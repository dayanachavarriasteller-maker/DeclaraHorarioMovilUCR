import 'package:declara_horario/domain/rules/time_rules.dart';
import 'package:declara_horario/models/models.dart';
import 'package:declara_horario_movil/domain/declaration_draft.dart';
import 'package:declara_horario_movil/features/declaration/declaration_controller.dart';
import 'package:declara_horario_movil/shared/widgets/ucr_widgets.dart';
import 'package:flutter/material.dart';

/// Abre la hoja para agregar o corregir un intervalo (R3).
Future<void> showIntervalSheet(
  BuildContext context,
  DeclarationController controller, {
  DraftInterval? interval,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _IntervalSheet(controller: controller, interval: interval),
    );

class _IntervalSheet extends StatefulWidget {
  const _IntervalSheet({required this.controller, this.interval});

  final DeclarationController controller;
  final DraftInterval? interval;

  @override
  State<_IntervalSheet> createState() => _IntervalSheetState();
}

class _IntervalSheetState extends State<_IntervalSheet> {
  late Weekday _day = widget.interval?.day ?? Weekday.monday;
  late int _start = widget.interval?.startMinutes ?? 8 * 60;
  late int _end = widget.interval?.endMinutes ?? 12 * 60;
  late String? _jobKey = widget.interval?.jobKey ??
      (widget.controller.draft.jobs.isEmpty
          ? null
          : widget.controller.draft.jobs.first.key);

  DeclarationDraft get _draft => widget.controller.draft;

  bool get _validRange => TimeRules.isValidRange(_start, _end);

  /// Intervalos del mismo día que chocan con el que se está editando,
  /// sin importar la institución (R4).
  List<String> get _conflicts => <String>[
        for (final other in _draft.sortedIntervals)
          if (other != widget.interval &&
              other.day == _day &&
              TimeRules.overlapMinutes(
                    startA: _start,
                    endA: _end,
                    startB: other.startMinutes,
                    endB: other.endMinutes,
                  ) >
                  0)
            '${TimeRules.format(other.startMinutes)}–'
                '${TimeRules.format(other.endMinutes)} '
                '(${_draft.jobByKey(other.jobKey)?.displayName ?? 'sin asociar'})',
      ];

  Future<void> _pick({required bool start}) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: start ? 'Hora de inicio' : 'Hora de finalización',
    );
    if (picked == null) return;
    setState(() {
      final minutes = picked.hour * 60 + picked.minute;
      if (start) {
        _start = minutes;
      } else {
        _end = minutes;
      }
    });
  }

  void _save() {
    final existing = widget.interval;
    if (existing != null) {
      existing
        ..day = _day
        ..startMinutes = _start
        ..endMinutes = _end
        ..jobKey = _jobKey!;
      widget.controller.upsertInterval(existing);
    } else {
      widget.controller.upsertInterval(DraftInterval(
        key: _draft.newKey('int'),
        jobKey: _jobKey!,
        day: _day,
        startMinutes: _start,
        endMinutes: _end,
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conflicts = _validRange ? _conflicts : const <String>[];
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(widget.interval == null
                  ? 'Agregar intervalo'
                  : 'Corregir intervalo'),
              Text('Día', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final day in Weekday.values)
                    ChoiceChip(
                      label: Text(day.title.substring(0, 3)),
                      tooltip: day.title,
                      selected: _day == day,
                      onSelected: (_) => setState(() => _day = day),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _TimeButton(
                      label: 'Inicio',
                      minutes: _start,
                      onTap: () => _pick(start: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeButton(
                      label: 'Finalización',
                      minutes: _end,
                      error: !_validRange,
                      onTap: () => _pick(start: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _validRange
                    ? 'Duración: ${TimeRules.hoursLabel(TimeRules.durationMinutes(_start, _end))}'
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
                      child: Text(job.displayName,
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _jobKey = v),
              ),
              if (conflicts.isNotEmpty) ...[
                const SizedBox(height: 12),
                IssueTile(
                  blocking: true,
                  message: 'Se traslapa el ${_day.label} con '
                      '${conflicts.join(' y ')}. Puede guardarlo, pero la '
                      'declaración no se podrá validar hasta corregirlo.',
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _validRange && _jobKey != null ? _save : null,
                child: Text(widget.interval == null
                    ? 'Agregar al horario'
                    : 'Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.minutes,
    required this.onTap,
    this.error = false,
  });

  final String label;
  final int minutes;
  final VoidCallback onTap;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.access_time),
          errorText: error ? 'Revise la hora' : null,
        ),
        child: Text(
          TimeRules.format(minutes),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
