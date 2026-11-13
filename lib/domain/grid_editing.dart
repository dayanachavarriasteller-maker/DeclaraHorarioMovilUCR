import 'package:declara_horario/domain/rules/schedule_grid.dart';
import 'package:declara_horario/domain/rules/schedule_rules_config.dart';
import 'package:declara_horario/domain/rules/time_rules.dart';
import 'package:declara_horario/models/models.dart';
import 'package:declara_horario_movil/domain/declaration_draft.dart';

/// Qué pasó al tocar una hora de la cuadrícula.
sealed class GridTapResult {
  const GridTapResult();
}

/// Se marcó o se liberó la hora.
class GridTapChanged extends GridTapResult {
  const GridTapChanged({required this.added});
  final bool added;
}

/// No se permitió; [message] explica por qué (regla del sistema original).
class GridTapBlocked extends GridTapResult {
  const GridTapBlocked(this.message);
  final String message;
}

/// La hora tiene un traslape: se abre [interval] para corregirlo.
class GridTapConflict extends GridTapResult {
  const GridTapConflict(this.interval);
  final DraftInterval interval;
}

/// Edición del horario tocando horas completas, con las reglas del sistema
/// original (`ScheduleRulesConfig`, `ScheduleValidator`):
///
/// * horas de 07:00 a 22:00; el almuerzo (12:00–13:00) está cerrado;
/// * una hora de otro trabajo no se puede tomar;
/// * un trabajo no pasa de las horas de su jornada;
/// * un día no pasa de 10 horas entre todos los trabajos;
/// * no más de 6 horas seguidas sin una hora de descanso.
///
/// Las horas seguidas del mismo trabajo se guardan como un solo intervalo,
/// igual que `ScheduleGrid.rangesOf` en el original.
///
/// [GridCell] identifica la hora por día e inicio; aquí cada celda dura
/// [step] (una hora), no la media hora de la cuadrícula del original.
class GridEditing {
  const GridEditing._();

  /// Duración de una celda: una hora cerrada.
  static const int step = 60;

  static const int dayStart = ScheduleRulesConfig.workDayStartMinutes;
  static const int dayEnd = ScheduleRulesConfig.workDayEndMinutes;

  /// Inicio de cada fila: 07:00, 08:00 … 21:00.
  static List<int> get rowStarts => <int>[
    for (var m = dayStart; m < dayEnd; m += step) m,
  ];

  /// La fila del almuerzo.
  static bool isLunch(int startMinutes) =>
      startMinutes >= ScheduleRulesConfig.excludedStartMinutes &&
      startMinutes < ScheduleRulesConfig.excludedEndMinutes;

  /// Horas que cubre un rango (redondeado hacia afuera a horas completas).
  static List<GridCell> cellsOf(Weekday day, int start, int end) => <GridCell>[
    for (var m = start - start % step; m < end; m += step) GridCell(day, m),
  ];

  /// Intervalos que ocupan cada hora (más de uno = traslape).
  static Map<GridCell, List<DraftInterval>> occupancy(DeclarationDraft d) {
    final map = <GridCell, List<DraftInterval>>{};
    for (final i in d.sortedIntervals) {
      if (i.durationMinutes <= 0) continue;
      for (final cell in cellsOf(i.day, i.startMinutes, i.endMinutes)) {
        map.putIfAbsent(cell, () => <DraftInterval>[]).add(i);
      }
    }
    return map;
  }

  /// Minutos del [day] entre todos los trabajos.
  static int dayMinutes(DeclarationDraft d, Weekday day) => d.intervals
      .where((i) => i.day == day)
      .fold<int>(0, (s, i) => s + i.durationMinutes);

  /// Tramos de trabajo continuo de un día, uniendo todos los trabajos: un
  /// descanso de menos de una hora no corta el tramo. Mismo cálculo que
  /// `ScheduleValidator.checkContinuousHours` del original.
  static List<(int, int)> continuousRuns(Iterable<(int, int)> ranges) {
    final sorted = ranges.where((r) => r.$2 > r.$1).toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    final runs = <(int, int)>[];
    for (final r in sorted) {
      if (runs.isNotEmpty &&
          r.$1 - runs.last.$2 < ScheduleRulesConfig.minBreakMinutes) {
        final last = runs.removeLast();
        runs.add((last.$1, r.$2 > last.$2 ? r.$2 : last.$2));
      } else {
        runs.add(r);
      }
    }
    return runs;
  }

