import 'package:declara_horario/core/config/firebase_emulators.dart';
import 'package:declara_horario/core/config/firebase_options.dart';
import 'package:declara_horario_movil/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Punto de entrada. Usa la MISMA configuración de Firebase y el mismo
/// conector a emuladores del sistema original.
///
/// Con datos locales:
///   flutter run -d chrome --dart-define=USE_EMULATORS=true
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (FirebaseEmulators.enabled) {
    await FirebaseEmulators.connect();
  }
  runApp(const DeclaraHorarioMovilApp());
}
