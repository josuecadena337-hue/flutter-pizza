import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart' hide User;

/// Servicio encargado de la comunicación directa con Firebase:
/// 1. `FirebaseAuth`: Valida credenciales, tokens y sesiones seguras.
/// 2. `FirebaseFirestore`: Colección 'users' donde se almacena el perfil y ROL de cada usuario.
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream para escuchar si el usuario inicia o cierra sesión en tiempo real
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  /// Obtiene los datos del usuario (incluyendo su rol) desde Firestore usando su UID
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Registro exclusivo para CLIENTES.
  ///
  /// Flujo pedagógico:
  /// 1. Firebase Auth crea la cuenta con correo y contraseña cifrada.
  /// 2. Usando el `uid` que Auth genera, creamos un documento en Firestore:
  ///    `users/{uid}` con el campo obligatorio `role: 'cliente'`.
  Future<UserModel> registerClient({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    // 1. Crear usuario en Firebase Auth
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final firebaseUser = userCredential.user;
    if (firebaseUser == null) {
      throw Exception('No se pudo completar el registro en Firebase Auth.');
    }

    // 2. Guardar perfil y rol en Firestore
    final newUser = UserModel(
      uid: firebaseUser.uid,
      name: name,
      email: email,
      role: 'cliente', // Por seguridad, el auto-registro siempre es 'cliente'
      phone: phone,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(firebaseUser.uid).set(newUser.toMap());

    // Actualizar nombre visible en el objeto Auth
    await firebaseUser.updateDisplayName(name);

    return newUser;
  }

  /// Inicio de sesión unificado para cualquier rol (Admin, Cliente, Repartidor).
  ///
  /// Flujo pedagógico:
  /// 1. Firebase Auth verifica correo y contraseña.
  /// 2. Si son válidos, consultamos en Firestore `users/{uid}` para conocer su rol.
  /// 3. Retornamos el objeto `UserModel` completo para que la app sepa a qué pantalla enviarlo.
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final firebaseUser = userCredential.user;
    if (firebaseUser == null) {
      throw Exception('Usuario no encontrado tras autenticar.');
    }

    // Consultar el rol en Firestore
    final userProfile = await getUserProfile(firebaseUser.uid);

    if (userProfile == null) {
      throw Exception('El usuario existe en Authentication pero no tiene perfil en Firestore.');
    }

    return userProfile;
  }

  /// Cierra la sesión activa en el dispositivo
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Crea una cuenta de REPARTIDOR desde el panel de Administrador.
  ///
  /// ¿Por qué usamos una instancia secundaria de FirebaseApp?
  /// -------------------------------------------------------------
  /// Si llamáramos a `_auth.createUserWithEmailAndPassword()` directamente,
  /// Firebase Auth reemplazaría de inmediato la sesión del Administrador por la
  /// del nuevo usuario creado, cerrando la sesión del Admin y expulsándolo de su panel.
  ///
  /// Solución:
  /// Creamos una instancia secundaria temporal de Firebase (`Firebase.initializeApp(...)`).
  /// Registramos el usuario en esa instancia secundaria y luego la eliminamos (`secondaryApp.delete()`).
  /// De esta manera, la sesión del Administrador en la instancia principal permanece 100% activa.
  Future<UserModel> createRepartidor({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    FirebaseApp? secondaryApp;
    try {
      final defaultApp = Firebase.app();
      final appName = 'SecondaryAuth_${DateTime.now().millisecondsSinceEpoch}';

      secondaryApp = await Firebase.initializeApp(
        name: appName,
        options: defaultApp.options,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final newRepartidorUser = userCredential.user;
      if (newRepartidorUser == null) {
        throw Exception('No se pudo crear el usuario en Firebase Auth.');
      }

      final uid = newRepartidorUser.uid;

      // Guardamos el perfil y rol 'repartidor' en Firestore usando la instancia principal
      final newUser = UserModel(
        uid: uid,
        name: name.trim(),
        email: email.trim(),
        role: 'repartidor',
        phone: phone?.trim(),
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(newUser.toMap());

      await newRepartidorUser.updateDisplayName(name.trim());

      await secondaryAuth.signOut();

      return newUser;
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
    }
  }
}

