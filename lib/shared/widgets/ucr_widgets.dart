import 'package:declara_horario/models/models.dart';
import 'package:declara_horario_movil/core/theme/ucr_theme.dart';
import 'package:flutter/material.dart';

/// Firma institucional oficial (assets/images/firma_ucr.png).
///
/// El Manual de Identidad Visual prohíbe reconstruir o deformar la firma,
/// así que solo se muestra el archivo oficial, escalado proporcionalmente
/// (`BoxFit.contain`) y sobre fondo blanco. Si el archivo aún no se ha
/// colocado, se muestra el nombre de la institución en texto, nunca un
/// logotipo inventado.
class UcrSignature extends StatelessWidget {
  const UcrSignature({super.key, this.height = 56});

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Universidad de Costa Rica',
      image: true,
      child: SizedBox(
        height: height,
        child: Image.asset(
          'assets/images/firma_ucr.png',
          fit: BoxFit.contain,
          errorBuilder: (context, _, _) => Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'UNIVERSIDAD DE\nCOSTA RICA',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                height: 1.1,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Encabezado institucional: firma sobre blanco + franja celeste.
class UcrBrandBar extends StatelessWidget {
  const UcrBrandBar({super.key, this.subtitle, this.signatureHeight = 56});

  final String? subtitle;

  /// Alto de la firma. 56 dp es el mínimo del cintillo (manual, p. 117).
  final double signatureHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stripe = theme.extension<UcrStatusColors>()!.accentStripe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              UcrSignature(height: signatureHeight),
              const Spacer(),
              if (subtitle != null)
                Flexible(
                  child: Text(
                    subtitle!,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(height: 4, color: stripe),
      ],
    );
  }
}

/// Etiqueta de estado con el nombre EXACTO del sistema original
/// (`BORRADOR`, `VALIDADA`, `PENDIENTE_FIRMA_DECLARANTE`...) (R1).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final DeclarationStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<UcrStatusColors>()!;
    final background = switch (status) {
      DeclarationStatus.borrador || DeclarationStatus.devuelta => colors.draft,
      DeclarationStatus.validada ||
      DeclarationStatus.finalizada =>
        colors.validated,
      DeclarationStatus.pendienteFirmaDeclarante ||
      DeclarationStatus.pendienteFirmaSuperior =>
        colors.pending,
      _ => colors.other,
    };
    return Semantics(
      label: 'Estado ${status.value}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          status.value,
          style: TextStyle(
            color: colors.onStatus,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

/// Título de sección con el azul institucional.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Fila "etiqueta: valor" para resúmenes.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso de un hallazgo de validación.
class IssueTile extends StatelessWidget {
  const IssueTile({
    super.key,
    required this.message,
    required this.blocking,
    this.onFix,
    this.success = false,
  });

  final String message;
  final bool blocking;
  final VoidCallback? onFix;

  /// Mensaje de éxito (verde UCR con texto oscuro).
  final bool success;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = Theme.of(context).extension<UcrStatusColors>()!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: blocking
            ? scheme.errorContainer
            : (success ? colors.validated : colors.draft)
                .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: blocking ? scheme.error : colors.onStatus,
            width: 4,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              blocking
                  ? Icons.error_outline
                  : success
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
              color: blocking ? scheme.error : colors.onStatus,
              size: 20,
              semanticLabel: blocking
                  ? 'Error'
                  : success
                      ? 'Correcto'
                      : 'Advertencia',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: blocking ? scheme.onErrorContainer : colors.onStatus,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
          if (onFix != null)
            TextButton(onPressed: onFix, child: const Text('Corregir')),
        ],
      ),
    );
  }
}
