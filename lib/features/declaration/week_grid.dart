import 'dart:math' as math;

import 'package:declara_horario/domain/rules/schedule_grid.dart';
import 'package:declara_horario/domain/rules/time_rules.dart';
import 'package:declara_horario/models/models.dart';
import 'package:declara_horario_movil/core/theme/ucr_theme.dart';
import 'package:declara_horario_movil/domain/declaration_draft.dart';
import 'package:declara_horario_movil/domain/grid_editing.dart';
import 'package:flutter/material.dart';

/// Cuadrícula semanal de horas completas (lunes a sábado, 07:00–22:00), como
/// la del sistema original: se escoge un trabajo y se tocan las horas
/// horas para marcarlas; tocarlas otra vez las libera. El almuerzo
/// (12:00–13:00) está cerrado y los traslapes se ven en rojo.
///
/// Los seis días caben en 412 dp sin desplazamiento horizontal.
class WeekGrid extends StatelessWidget {
  const WeekGrid({
    super.key,
    required this.draft,
    required this.selectedJobKey,
    required this.onCellTap,
  });

  final DeclarationDraft draft;

  /// Trabajo con el que se marcan las horas.
  final String? selectedJobKey;

  final ValueChanged<GridCell> onCellTap;

  static const double _rowHeight = 34;
  static const double _timeWidth = 44;
  static const double _headerHeight = 32;

