import 'package:declara_horario_movil/core/theme/ucr_colors.dart';
import 'package:flutter/material.dart';

/// Colores de estado que no caben en [ColorScheme]: se exponen como
/// extensión del tema para que ningún widget escriba un color a mano.
@immutable
class UcrStatusColors extends ThemeExtension<UcrStatusColors> {
  const UcrStatusColors({
    required this.draft,
    required this.validated,
    required this.pending,
    required this.other,
    required this.onStatus,
    required this.accentStripe,
  });

  /// BORRADOR (amarillo UCR).
  final Color draft;

  /// VALIDADA (verde UCR).
  final Color validated;

  /// Estados de firma pendiente (celeste UCR).
  final Color pending;

  /// Resto de estados del flujo completo.
  final Color other;

  /// Texto sobre cualquiera de los anteriores.
  final Color onStatus;

  /// Franja celeste institucional bajo el encabezado.
  final Color accentStripe;

  static const UcrStatusColors ucr = UcrStatusColors(
    draft: UcrColors.amarillo,
    validated: UcrColors.verde,
    pending: UcrColors.celeste,
    other: Color(0xFFDCE6F0),
    onStatus: UcrColors.ink,
    accentStripe: UcrColors.celeste,
  );

  @override
  UcrStatusColors copyWith({
    Color? draft,
    Color? validated,
    Color? pending,
    Color? other,
    Color? onStatus,
    Color? accentStripe,
  }) =>
      UcrStatusColors(
        draft: draft ?? this.draft,
        validated: validated ?? this.validated,
        pending: pending ?? this.pending,
        other: other ?? this.other,
        onStatus: onStatus ?? this.onStatus,
        accentStripe: accentStripe ?? this.accentStripe,
      );

  @override
  UcrStatusColors lerp(UcrStatusColors? other, double t) => this;
}

/// Tema institucional UCR (Manual de Identidad Visual, aplicaciones
/// electrónicas): azul UCR para navegación y acciones, celeste como acento,
/// fondos blancos y tipografía Trueno (la prevista para medios electrónicos),
/// con Arimo (sustituta de Arial) solo como respaldo para símbolos.
class UcrTheme {
  const UcrTheme._();

  /// Familia tipográfica declarada en pubspec.yaml.
  static const String fontFamily = 'Trueno';

  /// Respaldo para caracteres que Trueno no incluye.
  static const List<String> fontFamilyFallback = <String>['Arimo'];

  /// Altura mínima de los controles táctiles (Material: 48 dp).
  static const double minTouch = 48;

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: UcrColors.azul,
      onPrimary: UcrColors.blanco,
      primaryContainer: Color(0xFFD6E9F8),
      onPrimaryContainer: UcrColors.ink,
      secondary: UcrColors.celeste,
      onSecondary: UcrColors.ink,
      secondaryContainer: Color(0xFFD9F5FD),
      onSecondaryContainer: UcrColors.ink,
      tertiary: UcrColors.verde,
      onTertiary: UcrColors.ink,
      error: UcrColors.error,
      onError: UcrColors.blanco,
      errorContainer: UcrColors.errorFondo,
      onErrorContainer: Color(0xFF5F1410),
      surface: UcrColors.blanco,
      onSurface: UcrColors.ink,
      onSurfaceVariant: UcrColors.inkMuted,
      outline: Color(0xFF8193A8),
      outlineVariant: Color(0xFFD3DDE7),
      surfaceContainerLowest: UcrColors.blanco,
      surfaceContainerLow: UcrColors.fondo,
      surfaceContainer: UcrColors.fondo,
      surfaceContainerHigh: Color(0xFFE9F1F8),
      surfaceContainerHighest: Color(0xFFE1EBF4),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      scaffoldBackgroundColor: UcrColors.fondo,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );

    final text = base.textTheme.apply(
      bodyColor: UcrColors.ink,
      displayColor: UcrColors.ink,
    );

    return base.copyWith(
      extensions: const <ThemeExtension<dynamic>>[UcrStatusColors.ucr],
      textTheme: text.copyWith(
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: UcrColors.azul,
        ),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 15, height: 1.35),
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 16, height: 1.35),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: UcrColors.azul,
        foregroundColor: UcrColors.blanco,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: UcrColors.blanco,
        ),
      ),
      cardTheme: const CardThemeData(
        color: UcrColors.blanco,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Color(0xFFD3DDE7)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, minTouch),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, minTouch),
          foregroundColor: UcrColors.azul,
          side: const BorderSide(color: UcrColors.azul),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, minTouch),
          foregroundColor: UcrColors.azul,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: UcrColors.azul,
        foregroundColor: UcrColors.blanco,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: UcrColors.blanco,
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF8193A8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: UcrColors.azul, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: UcrColors.blanco,
        unselectedLabelColor: Color(0xFFD6E9F8),
        indicatorColor: UcrColors.celeste,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontWeight: FontWeight.w700,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: UcrColors.ink,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          color: UcrColors.blanco,
          fontSize: 15,
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFD3DDE7)),
    );
  }
}
