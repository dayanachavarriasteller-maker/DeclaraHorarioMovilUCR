import 'package:declara_horario/domain/rules/workload_catalog.dart';
import 'package:declara_horario/models/models.dart';

/// Tipo de trabajo declarado: nombramiento en la UCR (`appointments`) u otra
/// institución (`externalJobs`), igual que en el sistema original.
enum JobKind { ucr, external }

/// Nombramiento u otra institución mientras se edita en el teléfono.
///
/// Se convierte en [Appointment] o [ExternalJob] (modelos del sistema
/// original) al guardar y al validar.
class DraftJob {
  DraftJob({
    required this.key,
    required this.kind,
    this.firestoreId = '',
    this.name = '',
    this.position = '',
    this.workload = '',
    this.institutionType = InstitutionType.public,
    this.startDate,
    this.endDate,
  });

  /// Identificador local estable (sirve para asociar intervalos).
  final String key;

  final JobKind kind;

  /// Id del documento en Firestore; vacío mientras no se ha guardado.
  String firestoreId;

  /// Lugar de trabajo (UCR) o nombre de la institución (externa).
  String name;

  /// Puesto o categoría.
  String position;

  /// Jornada del catálogo (`1/4 TC`, `1/2 TC`...).
  String workload;

  /// Solo para otras instituciones.
  InstitutionType institutionType;

  /// Vigencia. En la UCR es la del período (las reglas de Firestore lo
  /// exigen); en otras instituciones la escoge la persona.
  DateTime? startDate;
  DateTime? endDate;

  /// Texto para listas y mensajes: "UCR · Sede del Sur" o la institución.
  String get displayName {
    final base = name.trim().isEmpty ? 'Sin nombre' : name.trim();
    return kind == JobKind.ucr ? 'UCR · $base' : base;
  }

  /// Minutos semanales de la jornada, o `null` si no se ha escogido.
  int? get weeklyMinutes => WorkloadCatalog.expectedMinutesFor(workload);
}

/// Intervalo de horario: día, hora de inicio, hora de fin y trabajo asociado.
class DraftInterval {
  DraftInterval({
    required this.key,
    required this.jobKey,
    required this.day,
    required this.startMinutes,
    required this.endMinutes,
  });

  final String key;
  String jobKey;
  Weekday day;
  int startMinutes;
  int endMinutes;

  /// Duración en minutos (0 si el rango es inválido).
  int get durationMinutes =>
      endMinutes > startMinutes ? endMinutes - startMinutes : 0;

  TimeBlock toBlock() => TimeBlock(
        day: day,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
      );
}

/// Toda la declaración en edición: datos generales, trabajos, horario y
/// observaciones. Es Dart puro para poder probarla sin Firebase.
class DeclarationDraft {
  DeclarationDraft({
    this.fullName = '',
    this.identification = '',
    this.identificationType = IdentificationType.nationalId,
    this.observations = '',
    this.unitName = '',
    this.campusName = '',
    this.phone = '',
    this.email = '',
    List<DraftJob>? jobs,
    List<DraftInterval>? intervals,
  })  : jobs = jobs ?? <DraftJob>[],
        intervals = intervals ?? <DraftInterval>[];

  String fullName;
  String identification;
  IdentificationType identificationType;
  String observations;

  // Datos del perfil que se conservan en la versión (solo lectura aquí).
  String unitName;
  String campusName;
  String phone;
  String email;

  final List<DraftJob> jobs;
  final List<DraftInterval> intervals;

  int _seq = 0;

