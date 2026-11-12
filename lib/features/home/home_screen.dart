import 'package:declara_horario/models/models.dart';
import 'package:declara_horario/repositories/declaration_repository.dart';
import 'package:declara_horario/repositories/period_repository.dart';
import 'package:declara_horario_movil/core/navigation.dart';
import 'package:declara_horario_movil/features/auth/session_state.dart';
import 'package:declara_horario_movil/features/declaration/declaration_controller.dart';
import 'package:declara_horario_movil/shared/widgets/ucr_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Pantalla principal (R1): identifica el sistema, lista las declaraciones
/// de la persona con su estado y permite crear una nueva o abrir un borrador.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionState>().user!;
    final declarations = context.read<DeclarationRepository>();
    final periods = context.read<PeriodRepository>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Declaraciones Juradas'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<SessionState>().signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, user),
        icon: const Icon(Icons.add),
        label: const Text('Nueva declaración'),
      ),
      body: StreamBuilder<List<Period>>(
        stream: periods.watchAll(),
        builder: (context, periodSnap) {
          final periodNames = <String, String>{
            for (final p in periodSnap.data ?? const <Period>[]) p.id: p.name,
          };
          return StreamBuilder<List<Declaration>>(
            stream: declarations.watchByDeclarant(user.uid),
            builder: (context, snap) {
              final items = snap.data ?? const <Declaration>[];
              return ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  const UcrBrandBar(subtitle: 'Sede del Sur'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                    child: Text(
                      'Sistema de Declaraciones Juradas de Horario y '
                      'Jornada de Trabajo',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      user.fullName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SectionTitle('Mis declaraciones'),
                  ),
                  if (snap.hasError)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: IssueTile(
                        message: DeclarationController.messageOf(snap.error!),
                        blocking: true,
                      ),
                    )
                  else if (!snap.hasData)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Aún no tiene declaraciones. Toque «Nueva '
                        'declaración» para crear un borrador.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    )
                  else
                    for (final d in items)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _DeclarationCard(
                          declaration: d,
                          periodName: periodNames[d.periodId] ?? d.periodId,
                        ),
                      ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Crea una declaración en BORRADOR con `createDraft` del original.
  Future<void> _create(BuildContext context, AppUser user) async {
    final messenger = ScaffoldMessenger.of(context);
    if (user.superiorUid == null || user.campusId == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Su perfil aún no tiene sede o superior asignado. '
            'Solicítelo a la administración.'),
      ));
      return;
    }
    final period = await showModalBottomSheet<Period>(
      context: context,
      showDragHandle: true,
      builder: (context) => _PeriodPicker(
        periods: context.read<PeriodRepository>(),
      ),
    );
    if (period == null || !context.mounted) return;
    try {
      final created = await context.read<DeclarationRepository>().createDraft(
            declarant: user,
            periodId: period.id,
            superiorUid: user.superiorUid!,
          );
      if (!context.mounted) return;
      await openDeclaration(context, created.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(
          'No se pudo crear la declaración de ${period.name}. Solo se '
          'permite una por período y la coordinación debe haberle asignado '
          'cursos. (${DeclarationController.messageOf(e)})',
        ),
      ));
    }
  }
}

class _DeclarationCard extends StatelessWidget {
  const _DeclarationCard({required this.declaration, required this.periodName});

  final Declaration declaration;
  final String periodName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final updated = declaration.updatedAt;
    final isDraft = declaration.status == DeclarationStatus.borrador;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openDeclaration(context, declaration.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(periodName, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusChip(status: declaration.status),
                        Text(
                          'Versión ${declaration.currentVersionNumber}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (updated != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Actualizada ${DateFormat('d MMM y, h:mm a', 'es').format(updated)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                isDraft ? Icons.edit_note : Icons.chevron_right,
                color: theme.colorScheme.primary,
                semanticLabel: isDraft ? 'Abrir borrador' : 'Ver declaración',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.periods});

  final PeriodRepository periods;

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('d MMM y', 'es');
    return SafeArea(
      child: StreamBuilder<List<Period>>(
        stream: periods.watchEnabled(),
        builder: (context, snap) {
          final items = snap.data ?? const <Period>[];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SectionTitle('¿Para qué período?'),
              ),
              if (!snap.hasData)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay períodos habilitados.'),
                ),
              for (final p in items)
                ListTile(
                  minVerticalPadding: 12,
                  leading: const Icon(Icons.event_note),
                  title: Text(p.name),
                  subtitle: Text(
                    '${format.format(p.startDate)} – ${format.format(p.endDate)}',
                  ),
                  onTap: () => Navigator.pop(context, p),
                ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}
