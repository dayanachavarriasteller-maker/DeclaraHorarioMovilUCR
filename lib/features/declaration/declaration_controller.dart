import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:declara_horario/core/constants/firestore_paths.dart';
import 'package:declara_horario/core/errors/app_exception.dart';
import 'package:declara_horario/models/models.dart';
import 'package:declara_horario/repositories/declaration_repository.dart';
import 'package:declara_horario/repositories/period_repository.dart';
import 'package:declara_horario/repositories/version_content_repository.dart';
import 'package:declara_horario/services/workflow_service.dart';
import 'package:declara_horario_movil/domain/declaration_draft.dart';
import 'package:declara_horario_movil/domain/mobile_validator.dart';
import 'package:flutter/foundation.dart';

/// Estado de una declaración abierta en el teléfono: carga, edición,
/// guardado del borrador y validación.
///
/// La persistencia es la del sistema original: [DeclarationRepository],
/// [VersionContentRepository], [PeriodRepository] y [WorkflowService]
/// (`reopenAsDraft` / `markValidated`). No se crea backend nuevo (R5).
class DeclarationController extends ChangeNotifier {
  DeclarationController({
    required this.declarationId,
    required this.actor,
    required this.declarations,
    required this.versions,
    required this.periods,
    required this.workflow,
    required this.firestore,
    this.validator = const MobileValidator(),
  });

  final String declarationId;
  final AppUser actor;
  final DeclarationRepository declarations;
  final VersionContentRepository versions;
  final PeriodRepository periods;
  final WorkflowService workflow;
  final FirebaseFirestore firestore;
  final MobileValidator validator;

  Declaration? declaration;
  Period? period;
  DeclarationDraft draft = DeclarationDraft();

  bool loading = true;
  bool busy = false;
  String? error;

  /// Hay cambios sin guardar.
  bool dirty = false;

  /// Resultado de la última validación (se recalcula en cada cambio).
  MobileValidation? validation;

  // Documentos borrados en el teléfono que deben eliminarse al guardar.
  final Set<String> _removedAppointments = <String>{};
  final Set<String> _removedExternalJobs = <String>{};

  static const Set<DeclarationStatus> _editable = <DeclarationStatus>{
    DeclarationStatus.borrador,
    DeclarationStatus.validada,
    DeclarationStatus.pendienteFirmaDeclarante,
  };

  /// La declaración se puede editar desde el teléfono. Los estados de firma
  /// y revisión no se tocan aquí (límite de alcance del laboratorio).
  bool get editable =>
      declaration != null && _editable.contains(declaration!.status);

  DeclarationStatus? get status => declaration?.status;

  DateTime get periodStart => period?.startDate ?? DateTime(2026);
  DateTime get periodEnd => period?.endDate ?? DateTime(2026, 12, 31);

  VersionRef get _ref => VersionRef(
        declarationId: declarationId,
        versionId: declaration!.currentVersionId,
      );

