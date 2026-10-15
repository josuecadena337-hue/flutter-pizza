import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/firebase_auth_service.dart';

/// Controlador de Autenticación con Provider (`ChangeNotifier`).
///
/// ¿Qué hace esta clase?
/// - Es el puente entre la interfaz de usuario (Login/Registro) y el servicio de Firebase.
/// - Guarda el estado del usuario activo (`currentUser`) y el estado de carga (`isLoading`).
/// - Cuando algo cambia, llama a `notifyListeners()` para que Flutter redibuje la pantalla automáticamente.
class AuthController with ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthController() {
    _checkInitialAuth();
  }

  /// Verifica si ya había una sesión guardada en el dispositivo al abrir la app
  Future<void> _checkInitialAuth() async {
    final firebaseUser = _authService.currentFirebaseUser;
    if (firebaseUser != null) {
      _isLoading = true;
      notifyListeners();
      try {
        _currentUser = await _authService.getUserProfile(firebaseUser.uid);
      } catch (e) {
        _currentUser = null;
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Inicia sesión con correo y contraseña.
  /// Obtiene el usuario de Firestore y almacena su rol.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signIn(
        email: email.trim(),
        password: password.trim(),
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getFriendlyFirebaseAuthError(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Registra un nuevo CLIENTE en Firebase Auth y Firestore.
  Future<bool> registerClient({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.registerClient(
        name: name.trim(),
        email: email.trim(),
        password: password.trim(),
        phone: phone?.trim(),
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getFriendlyFirebaseAuthError(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Cierra la sesión activa en Firebase y limpia la memoria de la app
  Future<void> logout() async {
    await _authService.signOut();
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Traduce los códigos de error técnicos de Firebase a mensajes claros en español
  String _getFriendlyFirebaseAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No existe ningún usuario registrado con este correo.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Contraseña o correo incorrectos.';
      case 'email-already-in-use':
        return 'Este correo electrónico ya está registrado por otro cliente.';
      case 'invalid-email':
        return 'El formato del correo electrónico no es válido.';
      case 'weak-password':
        return 'La contraseña es muy débil. Debe tener al menos 6 caracteres.';
      case 'network-request-failed':
        return 'Error de conexión. Revisa tu acceso a internet.';
      default:
        return 'Error de autenticación: $code';
    }
  }
}
