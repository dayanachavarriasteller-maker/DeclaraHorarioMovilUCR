import 'package:declara_horario/domain/rules/time_rules.dart';
import 'package:declara_horario/features/pdf/widgets/download_pdf_button.dart';
import 'package:declara_horario/models/models.dart';
import 'package:declara_horario_movil/domain/declaration_draft.dart';
import 'package:declara_horario_movil/features/declaration/declaration_controller.dart';
import 'package:declara_horario_movil/shared/widgets/ucr_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Resumen de la declaración (R6): datos generales, información laboral,
/// horario, horas totales, resultado de validaciones y estado.
///
/// Desde aquí se valida (`markValidated` del original). La firma, la
/// aprobación del superior y Recursos Humanos NO se hacen en el módulo
/// móvil, y la pantalla lo dice explícitamente.
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  Future<void> _validate(BuildContext context) async {
    final c = context.read<DeclarationController>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await c.validateAndMark();
    if (result == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(c.error ?? 'No se pudo validar.')),
      );
    } else if (result.hasBlocking) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'La declaración tiene problemas por corregir; no se '
            'marcó como VALIDADA.',
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Declaración guardada y marcada como VALIDADA.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DeclarationController>();
    final d = c.draft;
    final theme = Theme.of(context);
    final v = c.validation;
    final format = DateFormat('d MMM y', 'es');
    final canEdit = c.editable;
    // Si se abrió desde el formulario, «Corregir» vuelve a él con el dato.
    final fromForm = Navigator.of(context).canPop() && canEdit;
    // El PDF existe a partir de VALIDADA (`PdfState.buildPreview`) y debe
    // reflejar lo guardado, así que no se ofrece con cambios pendientes.
    final canDownload =
        c.declaration != null &&
        !c.dirty &&
        c.status != DeclarationStatus.borrador &&
        c.status != DeclarationStatus.devuelta;

    return Scaffold(
      appBar: AppBar(title: const Text('Resumen de la declaración')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (c.busy) const LinearProgressIndicator(),
          // Estado ----------------------------------------------------------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Estado',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      StatusChip(status: c.status!),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusText(c.status!, c.dirty),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Validaciones -----------------------------------------------------
          SectionTitle('Resultado de validaciones'),
          if (v == null || v.issues.isEmpty)
            IssueTile(
              blocking: false,
              success: true,
              message:
                  'Sin problemas: horario sin traslapes y rangos '
                  'correctos.',
            )
          else
            for (final issue in v.issues)
              IssueTile(
                message: issue.message,
                blocking: issue.blocking,
                onFix: fromForm ? () => Navigator.pop(context, issue) : null,
              ),
          const SizedBox(height: 8),

          // Datos generales -------------------------------------------------
          const SectionTitle('Datos generales'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  InfoRow('Nombre', d.fullName),
                  InfoRow('Identificación', d.identification),
                  InfoRow('Sede', d.campusName),
                  InfoRow('Unidad', d.unitName),
                  InfoRow('Período', c.period?.name ?? ''),
                  InfoRow('Versión', '${c.declaration?.currentVersionNumber}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Información laboral ---------------------------------------------
          const SectionTitle('Información laboral'),
          if (d.jobs.isEmpty) const Text('Sin nombramientos registrados.'),
          for (final job in d.jobs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.kind == JobKind.ucr
                            ? 'Universidad de Costa Rica'
                            : 'Otra institución (${_typeLabel(job.institutionType)})',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      InfoRow(
                        job.kind == JobKind.ucr ? 'Lugar' : 'Institución',
                        job.name,
                      ),
                      InfoRow('Puesto', job.position),
                      InfoRow('Jornada', job.workload),
                      InfoRow(
                        'Vigencia',
                        job.kind == JobKind.ucr
                            ? '${format.format(c.periodStart)} – ${format.format(c.periodEnd)}'
                            : '${job.startDate == null ? '?' : format.format(job.startDate!)} – '
                                  '${job.endDate == null ? '?' : format.format(job.endDate!)}',
                      ),
                      InfoRow(
                        'Horas',
                        job.weeklyMinutes == null
                            ? TimeRules.hoursLabel(d.minutesOf(job.key))
                            : TimeRules.hoursOf(
                                d.minutesOf(job.key),
                                job.weeklyMinutes!,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Horario ----------------------------------------------------------
          const SectionTitle('Horario semanal'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final day in Weekday.values)
                    ..._dayRows(context, d, day),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Horas totales registradas',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        TimeRules.hoursLabel(d.totalMinutes),
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                  if (v != null && d.ucrJobs.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'UCR: ${TimeRules.hoursOf(v.hoursSummary.declaredMinutes, v.hoursSummary.expectedMinutes)} '
                      'según la jornada.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          if (d.observations.trim().isNotEmpty) ...[
            const SectionTitle('Observaciones'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(d.observations.trim()),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Alcance ----------------------------------------------------------
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Este módulo móvil no firma la declaración. La firma de la '
              'persona declarante, la aprobación del superior y la '
              'recepción por Recursos Humanos se realizan en el sistema '
              'web DeclaraHorario.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
      bottomNavigationBar: canDownload && !canEdit
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: DownloadPdfButton(
                  declaration: c.declaration!,
                  label: 'Descargar PDF',
                  filled: true,
                ),
              ),
            )
          : !canEdit
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    if (fromForm) ...[
                      Expanded(
                        flex: canDownload ? 2 : 1,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Corregir'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (canDownload)
                      // Ya validada: el PDF del original (vista previa sin
                      // firmas) reemplaza al botón Validar.
                      Expanded(
                        flex: 3,
                        child: DownloadPdfButton(
                          declaration: c.declaration!,
                          label: 'Descargar PDF',
                          filled: true,
                        ),
                      )
                    else
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              c.busy ||
                                  (v?.hasBlocking ?? true) ||
                                  (c.status == DeclarationStatus.validada &&
                                      !c.dirty)
                              ? null
                              : () => _validate(context),
                          icon: const Icon(Icons.verified_outlined),
                          label: const Text('Validar'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  List<Widget> _dayRows(BuildContext context, DeclarationDraft d, Weekday day) {
    final items = d.sortedIntervals.where((i) => i.day == day).toList();
    if (items.isEmpty) return const <Widget>[];
    final theme = Theme.of(context);
    return <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Text(
          day.title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      for (final i in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 104,
                child: Text(
                  '${TimeRules.format(i.startMinutes)}–${TimeRules.format(i.endMinutes)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: Text(
                  d.jobByKey(i.jobKey)?.displayName ?? 'Sin asociar',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(TimeRules.hoursLabel(i.durationMinutes)),
            ],
          ),
        ),
    ];
  }

  static String _statusText(DeclarationStatus status, bool dirty) {
    if (dirty) {
      return 'Hay cambios sin guardar. Al validar se guardan y la '
          'declaración queda en VALIDADA si no hay errores.';
    }
    return switch (status) {
      DeclarationStatus.borrador =>
        'Borrador guardado. Corrija los problemas señalados y valide.',
      DeclarationStatus.validada =>
        'Validada sin errores bloqueantes. Queda lista para firmarse en el '
            'sistema web (aún NO está firmada).',
      DeclarationStatus.pendienteFirmaDeclarante =>
        'Pendiente de la firma de la persona declarante en el sistema web.',
      _ =>
        'La declaración avanzó en el flujo de firmas y revisión; aquí '
            'solo se puede consultar.',
    };
  }

  static String _typeLabel(InstitutionType type) => switch (type) {
    InstitutionType.public => 'pública',
    InstitutionType.private => 'privada',
    InstitutionType.foundation => 'fundación',
  };
}