  /// Carga la declaración, su versión actual y su período (prueba 04:
  /// recuperar el borrador al reabrirlo).
  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final found = await declarations.getById(declarationId);
      if (found == null) {
        throw const NotFoundException('La declaración no existe.');
      }
      declaration = found;
      final results = await Future.wait<Object?>([
        versions.getContent(_ref),
        periods.getById(found.periodId),
      ]);
      draft = DeclarationDraft.fromContent(
        results[0]! as VersionContent,
        identificationType: actor.identificationType,
      );
      period = results[1] as Period?;
      _removedAppointments.clear();
      _removedExternalJobs.clear();
      dirty = false;
      _revalidate();
    } catch (e) {
      error = messageOf(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- edición

  /// Llamar después de modificar [draft] desde la interfaz.
  void changed() {
    dirty = true;
    _revalidate();
    notifyListeners();
  }

  DraftJob addJob(JobKind kind) {
    final job = DraftJob(
      key: draft.newKey('job'),
      kind: kind,
      name: kind == JobKind.ucr ? draft.unitName : '',
      startDate: periodStart,
      endDate: periodEnd,
    );
    draft.jobs.add(job);
    changed();
    return job;
  }

  void removeJob(DraftJob job) {
    draft.jobs.remove(job);
    draft.intervals.removeWhere((i) => i.jobKey == job.key);
    if (job.firestoreId.isNotEmpty) {
      (job.kind == JobKind.ucr ? _removedAppointments : _removedExternalJobs)
          .add(job.firestoreId);
    }
    changed();
  }

  void upsertInterval(DraftInterval interval) {
    if (!draft.intervals.contains(interval)) draft.intervals.add(interval);
    changed();
  }

  void removeInterval(DraftInterval interval) {
    draft.intervals.remove(interval);
    changed();
  }

  void _revalidate() {
    validation = validator.validate(
      draft,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }

  // ------------------------------------------------------------ persistencia

  /// Guarda el borrador (R5, prueba 01). Si estaba VALIDADA, primero vuelve
  /// a BORRADOR con `reopenAsDraft` del original: las reglas de seguridad
  /// solo permiten editar contenido en BORRADOR.
  Future<bool> saveDraft() async {
    if (!editable) return false;
    return _run(() async {
      await _persist();
    });
  }

  /// Valida y, si no hay errores bloqueantes, guarda y marca la declaración
  /// como VALIDADA (`markValidated`). Devuelve el resultado de validar.
  Future<MobileValidation?> validateAndMark() async {
    _revalidate();
    notifyListeners();
    final result = validation!;
    if (result.hasBlocking || !editable) return result;
    final ok = await _run(() async {
      await _persist();
      await workflow.markValidated(
        declarationId: declarationId,
        actor: actor,
        hoursSummary: result.hoursSummary,
      );
      declaration = await declarations.getById(declarationId);
    });
    return ok ? result : null;
  }

  Future<void> _persist() async {
    if (declaration!.status != DeclarationStatus.borrador) {
      await workflow.reopenAsDraft(
        declarationId: declarationId,
        actor: actor,
      );
    }
    final ref = _ref;

    for (final id in _removedAppointments) {
      await versions.deleteAppointment(ref: ref, appointmentId: id);
    }
    for (final id in _removedExternalJobs) {
      await versions.deleteExternalJob(ref: ref, externalJobId: id);
    }
    _removedAppointments.clear();
    _removedExternalJobs.clear();

    // Se guardan con el id de Firestore (vacío = nuevo) y se recuerda el id
    // asignado para que el siguiente guardado actualice en vez de duplicar.
    final appointments =
        draft.toAppointments(periodStart: periodStart, periodEnd: periodEnd);
    final ucrJobs = draft.ucrJobs;
    for (var i = 0; i < ucrJobs.length; i++) {
      final job = ucrJobs[i];
      final a = appointments[i];
      job.firestoreId = await versions.saveAppointment(
        ref: ref,
        appointment: Appointment(
          id: job.firestoreId,
          workplace: a.workplace,
          position: a.position,
          workload: a.workload,
          startDate: a.startDate,
          endDate: a.endDate,
          blocks: a.blocks,
        ),
      );
    }

    final externals =
        draft.toExternalJobs(periodStart: periodStart, periodEnd: periodEnd);
    final extJobs = draft.externalJobs;
    for (var i = 0; i < extJobs.length; i++) {
      final job = extJobs[i];
      final e = externals[i];
      job.firestoreId = await versions.saveExternalJob(
        ref: ref,
        externalJob: ExternalJob(
          id: job.firestoreId,
          institution: e.institution,
          institutionType: e.institutionType,
          position: e.position,
          workload: e.workload,
          startDate: e.startDate,
          endDate: e.endDate,
          blocks: e.blocks,
          weeklyMinutes: e.weeklyMinutes,
        ),
      );
    }

    await versions.updateObservations(
      ref: ref,
      observations: draft.observations.trim(),
    );
    // Nombre e identificación capturados en el formulario (R2). El
    // repositorio original no expone este campo, pero las reglas permiten
    // actualizar `declarantSnapshot` de la versión en BORRADOR.
    await firestore
        .doc(FirestorePaths.version(declarationId, ref.versionId))
        .update(<String, Object>{
      VersionFields.declarantSnapshot: draft.toSnapshot().toMap(),
    });

    declaration = await declarations.getById(declarationId);
    dirty = false;
  }

  Future<bool> _run(Future<void> Function() action) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      _revalidate();
      return true;
    } catch (e) {
      error = messageOf(e);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Mensaje legible para cualquier error de los servicios.
  static String messageOf(Object e) {
    if (e is AppException) return e.message;
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return 'Firebase rechazó la operación (permisos). Revise que la '
            'declaración siga en un estado editable.';
      }
      if (e.code == 'unavailable') {
        return 'Sin conexión con el servidor. Intente de nuevo.';
      }
      return e.message ?? e.code;
    }
    return '$e';
  }
}
