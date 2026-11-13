import 'package:declara_horario/domain/rules/schedule_rules_config.dart';
import 'package:declara_horario/domain/rules/time_rules.dart';
import 'package:declara_horario/models/models.dart';
import 'package:declara_horario_movil/domain/declaration_draft.dart';
import 'package:declara_horario_movil/domain/grid_editing.dart';
import 'package:declara_horario_movil/features/declaration/declaration_controller.dart';
import 'package:declara_horario_movil/shared/widgets/ucr_widgets.dart';
import 'package:flutter/material.dart';

/// Abre la hoja para agregar o corregir un intervalo (R3).
///
/// Al agregar se pueden marcar varios días a la vez (por ejemplo L, M y V
/// de 08:00 a 10:00) y se crea un intervalo por día. [day] y
/// [startMinutes] prellenan la hoja cuando se toca una celda vacía de la
/// cuadrícula semanal.
Future<void> showIntervalSheet(
  BuildContext context,
  DeclarationController controller, {
  DraftInterval? interval,
  Weekday? day,
  int? startMinutes,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _IntervalSheet(
    controller: controller,
    interval: interval,
    day: day,
    startMinutes: startMinutes,
  ),
);

class _IntervalSheet extends StatefulWidget {
  const _IntervalSheet({
    required this.controller,
    this.interval,
    this.day,
    this.startMinutes,
  });

  final DeclarationController controller;
  final DraftInterval? interval;
  final Weekday? day;
  final int? startMinutes;

  @override
  State<_IntervalSheet> createState() => _IntervalSheetState();
}

class _IntervalSheetState extends State<_IntervalSheet> {
  late final Set<Weekday> _days = <Weekday>{
    widget.interval?.day ?? widget.day ?? Weekday.monday,
  };
  // Horas completas entre 07:00 y 22:00; un intervalo viejo con minutos
  // se redondea hacia afuera.
  late int _start = _snap(
    widget.interval?.startMinutes ?? widget.startMinutes ?? 8 * 60,
    up: false,
  );
  late int _end = _snap(
    widget.interval?.endMinutes ??
        (widget.startMinutes == null ? 12 * 60 : widget.startMinutes! + 120),
    up: true,
  );

  static int _snap(int minutes, {required bool up}) {
    final hour = up ? (minutes + 59) ~/ 60 : minutes ~/ 60;
    return (hour * 60).clamp(GridEditing.dayStart, GridEditing.dayEnd);
  }

  /// Horas que se pueden escoger como inicio (07:00–21:00) o fin
  /// (08:00–22:00).
  static List<int> _hours({required bool end}) => <int>[
    for (
      var m = GridEditing.dayStart + (end ? 60 : 0);
      m <= GridEditing.dayEnd - (end ? 0 : 60);
      m += 60
    )
      m,
  ];

  /// Primer día marcado donde el rango dejaría más de 6 h seguidas.
  String? get _continuous {
    for (final day in _selectedDays) {
      final run = GridEditing.tooLongRun(_draft, day, [
        (_start, _end),
      ], except: widget.interval);
      if (run != null) return GridEditing.continuousMessage(day, run);
    }
    return null;
  }

  late String? _jobKey =
      widget.interval?.jobKey ??
      (widget.controller.draft.jobs.isEmpty
          ? null
          : widget.controller.draft.jobs.first.key);

  DeclarationDraft get _draft => widget.controller.draft;

  bool get _editing => widget.interval != null;

  bool get _validRange => TimeRules.isValidRange(_start, _end);

  bool get _invadesLunch =>
      TimeRules.overlapMinutes(
        startA: _start,
        endA: _end,
        startB: ScheduleRulesConfig.excludedStartMinutes,
        endB: ScheduleRulesConfig.excludedEndMinutes,
      ) >
      0;

  /// Días marcados, en orden de la semana.
  List<Weekday> get _selectedDays =>
      Weekday.values.where(_days.contains).toList();

  /// Intervalos de los días marcados que chocan con el que se está
  /// editando, sin importar la institución (R4).
  List<String> get _conflicts => <String>[
    for (final other in _draft.sortedIntervals)
      if (other != widget.interval &&
          _days.contains(other.day) &&
          TimeRules.overlapMinutes(
                startA: _start,
                endA: _end,
                startB: other.startMinutes,
                endB: other.endMinutes,
              ) >
              0)
        '${_days.length > 1 ? '${other.day.label} ' : ''}'
            '${TimeRules.format(other.startMinutes)}–'
            '${TimeRules.format(other.endMinutes)} '
            '(${_draft.jobByKey(other.jobKey)?.displayName ?? 'sin asociar'})',
  ];

  void _save() {
    final existing = widget.interval;
    if (existing != null) {
      existing
        ..day = _days.single
        ..startMinutes = _start
        ..endMinutes = _end
        ..jobKey = _jobKey!;
      widget.controller.upsertInterval(existing);
    } else {
      widget.controller.addIntervals([
        for (final day in _selectedDays)
          DraftInterval(
            key: _draft.newKey('int'),
            jobKey: _jobKey!,
            day: day,
            startMinutes: _start,
            endMinutes: _end,
          ),
      ]);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conflicts = _validRange ? _conflicts : const <String>[];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(
                widget.interval == null
                    ? 'Agregar intervalo'
                    : 'Corregir intervalo',
              ),
              Text(
                _editing ? 'Día' : 'Días (puede marcar varios)',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final day in Weekday.values)
                    if (_editing)
                      ChoiceChip(
                        label: Text(day.title.substring(0, 3)),
                        tooltip: day.title,
                        selected: _days.contains(day),
                        onSelected: (_) => setState(
                          () => _days
                            ..clear()
                            ..add(day),
                        ),
                      )
                    else
                      FilterChip(
                        label: Text(day.title.substring(0, 3)),
                        tooltip: day.title,
                        selected: _days.contains(day),
                        onSelected: (on) => setState(
                          () => on ? _days.add(day) : _days.remove(day),
                        ),
                      ),
                ],
              ),
              if (!_editing) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Lunes a viernes'),
                      onPressed: () => setState(
                        () => _days
                          ..clear()
                          ..addAll(
                            Weekday.values.where((d) => d != Weekday.saturday),
                          ),
                      ),
                    ),
                    ActionChip(
                      label: const Text('Limpiar'),
                      onPressed: () => setState(_days.clear),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _HourField(
                      label: 'Desde',
                      value: _start,
                      hours: _hours(end: false),
                      onChanged: (v) => setState(() => _start = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HourField(
                      label: 'Hasta',
                      value: _end,
                      hours: _hours(end: true),
                      error: !_validRange,
                      onChanged: (v) => setState(() => _end = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _validRange
                    ? 'Duración: ${TimeRules.hoursLabel(TimeRules.durationMinutes(_start, _end))}'
                          '${_days.length > 1 ? ' por día · ${TimeRules.hoursLabel(TimeRules.durationMinutes(_start, _end) * _days.length)} en total' : ''}'
                    : 'La hora de finalización debe ser posterior a la de '
                          'inicio.',
                style: TextStyle(
                  color: _validRange ? null : theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _jobKey,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Institución o nombramiento *',
                ),
                items: [
                  for (final job in _draft.jobs)
                    DropdownMenuItem(
                      value: job.key,
                      child: Text(
                        job.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _jobKey = v),
              ),
              if (_validRange && _invadesLunch) ...[
                const SizedBox(height: 12),
                const IssueTile(
                  blocking: true,
                  message:
                      'Este rango invade la hora de almuerzo '
                      '(12:00–13:00), que no se declara. Puede guardarlo, '
                      'pero la declaración no se podrá validar hasta '
                      'corregirlo.',
                ),
              ],
              if (_validRange && _continuous != null) ...[
                const SizedBox(height: 12),
                IssueTile(
                  blocking: true,
                  message:
                      '$_continuous Puede guardarlo, pero la '
                      'declaración no se podrá validar hasta corregirlo.',
                ),
              ],
              if (conflicts.isNotEmpty) ...[
                const SizedBox(height: 12),
                IssueTile(
                  blocking: true,
                  message:
                      'Se traslapa '
                      '${_days.length == 1 ? 'el ${_days.single.label} ' : ''}con '
                      '${conflicts.join(' y ')}. Puede guardarlo, pero la '
                      'declaración no se podrá validar hasta corregirlo.',
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _validRange && _jobKey != null && _days.isNotEmpty
                    ? _save
                    : null,
                child: Text(
                  _editing
                      ? 'Guardar cambios'
                      : _days.length > 1
                      ? 'Agregar a ${_days.length} días'
                      : 'Agregar al horario',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selector de hora en punto (horario por horas completas).
class _HourField extends StatelessWidget {
  const _HourField({
    required this.label,
    required this.value,
    required this.hours,
    required this.onChanged,
    this.error = false,
  });

  final String label;
  final int value;
  final List<int> hours;
  final ValueChanged<int> onChanged;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      key: ValueKey('$label-$value'),
      initialValue: hours.contains(value) ? value : null,
      isExpanded: true,
      menuMaxHeight: 320,
      decoration: InputDecoration(
        labelText: label,
        errorText: error ? 'Revise la hora' : null,
      ),
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
      items: [
        for (final m in hours)
          DropdownMenuItem(value: m, child: Text(TimeRules.format(m))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
