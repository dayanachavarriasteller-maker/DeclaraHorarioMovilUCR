import 'package:declara_horario_movil/core/providers.dart';
import 'package:declara_horario_movil/core/theme/ucr_theme.dart';
import 'package:declara_horario_movil/features/auth/login_screen.dart';
import 'package:declara_horario_movil/features/auth/session_state.dart';
import 'package:declara_horario_movil/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

/// Aplicación móvil DeclaraHorario.
class DeclaraHorarioMovilApp extends StatelessWidget {
  const DeclaraHorarioMovilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: buildProviders(),
      child: MaterialApp(
        title: 'DeclaraHorario móvil · UCR',
        debugShowCheckedModeBanner: false,
        theme: UcrTheme.light(),
        locale: const Locale('es', 'CR'),
        supportedLocales: const [Locale('es', 'CR'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // Con emuladores, Firebase ya muestra su propio aviso al pie.
        builder: (context, child) => PhoneFrame(child: child!),
        home: const _SessionGate(),
      ),
    );
  }
}

class _SessionGate extends StatelessWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    if (session.starting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return session.user == null ? const LoginScreen() : const HomeScreen();
  }
}

/// En una pantalla ancha (navegador de escritorio) dibuja la app dentro de
/// un marco del tamaño de un teléfono (412 × 892 dp, como un Pixel 7), para
/// probar la vista móvil. En un teléfono real no hace nada.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  static const Size phone = Size(412, 892);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= 600) return child;
    final height =
        media.size.height - 32 < phone.height ? media.size.height - 32 : phone.height;
    return ColoredBox(
      color: const Color(0xFF0B2239),
      child: Center(
        child: Container(
          width: phone.width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF44546A), width: 6),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: MediaQuery(
              data: media.copyWith(
                size: Size(phone.width - 12, height - 12),
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
