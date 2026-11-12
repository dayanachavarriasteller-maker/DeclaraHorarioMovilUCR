import 'package:declara_horario/domain/rules/time_rules.dart';
import 'package:declara_horario/domain/rules/workload_catalog.dart';
import 'package:declara_horario/models/models.dart';
import 'package:declara_horario/shared/validators/form_validators.dart';
import 'package:declara_horario_movil/core/navigation.dart';
import 'package:declara_horario_movil/domain/declaration_draft.dart';
import 'package:declara_horario_movil/domain/mobile_validator.dart';
import 'package:declara_horario_movil/features/declaration/declaration_controller.dart';
import 'package:declara_horario_movil/features/declaration/interval_sheet.dart';
import 'package:declara_horario_movil/shared/widgets/ucr_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Formulario de la declaración (R2) y registro de horario (R3), en cuatro
/// pestañas para que quepa en pantallas pequeñas sin desbordes.
class DeclarationFormScreen extends StatefulWidget {
  const DeclarationFormScreen({super.key});

  @override
  State<DeclarationFormScreen> createState() => _DeclarationFormScreenState();
}

class _DeclarationFormScreenState extends State<DeclarationFormScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  static const int _tabGeneral = 0;
  static const int _tabJobs = 1;
  static const int _tabSchedule = 2;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Lleva a la persona al dato que debe corregir (R4).
  Future<void> _goTo(MobileIssue issue) async {
    final c = context.read<DeclarationController>();
    switch (issue.target) {
      case IssueTarget.general:
        _tabs.animateTo(_tabGeneral);
      case IssueTarget.job:
        _tabs.animateTo(_tabJobs);
      case IssueTarget.schedule:
        _tabs.animateTo(_tabSchedule);
      case IssueTarget.interval:
        _tabs.animateTo(_tabSchedule);
        final key = issue.targetKeys.isEmpty ? null : issue.targetKeys.last;
        final interval =
            c.draft.intervals.where((i) => i.key == key).firstOrNull;
        if (interval != null) {
          await showIntervalSheet(context, c, interval: interval);
        }
    }
  }

  Future<void> _save() async {
    final c = context.read<DeclarationController>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await c.saveDraft();
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Borrador guardado.'
          : c.error ?? 'No se pudo guardar el borrador.'),
    ));
  }

  Future<void> _summary() async {
    final c = context.read<DeclarationController>();
    final issue = await openSummary(context, c);
    if (issue != null && mounted) await _goTo(issue);
  }

  Future<bool> _confirmLeave() async {
    final c = context.read<DeclarationController>();
    if (!c.dirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambios sin guardar'),
        content: const Text(
            '¿Desea salir sin guardar el borrador? Se perderán los cambios.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir sin guardar'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DeclarationController>();
    final blocking = c.validation?.blocking.length ?? 0;
    return PopScope(
      canPop: !c.dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Declaración jurada'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: StatusChip(status: c.status!)),
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Datos'),
              Tab(text: 'Trabajo'),
              Tab(text: 'Horario'),
              Tab(text: 'Notas'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (c.busy) const LinearProgressIndicator(),
            if (c.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: IssueTile(message: c.error!, blocking: true),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [
                  _GeneralTab(),
                  _JobsTab(),
                  _ScheduleTab(),
                  _NotesTab(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (blocking > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        blocking == 1
                            ? '1 problema pendiente de corregir'
                            : '$blocking problemas pendientes de corregir',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: c.busy ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Guardar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: c.busy ? null : _summary,
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Resumen'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- Datos

class _GeneralTab extends StatelessWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DeclarationController>();
    final d = c.draft;
    final format = DateFormat('d MMM y', 'es');
    final issues = c.validation?.issues
            .where((i) => i.target == IssueTarget.general)
            .toList() ??
        const <MobileIssue>[];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle('Persona declarante'),
        TextFormField(
          key: const ValueKey('fullName'),
          initialValue: d.fullName,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre completo *'),
          autovalidateMode: AutovalidateMode.always,
          validator: FormValidators.notEmpty,
          onChanged: (v) {
            d.fullName = v;
            c.changed();
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          key: const ValueKey('identification'),
          initialValue: d.identification,
          keyboardType: d.identificationType == IdentificationType.nationalId
              ? TextInputType.number
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: 'Identificación (${d.identificationType.label}) *',
            helperText: d.identificationType == IdentificationType.nationalId
                ? 'Nueve dígitos, sin guiones'
                : null,
          ),
          autovalidateMode: AutovalidateMode.always,
          validator: (v) =>
              FormValidators.identification(v, d.identificationType),
          onChanged: (v) {
            d.identification = v;
            c.changed();
          },
        ),
        const SizedBox(height: 20),
        const SectionTitle('Datos del perfil'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                InfoRow('Sede', d.campusName),
                InfoRow('Unidad', d.unitName),
                InfoRow('Correo', d.email),
                InfoRow('Teléfono', d.phone),
                InfoRow(
                  'Período',
                  c.period == null
                      ? ''
                      : '${c.period!.name}\n'
                          '${format.format(c.periodStart)} – ${format.format(c.periodEnd)}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sede, unidad y contacto se toman del perfil del sistema web.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final i in issues)
            IssueTile(message: i.message, blocking: i.blocking),
        ],
      ],
    );
  }
}

// ----------------------------------------------------------------- Trabajo

class _JobsTab extends StatelessWidget {
  const _JobsTab();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DeclarationController>();
    final d = c.draft;
    final general = c.validation?.issues
            .where((i) => i.target == IssueTarget.job && i.targetKeys.isEmpty)
            .toList() ??
        const <MobileIssue>[];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle(
          'Universidad de Costa Rica',
          trailing: TextButton.icon(
            onPressed: () => c.addJob(JobKind.ucr),
            icon: const Icon(Icons.add),
            label: const Text('Nombramiento'),
          ),
        ),
        if (d.ucrJobs.isEmpty)
          const _EmptyHint('Agregue su nombramiento en la UCR.'),
        for (final job in d.ucrJobs) _JobCard(job: job),
        const SizedBox(height: 16),
        SectionTitle(
          'Otras instituciones',
          trailing: TextButton.icon(
            onPressed: () => c.addJob(JobKind.external),
            icon: const Icon(Icons.add),
            label: const Text('Institución'),
          ),
        ),
        if (d.externalJobs.isEmpty)
          const _EmptyHint(
              'Si labora en otra institución pública, privada o fundación, '
              'agréguela aquí.'),
        for (final job in d.externalJobs) _JobCard(job: job),
        if (general.isNotEmpty) const SizedBox(height: 8),
        for (final i in general)
          IssueTile(message: i.message, blocking: i.blocking),
      ],
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final DraftJob job;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DeclarationController>();
    final theme = Theme.of(context);
    final format = DateFormat('d MMM y', 'es');
    final isUcr = job.kind == JobKind.ucr;
    final options =
        isUcr ? WorkloadCatalog.options : WorkloadCatalog.externalOptions;
    final issues = c.validation?.issues
            .where((i) => i.targetKeys.contains(job.key))
            .where((i) => i.target == IssueTarget.job)
            .toList() ??
        const <MobileIssue>[];
    final registered = c.draft.minutesOf(job.key);
    final expected = job.weeklyMinutes;

    void set(void Function() change) {
      change();
      c.changed();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(isUcr ? Icons.school_outlined : Icons.business_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isUcr ? 'Nombramiento UCR' : 'Otra institución',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, c),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    TextFormField(
                      key: ValueKey('${job.key}-name'),
                      initialValue: job.name,
                      decoration: InputDecoration(
                        labelText: isUcr
                            ? 'Lugar de trabajo (unidad) *'
                            : 'Institución *',
                      ),
                      autovalidateMode: AutovalidateMode.always,
                      validator: FormValidators.notEmpty,
                      onChanged: (v) => set(() => job.name = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: ValueKey('${job.key}-position'),
                      initialValue: job.position,
                      decoration:
                          const InputDecoration(labelText: 'Puesto *'),
                      autovalidateMode: AutovalidateMode.always,
                      validator: FormValidators.notEmpty,
                      onChanged: (v) => set(() => job.position = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('${job.key}-workload'),
                      initialValue: options.any((o) => o.label == job.workload)
                          ? job.workload
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Tipo de jornada *'),
                      autovalidateMode: AutovalidateMode.always,
                      validator: (v) =>
                          v == null ? 'Seleccione la jornada.' : null,
                      items: [
                        for (final o in options)
                          DropdownMenuItem(
                            value: o.label,
                            child: Text(
                                '${o.label} · ${TimeRules.hoursLabel(o.weeklyMinutes)} semanales'),
                          ),
                      ],
                      onChanged: (v) => set(() => job.workload = v ?? ''),
                    ),
                    if (!isUcr) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<InstitutionType>(
                        key: ValueKey('${job.key}-type'),
                        initialValue: job.institutionType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Tipo de institución *'),
                        items: const [
                          DropdownMenuItem(
                              value: InstitutionType.public,
                              child: Text('Pública')),
                          DropdownMenuItem(
                              value: InstitutionType.private,
                              child: Text('Privada')),
                          DropdownMenuItem(
                              value: InstitutionType.foundation,
                              child: Text('Fundación')),
                        ],
                        onChanged: (v) => set(() =>
                            job.institutionType = v ?? InstitutionType.public),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (isUcr)
                      InfoRow(
                        'Vigencia',
                        '${format.format(c.periodStart)} – ${format.format(c.periodEnd)} (período)',
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _DateField(
                              label: 'Desde *',
                              value: job.startDate,
                              onPicked: (v) => set(() => job.startDate = v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DateField(
                              label: 'Hasta *',
                              value: job.endDate,
                              onPicked: (v) => set(() => job.endDate = v),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Text(
                      expected == null
                          ? 'Horario registrado: ${TimeRules.hoursLabel(registered)}'
                          : 'Horario registrado: ${TimeRules.hoursOf(registered, expected)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (issues.isNotEmpty) const SizedBox(height: 8),
                    for (final i in issues)
                      IssueTile(message: i.message, blocking: i.blocking),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, DeclarationController c) async {
    final count = c.draft.intervalsOf(job.key).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Eliminar ${job.displayName}?'),
        content: Text(count == 0
            ? 'Se eliminará al guardar el borrador.'
            : 'También se eliminarán sus $count intervalos de horario.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok ?? false) c.removeJob(job);
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPicked,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '' : DateFormat('d/M/y', 'es').format(value!);
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 5),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
          errorText: value == null ? 'Requerida' : null,
        ),
        child: Text(text),
      ),
    );
  }
}

// ----------------------------------------------------------------- Horario

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DeclarationController>();
    final d = c.draft;
    final theme = Theme.of(context);
    final conflictKeys = <String>{
      for (final i in c.validation?.blocking ?? const <MobileIssue>[])
        if (i.target == IssueTarget.interval) ...i.targetKeys,
    };
    final scheduleIssues = c.validation?.issues
            .where((i) =>
                i.target == IssueTarget.interval ||
                i.target == IssueTarget.schedule)
            .toList() ??
        const <MobileIssue>[];

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Total registrado',
                          style: theme.textTheme.titleSmall),
                    ),
                    Text(
                      TimeRules.hoursLabel(d.totalMinutes),
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final issue in scheduleIssues)
              IssueTile(
                message: issue.message,
                blocking: issue.blocking,
                onFix: issue.target == IssueTarget.interval &&
                        issue.targetKeys.isNotEmpty
                    ? () {
                        final interval = d.intervals
                            .where((i) => i.key == issue.targetKeys.last)
                            .firstOrNull;
                        if (interval != null) {
                          showIntervalSheet(context, c, interval: interval);
                        }
                      }
                    : null,
              ),
            if (d.jobs.isEmpty)
              const _EmptyHint('Primero agregue un nombramiento en la pestaña '
                  '«Trabajo»; luego registre aquí su horario.'),
            for (final day in Weekday.values)
              _DaySection(day: day, conflictKeys: conflictKeys),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'add-interval',
            onPressed: d.jobs.isEmpty
                ? null
                : () => showIntervalSheet(context, c),
            icon: const Icon(Icons.more_time),
            label: const Text('Agregar intervalo'),
          ),
        ),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.day, required this.conflictKeys});

  final Weekday day;
  final Set<String> conflictKeys;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DeclarationController>();
    final theme = Theme.of(context);
    final items = c.draft.sortedIntervals.where((i) => i.day == day).toList();
    final total = items.fold<int>(0, (s, i) => s + i.durationMinutes);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(day.title, style: theme.textTheme.titleSmall),
                  ),
                  Text(
                    items.isEmpty ? 'Sin horario' : TimeRules.hoursLabel(total),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              for (final i in items)
                _IntervalTile(
                  interval: i,
                  conflict: conflictKeys.contains(i.key),
                ),
              if (items.isEmpty) const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntervalTile extends StatelessWidget {
  const _IntervalTile({required this.interval, required this.conflict});

  final DraftInterval interval;
  final bool conflict;

  @override
  Widget build(BuildContext context) {
    final c = context.read<DeclarationController>();
    final scheme = Theme.of(context).colorScheme;
    final job = c.draft.jobByKey(interval.jobKey);
    return Container(
      margin: const EdgeInsets.only(top: 6, right: 8),
      decoration: BoxDecoration(
        color: conflict ? scheme.errorContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: conflict ? scheme.error : scheme.outlineVariant,
          width: conflict ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 12, right: 0),
        minVerticalPadding: 8,
        onTap: () => showIntervalSheet(context, c, interval: interval),
        title: Text(
          '${TimeRules.format(interval.startMinutes)} – '
          '${TimeRules.format(interval.endMinutes)}'
          '  ·  ${TimeRules.hoursLabel(interval.durationMinutes)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            job?.displayName ?? 'Sin institución asociada',
            if (conflict) 'Conflicto: toque para corregir',
          ].join('\n'),
          style: TextStyle(color: conflict ? scheme.onErrorContainer : null),
        ),
        trailing: IconButton(
          tooltip: 'Eliminar intervalo',
          icon: const Icon(Icons.close),
          onPressed: () => c.removeInterval(interval),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- Notas

class _NotesTab extends StatelessWidget {
  const _NotesTab();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DeclarationController>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle('Observaciones'),
        TextFormField(
          key: const ValueKey('observations'),
          initialValue: c.draft.observations,
          minLines: 5,
          maxLines: 10,
          maxLength: 1000,
          decoration: const InputDecoration(
            hintText: 'Aclaraciones sobre su jornada u horario (opcional).',
            alignLabelWithHint: true,
          ),
          onChanged: (v) {
            c.draft.observations = v;
            c.changed();
          },
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}
