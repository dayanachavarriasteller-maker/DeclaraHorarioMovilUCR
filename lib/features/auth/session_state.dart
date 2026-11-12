import 'dart:async';

import 'package:declara_horario/core/errors/app_exception.dart';
import 'package:declara_horario/models/models.dart';
import 'package:declara_horario/repositories/user_repository.dart';
import 'package:declara_horario/services/auth_service.dart';
import 'package:flutter/foundation.dart';

/// Sesión del teléfono. Reutiliza el [AuthService] y el [UserRepository]
/// del sistema original: no se reconstruye la autenticación (R5).
class SessionState extends ChangeNotifier {
  SessionState({required this.auth, required this.users}) {
    _sub = auth.authStateChanges().listen(_onUid);
  }

  final AuthService auth;
  final UserRepository users;
  StreamSubscription<String?>? _sub;

  /// `true` hasta que Firebase informa si hay sesión.
  bool starting = true;
  bool busy = false;
  String? error;
  AppUser? user;

  Future<void> _onUid(String? uid) async {
    if (uid == null) {
      user = null;
      starting = false;
      notifyListeners();
      return;
    }
    try {
      final profile = await users.getById(uid);
      if (profile == null) {
        error = 'La cuenta no tiene perfil en el sistema.';
        await auth.signOut();
        return;
      }
      if (!profile.active || !profile.roles.contains(UserRole.declarant)) {
        error = 'El módulo móvil es para personas declarantes con la cuenta '
            'activa. Use el sistema web para otros roles.';
        await auth.signOut();
        return;
      }
      user = profile;
    } catch (e) {
      error = e is AppException ? e.message : '$e';
    } finally {
      starting = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      error = e is AppException ? e.message : 'No se pudo iniciar sesión.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() => auth.signOut();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