  /// Letras de los días como en los horarios de la UCR (K = martes).
  static const Map<Weekday, String> letters = <Weekday, String>{
    Weekday.monday: 'L',
    Weekday.tuesday: 'K',
    Weekday.wednesday: 'M',
    Weekday.thursday: 'J',
    Weekday.friday: 'V',
    Weekday.saturday: 'S',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = GridEditing.rowStarts;
    final occupancy = GridEditing.occupancy(draft);

    return LayoutBuilder(
      builder: (context, constraints) {
        final dayWidth =
            (constraints.maxWidth - _timeWidth) / ScheduleGrid.days.length;
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                height: _headerHeight,
                color: scheme.primary,
                child: Row(
                  children: [
                    SizedBox(
                      width: _timeWidth,
                      child: Center(
                        child: Text(
                          'Hora',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                    for (final day in ScheduleGrid.days)
                      SizedBox(
                        width: dayWidth,
                        child: Tooltip(
                          message: day.title,
                          child: Center(
                            child: Text(
                              letters[day]!,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              for (final start in rows)
                SizedBox(
                  height: _rowHeight,
                  child: Row(
                    children: [
                      Container(
                        width: _timeWidth,
                        height: _rowHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          border: start % 60 == 0
                              ? Border(
                                  top: BorderSide(color: scheme.outlineVariant),
                                )
                              : null,
                        ),
                        child: start % 60 == 0
                            ? Text(
                                TimeRules.format(start),
                                style: theme.textTheme.labelSmall,
                              )
                            : null,
                      ),
                      for (final day in ScheduleGrid.days)
                        SizedBox(
                          width: dayWidth,
                          child: _Cell(
                            cell: GridCell(day, start),
                            draft: draft,
                            occupancy: occupancy,
                            selectedJobKey: selectedJobKey,
                            onTap: onCellTap,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.cell,
    required this.draft,
    required this.occupancy,
    required this.selectedJobKey,
    required this.onTap,
  });

  final GridCell cell;
  final DeclarationDraft draft;
  final Map<GridCell, List<DraftInterval>> occupancy;
  final String? selectedJobKey;
  final ValueChanged<GridCell> onTap;

  List<DraftInterval> _at(int start) =>
      occupancy[GridCell(cell.day, start)] ?? const <DraftInterval>[];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<UcrStatusColors>()!;
    final step = GridEditing.step;
    final range =
        '${TimeRules.format(cell.startMinutes)} a '
        '${TimeRules.format(cell.startMinutes + GridEditing.step)}';
    final line = BorderSide(color: scheme.outlineVariant, width: 0.5);
    final topLine = cell.startMinutes % 60 == 0
        ? BorderSide(color: scheme.outlineVariant)
        : line;

    // Almuerzo: cerrado, como en el original.
    if (GridEditing.isLunch(cell.startMinutes)) {
      return Semantics(
        label: '${cell.day.title} $range, almuerzo, no se declara',
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            border: Border(top: topLine, left: line),
          ),
          alignment: Alignment.center,
          child: cell.startMinutes == 12 * 60
              ? Icon(Icons.restaurant, size: 14, color: scheme.outline)
              : null,
        ),
      );
    }

    final here = _at(cell.startMinutes);
    if (here.isEmpty) {
      return Semantics(
        button: true,
        label: '${cell.day.title} $range, libre',
        child: InkWell(
          onTap: () => onTap(cell),
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: topLine, left: line),
            ),
          ),
        ),
      );
    }

    final conflict = here.length > 1;
    final interval = here.first;
    final jobIndex = draft.jobs.indexWhere((j) => j.key == interval.jobKey);
    final job = draft.jobByKey(interval.jobKey);
    final palette = colors.jobBlock(math.max(jobIndex, 0));
    final fill = conflict ? scheme.errorContainer : palette.fill;
    final ink = conflict ? scheme.onErrorContainer : palette.text;

    // Misma ocupación arriba/abajo = mismo bloque visual.
    bool same(List<DraftInterval> other) =>
        other.length == here.length &&
        (conflict || other.first.jobKey == interval.jobKey);
    final above = _at(cell.startMinutes - step);
    final below = _at(cell.startMinutes + step);
    final isFirst =
        !same(above) || GridEditing.isLunch(cell.startMinutes - step);
    final isLast =
        !same(below) || GridEditing.isLunch(cell.startMinutes + step);
    final aboveFirst = !isFirst && !same(_at(cell.startMinutes - 2 * step));

    String? text;
    if (conflict && isFirst) {
      text = '⚠ Conflicto';
    } else if (!conflict && isFirst) {
      text = _shortName(job);
    } else if (!conflict && aboveFirst) {
      text = TimeRules.format(_runStart(interval.jobKey));
    }

    final name = conflict
        ? 'conflicto entre ${here.map((i) => draft.jobByKey(i.jobKey)?.displayName ?? 'sin asociar').join(' y ')}, toque para corregir'
        : '${job?.displayName ?? 'sin asociar'}'
              '${interval.jobKey == selectedJobKey ? ', toque para liberar' : ''}';

    return Semantics(
      button: true,
      label: '${cell.day.title} $range, $name',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onTap(cell),
        child: Container(
          margin: EdgeInsets.only(
            left: 1.5,
            right: 1.5,
            top: isFirst ? 1.5 : 0,
            bottom: isLast ? 1.5 : 0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 3),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(isFirst ? 4 : 0),
              bottom: Radius.circular(isLast ? 4 : 0),
            ),
            border: conflict
                ? Border(
                    left: BorderSide(color: scheme.error, width: 2),
                    right: BorderSide(color: scheme.error, width: 2),
                    top: isFirst
                        ? BorderSide(color: scheme.error, width: 2)
                        : BorderSide.none,
                    bottom: isLast
                        ? BorderSide(color: scheme.error, width: 2)
                        : BorderSide.none,
                  )
                : null,
          ),
          child: text == null
              ? null
              : Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  /// Inicio del bloque (horas seguidas del mismo trabajo) que
  /// contiene esta celda.
  int _runStart(String jobKey) {
    var start = cell.startMinutes;
    while (true) {
      final prev = _at(start - GridEditing.step);
      if (prev.length != 1 || prev.first.jobKey != jobKey) return start;
      start -= GridEditing.step;
    }
  }

  static String _shortName(DraftJob? job) {
    if (job == null) return 'Sin asociar';
    if (job.kind == JobKind.ucr) return 'UCR';
    final name = job.name.trim();
    return name.isEmpty ? 'Otra' : name;
  }
}

/// Selector del trabajo con el que se marcan las horas. Sirve
/// también de leyenda: color, nombre y horas ubicadas de la jornada.
class WeekGridJobPicker extends StatelessWidget {
  const WeekGridJobPicker({
    super.key,
    required this.draft,
    required this.selectedJobKey,
    required this.onSelected,
  });

  final DeclarationDraft draft;
  final String? selectedJobKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<UcrStatusColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Marcar horas de:', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var k = 0; k < draft.jobs.length; k++)
              _jobChip(context, colors.jobBlock(k).fill, draft.jobs[k]),
          ],
        ),
      ],
    );
  }

  Widget _jobChip(BuildContext context, Color color, DraftJob job) {
    final placed = draft.minutesOf(job.key);
    final weekly = job.weeklyMinutes;
    return ChoiceChip(
      // El cuadro de color es la leyenda: no se tapa con la marca.
      showCheckmark: false,
      selected: job.key == selectedJobKey,
      onSelected: (_) => onSelected(job.key),
      avatar: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 230),
        child: Text(
          '${job.displayName} · '
          '${weekly == null ? TimeRules.hoursLabel(placed) : TimeRules.hoursOf(placed, weekly)}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
