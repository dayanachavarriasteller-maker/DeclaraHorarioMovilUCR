import 'package:flutter/material.dart';

/// Paleta institucional de la Universidad de Costa Rica.
///
/// Es el ÚNICO lugar donde se escriben códigos de color: los widgets leen el
/// tema (`Theme.of(context)`) y nunca usan estos valores directamente
/// (laboratorio §5.1).
///
/// Contraste (WCAG 2.1, texto normal requiere 4,5:1):
/// * Azul UCR #005DA4 sobre blanco: 6,8:1 → apto para texto y botones.
/// * Celeste UCR #00C0F3 sobre blanco: 2,1:1 → NO apto para texto; se usa
///   solo como franja/acento decorativo, o con texto azul oscuro encima.
/// * Amarillo UCR #FFE06A y Verde UCR #6DC067 sobre blanco tampoco alcanzan
///   4,5:1; por eso se usan como fondo de etiquetas con texto oscuro
///   ([ink]) encima (12,4:1 y 7,2:1).
class UcrColors {
  const UcrColors._();

  /// Celeste UCR: encabezados y acentos institucionales.
  static const Color celeste = Color(0xFF00C0F3);

  /// Azul UCR: botones, navegación y títulos.
  static const Color azul = Color(0xFF005DA4);

  /// Blanco: fondos y superficies.
  static const Color blanco = Color(0xFFFFFFFF);

  /// Amarillo UCR: acentos secundarios (estado BORRADOR).
  static const Color amarillo = Color(0xFFFFE06A);

  /// Verde UCR: estados correctos (VALIDADA), siempre con texto oscuro.
  static const Color verde = Color(0xFF6DC067);

  /// Texto principal sobre fondos claros (azul casi negro, 16:1 sobre
  /// blanco). Derivado del azul UCR para mantener la familia de color.
  static const Color ink = Color(0xFF0B2239);

  /// Texto secundario (7,7:1 sobre blanco).
  static const Color inkMuted = Color(0xFF44546A);

  /// Fondo de la aplicación: blanco con un tinte mínimo del celeste.
  static const Color fondo = Color(0xFFF3F8FC);

  /// Rojo de error (6,5:1 sobre blanco). No es color institucional: lo exige
  /// la accesibilidad para mensajes de error.
  static const Color error = Color(0xFFB3261E);

  /// Fondo suave de los avisos de error.
  static const Color errorFondo = Color(0xFFFCE8E6);
}