  /// El tramo continuo más largo que sobrepasa 6 h si al [day] se le
  /// agregan [extra], o `null` si se respeta la regla. [except] se excluye
  /// (el intervalo que se está corrigiendo).
  static (int, int)? tooLongRun(
    DeclarationDraft d,
    Weekday day,
    Iterable<(int, int)> extra, {
    DraftInterval? except,
  }) {
    final runs = continuousRuns(<(int, int)>[
      for (final i in d.intervals)
        if (i.day == day && i != except) (i.startMinutes, i.endMinutes),
      ...extra,
    ]);
    for (final run in runs) {
      if (run.$2 - run.$1 > ScheduleRulesConfig.maxContinuousMinutes) {
        return run;
      }
    }
    return null;
  }

  /// Mensaje de la regla de 6 horas para el tramo [run].
  static String continuousMessage(Weekday day, (int, int) run) =>
      'El ${day.label} quedarían ${TimeRules.hoursLabel(run.$2 - run.$1)} '
      'seguidas (${TimeRules.format(run.$1)}-${TimeRules.format(run.$2)}) '
      'sin una hora de descanso; el máximo es '
      '${TimeRules.hoursLabel(ScheduleRulesConfig.maxContinuousMinutes)}.';

  /// Aplica el toque de [cell] para el trabajo [jobKey] sobre [draft].
  static GridTapResult tap(
    DeclarationDraft draft,
    String jobKey,
    GridCell cell,
  ) {
    final start = cell.startMinutes;
    if (isLunch(start)) {
      return const GridTapBlocked(
        'La hora de almuerzo (12:00–13:00) no se declara.',
      );
    }
    final job = draft.jobByKey(jobKey);
    if (job == null) {
      return const GridTapBlocked('Escoja primero un trabajo.');
    }
    final occupants = occupancy(draft)[cell] ?? const <DraftInterval>[];
    final own = occupants.where((i) => i.jobKey == jobKey).toList();

    if (occupants.length > 1) {
      // Traslape ya registrado: se corrige en la hoja del intervalo.
      return GridTapConflict(own.isNotEmpty ? own.last : occupants.last);
    }
    if (own.isNotEmpty) {
      _setCell(draft, jobKey, cell, on: false);
      return const GridTapChanged(added: false);
    }
    if (occupants.isNotEmpty) {
      final other =
          draft.jobByKey(occupants.first.jobKey)?.displayName ?? 'otro trabajo';
      return GridTapBlocked('Esa hora ya está ocupada por $other.');
    }
    final weekly = job.weeklyMinutes;
    if (weekly == null) {
      return const GridTapBlocked(
        'Indique primero el tipo de jornada en la pestaña «Trabajo».',
      );
    }
    if (draft.minutesOf(jobKey) + step > weekly) {
      return GridTapBlocked(
        'Ya ubicó las ${TimeRules.hoursLabel(weekly)} por '
        'semana de ${job.displayName}.',
      );
    }
    if (dayMinutes(draft, cell.day) + step >
        ScheduleRulesConfig.maxDailyMinutes) {
      return GridTapBlocked(
        'El ${cell.day.label} ya suma '
        '${TimeRules.hoursLabel(ScheduleRulesConfig.maxDailyMinutes)}, '
        'el máximo diario.',
      );
    }
    final run = tooLongRun(draft, cell.day, [(start, start + step)]);
    if (run != null) {
      return GridTapBlocked(continuousMessage(cell.day, run));
    }
    _setCell(draft, jobKey, cell, on: true);
    return const GridTapChanged(added: true);
  }

  /// Marca o libera [cell] del trabajo y vuelve a unir las horas seguidas
  /// de ese día en intervalos.
  static void _setCell(
    DeclarationDraft draft,
    String jobKey,
    GridCell cell, {
    required bool on,
  }) {
    final mine = draft.intervals
        .where((i) => i.jobKey == jobKey && i.day == cell.day)
        .toList();
    final starts = <int>{
      for (final i in mine)
        if (i.durationMinutes > 0)
          for (final c in cellsOf(i.day, i.startMinutes, i.endMinutes))
            c.startMinutes,
    };
    on ? starts.add(cell.startMinutes) : starts.remove(cell.startMinutes);
    draft.intervals.removeWhere(mine.contains);

    final sorted = starts.toList()..sort();
    var k = 0;
    while (k < sorted.length) {
      final start = sorted[k];
      var end = start + step;
      while (k + 1 < sorted.length && sorted[k + 1] == end) {
        k++;
        end += step;
      }
      draft.intervals.add(
        DraftInterval(
          key: draft.newKey('int'),
          jobKey: jobKey,
          day: cell.day,
          startMinutes: start,
          endMinutes: end,
        ),
      );
      k++;
    }
  }
}
