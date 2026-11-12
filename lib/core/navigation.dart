import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:declara_horario/repositories/declaration_repository.dart';
import 'package:declara_horario/repositories/period_repository.dart';
import 'package:declara_horario/repositories/version_content_repository.dart';
import 'package:declara_horario/services/workflow_service.dart';
import 'package:declara_horario_movil/domain/mobile_validator.dart';
import 'package:declara_horario_movil/features/auth/session_state.dart';
import 'package:declara_horario_movil/features/declaration/declaration_controller.dart';
import 'package:declara_horario_movil/features/declaration/declaration_form_screen.dart';
import 'package:declara_horario_movil/features/summary/summary_screen.dart';
import 'package:declara_horario_movil/shared/widgets/ucr_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Abre una declaración: el formulario si es editable o, si ya avanzó en el
/// flujo de firmas, directamente su resumen de solo lectura.
Future<void> openDeclaration(BuildContext context, String declarationId) {
  final controller = DeclarationController(
    declarationId: declarationId,
    actor: context.read<SessionState>().user!,
    declarations: context.read<DeclarationRepository>(),
    versions: context.read<VersionContentRepository>(),
    periods: context.read<PeriodRepository>(),
    workflow: context.read<WorkflowService>(),
    firestore: FirebaseFirestore.instance,
  )..load();
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => ChangeNotifierProvider<DeclarationController>.value(
      value: controller,
      child: const _DeclarationGate(),
    ),
  )).whenComplete(controller.dispose);
}

/// Abre el resumen de la declaración ya cargada en [controller]. Si la
/// persona toca «Corregir» en un hallazgo, devuelve ese hallazgo para que el
/// formulario la lleve al dato.
Future<MobileIssue?> openSummary(
  BuildContext context,
  DeclarationController controller,
) =>
    Navigator.of(context).push(MaterialPageRoute<MobileIssue>(
      builder: (_) => ChangeNotifierProvider<DeclarationController>.value(
        value: controller,
        child: const SummaryScreen(),
      ),
    ));

class _DeclarationGate extends StatelessWidget {
  const _DeclarationGate();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DeclarationController>();
    if (c.loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Declaración')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (c.declaration == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Declaración')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: IssueTile(
            message: c.error ?? 'No se pudo abrir la declaración.',
            blocking: true,
          ),
        ),
      );
    }
    return c.editable ? const DeclarationFormScreen() : const SummaryScreen();
  }
}
