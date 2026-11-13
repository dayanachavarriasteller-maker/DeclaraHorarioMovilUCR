import 'dart:math' as math;

import 'package:declara_horario/domain/rules/hours_calculator.dart';
import 'package:declara_horario/domain/rules/schedule_rules_config.dart';
import 'package:declara_horario/domain/rules/overlap_detector.dart';
import 'package:declara_horario/domain/rules/schedule_slot.dart';
import 'package:declara_horario/domain/rules/schedule_validator.dart';
import 'package:declara_horario/domain/rules/time_rules.dart';
import 'package:declara_horario/models/models.dart';
import 'package:declara_horario/shared/validators/form_validators.dart';
import 'package:declara_horario_movil/domain/declaration_draft.dart';

/// Dónde se corrige un hallazgo; la interfaz lo usa para llevar a la
/// persona directamente al dato que debe cambiar (laboratorio R4).
enum IssueTarget { general, job, interval, schedule }

/// Hallazgo de validación del módulo móvil.
class MobileIssue {
  const MobileIssue({
    required this.message,
    required this.blocking,
    required this.target,
    this.targetKeys = const <String>[],
    this.code,
  });

  final String message;

  /// `true` impide marcar la declaración como VALIDADA.
  final bool blocking;

  final IssueTarget target;

  /// Claves locales de los trabajos o intervalos involucrados.
  final List<String> targetKeys;

  /// Código del sistema original, cuando la regla viene de allí.
  final ValidationIssueCode? code;
}

/// Resultado: hallazgos + resumen de horas (el mismo [HoursSummary] que
/// guarda `markValidated` del original).
class MobileValidation {
  const MobileValidation({required this.issues, required this.hoursSummary});

  final List<MobileIssue> issues;
  final HoursSummary hoursSummary;

  bool get hasBlocking => issues.any((i) => i.blocking);
  List<MobileIssue> get blocking => issues.where((i) => i.blocking).toList();
  List<MobileIssue> get warnings => issues.where((i) => !i.blocking).toList();
}

/// Validador del módulo móvil.
///
/// Reutiliza las reglas del sistema original ([OverlapDetector], [TimeRules],
/// [HoursCalculator] y varias reglas de [ScheduleValidator]) y agrega la
/// revisión de campos obligatorios del formulario. Los traslapes se detectan
/// por INTERVALO para poder señalar exactamente cuál corregir, aunque sean de
/// instituciones diferentes (R4).
///
/// No aplica las reglas que dependen de la asignación de la coordinación de
/// carrera (lecciones, categorías): esa información no se captura en el
/// teléfono.
class MobileValidator {
  const MobileValidator({
    this.overlapDetector = const OverlapDetector(),
    this.scheduleValidator = const ScheduleValidator(),
    this.hoursCalculator = const HoursCalculator(),
  });

  final OverlapDetector overlapDetector;
  final ScheduleValidator scheduleValidator;
  final HoursCalculator hoursCalculator;

