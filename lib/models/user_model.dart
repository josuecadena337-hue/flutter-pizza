import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Usuario para Appizza con Firebase.
///
/// ¿Por qué cambiamos respecto a SQLite?
/// 1. `uid`: Firebase Authentication le asigna a cada usuario un identificador alfanumérico único.
/// 2. NO guardamos la contraseña aquí: Firebase Authentication se encarga de cifrarla y protegerla.
/// 3. `role`: Define el tipo de cuenta ('admin', 'cliente', 'repartidor') y determina a qué pantalla entra.
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // 'admin', 'cliente', 'repartidor'
  final String? phone;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.createdAt,
  });

  // Convertir a Map para guardar en Cloud Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone ?? '',
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  // Crear objeto UserModel a partir de un Map (compatibilidad SQLite)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid']?.toString() ?? map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'cliente',
      phone: map['phone'],
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }

  // Crear objeto UserModel a partir de un DocumentSnapshot de Firestore
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    DateTime? created;
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    }

    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'cliente',
      phone: data['phone'],
      createdAt: created,
    );
  }

  // Helper útil para saber el rol de forma limpia
  bool get isAdmin => role == 'admin';
  bool get isCliente => role == 'cliente';
  bool get isRepartidor => role == 'repartidor';

  // Compatibilidad temporal con el módulo de carrito previo
  int? get id => int.tryParse(uid) ?? uid.hashCode;
}

// Alias para mantener compatibilidad con imports anteriores
typedef User = UserModel;