  /// Clave local única.
  String newKey(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  DraftJob? jobByKey(String key) {
    for (final job in jobs) {
      if (job.key == key) return job;
    }
    return null;
  }

  List<DraftJob> get ucrJobs =>
      jobs.where((job) => job.kind == JobKind.ucr).toList();

  List<DraftJob> get externalJobs =>
      jobs.where((job) => job.kind == JobKind.external).toList();

  List<DraftInterval> intervalsOf(String jobKey) =>
      intervals.where((i) => i.jobKey == jobKey).toList();

  /// Intervalos ordenados por día y hora (para listas y resumen).
  List<DraftInterval> get sortedIntervals => [...intervals]..sort((a, b) {
      final byDay = a.day.number.compareTo(b.day.number);
      return byDay != 0 ? byDay : a.startMinutes.compareTo(b.startMinutes);
    });

  /// Total de minutos registrados (todos los intervalos válidos).
  int get totalMinutes =>
      intervals.fold<int>(0, (sum, i) => sum + i.durationMinutes);

  /// Minutos registrados de un trabajo.
  int minutesOf(String jobKey) =>
      intervalsOf(jobKey).fold<int>(0, (sum, i) => sum + i.durationMinutes);

  /// Minutos esperados por las jornadas de la UCR (para [HoursSummary]).
  int get expectedUcrMinutes => ucrJobs.fold<int>(
      0, (sum, job) => sum + (job.weeklyMinutes ?? 0));

  /// Id con el que el trabajo aparece en los modelos: el de Firestore o, si
  /// aún no se ha guardado, la clave local.
  static String modelIdOf(DraftJob job) =>
      job.firestoreId.isEmpty ? job.key : job.firestoreId;

  /// Nombramientos UCR como modelos del sistema original.
  List<Appointment> toAppointments({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) =>
      <Appointment>[
        for (final job in ucrJobs)
          Appointment(
            id: modelIdOf(job),
            workplace: job.name.trim(),
            position: job.position.trim(),
            workload: job.workload,
            startDate: periodStart,
            endDate: periodEnd,
            blocks: [for (final i in intervalsOf(job.key)) i.toBlock()],
          ),
      ];

  /// Otras instituciones como modelos del sistema original.
  List<ExternalJob> toExternalJobs({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) =>
      <ExternalJob>[
        for (final job in externalJobs)
          ExternalJob(
            id: modelIdOf(job),
            institution: job.name.trim(),
            institutionType: job.institutionType,
            position: job.position.trim(),
            workload: job.workload,
            startDate: job.startDate ?? periodStart,
            endDate: job.endDate ?? periodEnd,
            blocks: [for (final i in intervalsOf(job.key)) i.toBlock()],
            weeklyMinutes: job.weeklyMinutes,
          ),
      ];

  /// Datos de la persona declarante para la versión.
  DeclarantSnapshot toSnapshot() => DeclarantSnapshot(
        fullName: fullName.trim(),
        identification: identification.trim(),
        phone: phone,
        email: email,
        unitName: unitName,
        campusName: campusName,
      );

  /// Construye el borrador a partir del contenido guardado de una versión.
  factory DeclarationDraft.fromContent(
    VersionContent content, {
    IdentificationType identificationType = IdentificationType.nationalId,
  }) {
    final snapshot = content.version.declarantSnapshot;
    final draft = DeclarationDraft(
      fullName: snapshot.fullName,
      identification: snapshot.identification,
      identificationType: identificationType,
      observations: content.version.observations,
      unitName: snapshot.unitName,
      campusName: snapshot.campusName,
      phone: snapshot.phone,
      email: snapshot.email,
    );
    void addBlocks(String jobKey, List<TimeBlock> blocks) {
      for (final block in blocks) {
        draft.intervals.add(DraftInterval(
          key: draft.newKey('int'),
          jobKey: jobKey,
          day: block.day,
          startMinutes: block.startMinutes,
          endMinutes: block.endMinutes,
        ));
      }
    }

    for (final a in content.appointments) {
      final job = DraftJob(
        key: draft.newKey('job'),
        kind: JobKind.ucr,
        firestoreId: a.id,
        name: a.workplace,
        position: a.position,
        workload: a.workload,
        startDate: a.startDate,
        endDate: a.endDate,
      );
      draft.jobs.add(job);
      addBlocks(job.key, a.blocks);
    }
    for (final e in content.externalJobs) {
      final job = DraftJob(
        key: draft.newKey('job'),
        kind: JobKind.external,
        firestoreId: e.id,
        name: e.institution,
        position: e.position,
        workload: e.workload,
        institutionType: e.institutionType,
        startDate: e.startDate,
        endDate: e.endDate,
      );
      draft.jobs.add(job);
      addBlocks(job.key, e.blocks);
    }
    return draft;
  }
}