  MobileValidation validate(
    DeclarationDraft draft, {
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final appointments = draft.toAppointments(
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
    final externalJobs = draft.toExternalJobs(
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
    final content = VersionContent(
      version: DeclarationVersion(
        id: 'local',
        number: 1,
        declarantSnapshot: draft.toSnapshot(),
        observations: draft.observations,
        isLocked: false,
      ),
      appointments: appointments,
      externalJobs: externalJobs,
    );

    final overlaps = checkOverlaps(
      draft,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
    // Días con traslape: el original no repite ahí el hallazgo de horas
    // seguidas, porque al corregir el traslape cambia el tramo.
    final overlapDays = <Weekday>{
      for (final issue in overlaps)
        for (final i in draft.intervals)
          if (issue.targetKeys.contains(i.key)) i.day,
    };

    final issues = <MobileIssue>[
      ...checkRequired(draft),
      ...checkRanges(draft),
      ...checkLunch(draft),
      ...overlaps,
      // Máximo 6 horas seguidas sin una hora de descanso (todos los
      // trabajos juntos), regla del original.
      ..._fromOriginal(
        scheduleValidator.checkContinuousHours(content, skipDays: overlapDays),
        IssueTarget.schedule,
        draft,
      ),
      // Reglas del sistema original sobre el contenido completo.
      ..._fromOriginal(
        scheduleValidator.checkNotEmpty(content),
        IssueTarget.schedule,
        draft,
      ),
      ..._fromOriginal(
        scheduleValidator.checkDailyLimit(content),
        IssueTarget.schedule,
        draft,
      ),
      ..._fromOriginal(
        scheduleValidator.checkWeeklyLimit(content),
        IssueTarget.schedule,
        draft,
      ),
      ..._fromOriginal(
        scheduleValidator.checkExternalWeeklyLimit(content),
        IssueTarget.job,
        draft,
      ),
      ..._fromOriginal(
        scheduleValidator.checkExternalHours(content),
        IssueTarget.job,
        draft,
      ),
    ];

    final summary = hoursCalculator.summarize(
      appointments: appointments,
      expectedMinutes: draft.expectedUcrMinutes,
    );
    if (draft.ucrJobs.isNotEmpty &&
        draft.ucrJobs.every((job) => job.weeklyMinutes != null)) {
      issues.addAll(
        _fromOriginal(
          scheduleValidator.checkWorkloadMatch(summary),
          IssueTarget.schedule,
          draft,
        ),
      );
    }

    return MobileValidation(issues: issues, hoursSummary: summary);
  }

  /// Campos obligatorios (R2, prueba 03).
  List<MobileIssue> checkRequired(DeclarationDraft draft) {
    final issues = <MobileIssue>[];
    void general(String message) => issues.add(
      MobileIssue(
        message: message,
        blocking: true,
        target: IssueTarget.general,
      ),
    );

    if (FormValidators.notEmpty(draft.fullName) != null) {
      general('Falta el nombre completo de la persona declarante.');
    }
    final idError = FormValidators.identification(
      draft.identification,
      draft.identificationType,
    );
    if (idError != null) {
      general('Identificación: $idError');
    }
    if (draft.ucrJobs.isEmpty) {
      issues.add(
        const MobileIssue(
          message:
              'Agregue al menos un nombramiento en la Universidad de '
              'Costa Rica (institución, puesto y jornada).',
          blocking: true,
          target: IssueTarget.job,
        ),
      );
    }
    for (final job in draft.jobs) {
      final missing = <String>[
        if (job.name.trim().isEmpty)
          job.kind == JobKind.ucr ? 'lugar de trabajo' : 'institución',
        if (job.position.trim().isEmpty) 'puesto',
        if (job.workload.isEmpty) 'tipo de jornada',
        if (job.kind == JobKind.external &&
            (job.startDate == null || job.endDate == null))
          'período de vigencia',
      ];
      if (missing.isNotEmpty) {
        issues.add(
          MobileIssue(
            message: '${job.displayName}: falta ${_joinSpanish(missing)}.',
            blocking: true,
            target: IssueTarget.job,
            targetKeys: <String>[job.key],
          ),
        );
      }
      if (job.kind == JobKind.external &&
          job.startDate != null &&
          job.endDate != null &&
          job.endDate!.isBefore(job.startDate!)) {
        issues.add(
          MobileIssue(
            message:
                '${job.displayName}: la vigencia termina antes de empezar.',
            blocking: true,
            target: IssueTarget.job,
            targetKeys: <String>[job.key],
          ),
        );
      }
    }
    for (final interval in draft.intervals) {
      if (draft.jobByKey(interval.jobKey) == null) {
        issues.add(
          MobileIssue(
            message:
                'El intervalo del ${interval.day.label} '
                '${TimeRules.format(interval.startMinutes)}-'
                '${TimeRules.format(interval.endMinutes)} no tiene institución '
                'o nombramiento asociado.',
            blocking: true,
            target: IssueTarget.interval,
            targetKeys: <String>[interval.key],
          ),
        );
      }
    }
    return issues;
  }

  /// R4: la hora final debe ser posterior a la inicial.
  List<MobileIssue> checkRanges(DeclarationDraft draft) => <MobileIssue>[
    for (final i in draft.sortedIntervals)
      if (!TimeRules.isValidRange(i.startMinutes, i.endMinutes))
        MobileIssue(
          message:
              'Rango inválido el ${i.day.label} '
              '(${_jobLabel(draft, i)}): '
              '${TimeRules.format(i.startMinutes)}-'
              '${TimeRules.format(i.endMinutes)}. La hora de finalización '
              'debe ser posterior a la de inicio.',
          blocking: true,
          target: IssueTarget.interval,
          targetKeys: <String>[i.key],
          code: ValidationIssueCode.invalidTimeRange,
        ),
  ];

  /// Hora de almuerzo 12:00–13:00 excluida (regla 7.4 del original,
  /// `ScheduleValidator.checkExcludedWindow`, mismo código y mismo
  /// mensaje). Se revisa por intervalo, y para todos los trabajos como en
  /// la cuadrícula del original, para poder llevar a corregir el
  /// intervalo exacto.
  List<MobileIssue> checkLunch(DeclarationDraft draft) {
    const lunchStart = ScheduleRulesConfig.excludedStartMinutes;
    const lunchEnd = ScheduleRulesConfig.excludedEndMinutes;
    return <MobileIssue>[
      for (final i in draft.sortedIntervals)
        if (TimeRules.isValidRange(i.startMinutes, i.endMinutes))
          if (TimeRules.overlapMinutes(
                startA: i.startMinutes,
                endA: i.endMinutes,
                startB: lunchStart,
                endB: lunchEnd,
              ) >
              0)
            MobileIssue(
              message:
                  'El intervalo del ${i.day.label} en '
                  '"${_jobLabel(draft, i)}" '
                  '(${TimeRules.format(i.startMinutes)}-'
                  '${TimeRules.format(i.endMinutes)}) invade la hora de '
                  'almuerzo ${TimeRules.format(math.max(i.startMinutes, lunchStart))}-'
                  '${TimeRules.format(math.min(i.endMinutes, lunchEnd))}, '
                  'que no se declara.',
              blocking: true,
              target: IssueTarget.interval,
              targetKeys: <String>[i.key],
              code: ValidationIssueCode.excludedHour,
            ),
    ];
  }

  /// R4: sin traslapes en un mismo día, aunque sean de instituciones
  /// diferentes. Usa el [OverlapDetector] del original con un "slot" por
  /// intervalo.
  List<MobileIssue> checkOverlaps(
    DeclarationDraft draft, {
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final slots = <ScheduleSlot>[
      for (final i in draft.sortedIntervals)
        if (TimeRules.isValidRange(i.startMinutes, i.endMinutes))
          ScheduleSlot(
            itemId: i.key,
            label: _jobLabel(draft, i),
            origin: draft.jobByKey(i.jobKey)?.kind == JobKind.external
                ? SlotOrigin.externalJob
                : SlotOrigin.appointment,
            day: i.day,
            startMinutes: i.startMinutes,
            endMinutes: i.endMinutes,
            // R4 pide comparar siempre los intervalos del mismo día, por
            // eso todos usan la vigencia del período.
            startDate: periodStart,
            endDate: periodEnd,
          ),
    ];
    return <MobileIssue>[
      for (final issue in overlapDetector.findConflicts(slots))
        MobileIssue(
          message: issue.message,
          blocking: true,
          target: IssueTarget.interval,
          targetKeys: issue.relatedItemIds,
          code: issue.code,
        ),
    ];
  }

  List<MobileIssue> _fromOriginal(
    List<ValidationIssue> issues,
    IssueTarget target,
    DeclarationDraft draft,
  ) => <MobileIssue>[
    for (final issue in issues)
      MobileIssue(
        message: issue.message,
        blocking: issue.severity == ValidationSeverity.blocking,
        target: target,
        targetKeys: <String>[
          for (final id in issue.relatedItemIds)
            for (final job in draft.jobs)
              if (DeclarationDraft.modelIdOf(job) == id) job.key,
        ],
        code: issue.code,
      ),
  ];

  static String _jobLabel(DeclarationDraft draft, DraftInterval i) =>
      draft.jobByKey(i.jobKey)?.displayName ?? 'sin asociar';

  static String _joinSpanish(List<String> items) {
    if (items.length == 1) return items.first;
    return '${items.sublist(0, items.length - 1).join(', ')} y ${items.last}';
  }
}
