import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Producto (Pizza) para Appizza compatible con Cloud Firestore y SQLite.
///
/// Campos principales en Cloud Firestore ('products'):
/// - `id`: ID único del documento en Firestore.
/// - `name`: Nombre de la pizza (ej. "Pepperoni Especial").
/// - `description`: Ingredientes o descripción breve.
/// - `price`: Precio numérico (ej. 38000.0).
/// - `imageUrl`: Enlace web a la foto de la pizza.
/// - `available`: Booleano (true/false) para mostrar u ocultar en el catálogo sin borrar.
class ProductModel {
  final dynamic id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final bool available;
  final String pizzaSize;
  final int stock;
  final String categoria; // 'pizza' o 'bebida'

  ProductModel({
    this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.imageUrl = '',
    this.available = true,
    this.pizzaSize = 'Mediana',
    this.stock = 50,
    this.categoria = 'pizza',
  });

  /// Convierte el producto a Map para guardarlo o actualizarlo en Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'available': available,
      'pizza_size': pizzaSize,
      'stock': stock,
      'categoria': categoria,
    };
  }

  /// Construye un ProductModel a partir de un DocumentSnapshot de Cloud Firestore
  factory ProductModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ProductModel(
      id: doc.id,
      name: data['name'] ?? 'Producto sin nombre',
      description: data['description'] ?? '',
      price: (data['price'] is num) ? (data['price'] as num).toDouble() : 0.0,
      imageUrl: data['imageUrl'] ?? data['image'] ?? '',
      available: data['available'] ?? true,
      pizzaSize: data['pizza_size'] ?? data['pizzaSize'] ?? 'Mediana',
      stock: data['stock'] ?? 50,
      categoria: data['categoria'] ?? data['category'] ?? 'pizza',
    );
  }

  /// Constructor a partir de un Map (compatibilidad con SQLite)
  factory ProductModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return ProductModel(
      id: docId ?? map['id'],
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] is num) ? (map['price'] as num).toDouble() : 0.0,
      imageUrl: map['imageUrl'] ?? map['image'] ?? '',
      available: map['available'] ?? true,
      pizzaSize: map['pizza_size'] ?? map['pizzaSize'] ?? 'Mediana',
      stock: map['stock'] ?? 50,
      categoria: map['categoria'] ?? map['category'] ?? 'pizza',
    );
  }
}

// Alias para mantener compatibilidad total con pantallas previas
typedef Product = ProductModel;
