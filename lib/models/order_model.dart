import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa un producto individual dentro de un pedido en Firestore.
class OrderProductItem {
  final String nombre;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  OrderProductItem({
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'cantidad': cantidad,
    'precioUnitario': precioUnitario,
    'subtotal': subtotal,
  };

  factory OrderProductItem.fromMap(Map<String, dynamic> map) => OrderProductItem(
    nombre: map['nombre'] ?? '',
    cantidad: (map['cantidad'] is num) ? (map['cantidad'] as num).toInt() : 1,
    precioUnitario: (map['precioUnitario'] is num) ? (map['precioUnitario'] as num).toDouble() : 0.0,
    subtotal: (map['subtotal'] is num) ? (map['subtotal'] as num).toDouble() : 0.0,
  );
}

/// Modelo de Pedido para Appizza con Cloud Firestore.
///
/// Estructura de cada documento en la colección 'orders':
/// - `clienteId`: UID de Firebase Auth del cliente que ordenó.
/// - `clienteNombre`: Nombre completo del cliente.
/// - `productos`: Lista de mapas con nombre, cantidad, precio unitario y subtotal.
/// - `total`: Total general en pesos.
/// - `direccion`: Dirección de entrega ingresada por el cliente.
/// - `metodoPago`: 'efectivo' | 'en_linea'.
/// - `estado`: 'pendiente' | 'en_camino' | 'entregado'.
/// - `repartidorId`: UID del repartidor asignado por el admin (o null).
/// - `fechaCreacion`: Timestamp del servidor generado por `FieldValue.serverTimestamp()`.
class OrderModel {
  final dynamic id;
  final String clienteId;
  final String clienteNombre;
  final List<OrderProductItem> productos;
  final double total;
  final String direccion;
  final String metodoPago;
  final String estado;
  final String? clienteTelefono;
  final String? repartidorId;
  final String? repartidorNombre;
  final String? pagoEstado;
  final String? transaccionId;
  final String? tarjetaUltimos4;
  final DateTime? fechaCreacion;

  OrderModel({
    this.id,
    required this.clienteId,
    required this.clienteNombre,
    this.productos = const [],
    required this.total,
    this.direccion = '',
    this.metodoPago = 'efectivo',
    this.estado = 'pendiente',
    this.clienteTelefono,
    this.repartidorId,
    this.repartidorNombre,
    this.pagoEstado,
    this.transaccionId,
    this.tarjetaUltimos4,
    this.fechaCreacion,
  });

  Map<String, dynamic> toMap() => {
    'clienteId': clienteId,
    'clienteNombre': clienteNombre,
    'clienteTelefono': clienteTelefono,
    'productos': productos.map((p) => p.toMap()).toList(),
    'total': total,
    'direccion': direccion,
    'metodoPago': metodoPago,
    'estado': estado,
    'repartidorId': repartidorId,
    'repartidorNombre': repartidorNombre,
    'pagoEstado': pagoEstado,
    'transaccionId': transaccionId,
    'tarjetaUltimos4': tarjetaUltimos4,
    'fechaCreacion': fechaCreacion != null ? Timestamp.fromDate(fechaCreacion!) : FieldValue.serverTimestamp(),
  };

  factory OrderModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime? fecha;
    if (data['fechaCreacion'] is Timestamp) {
      fecha = (data['fechaCreacion'] as Timestamp).toDate();
    }

    final rawProducts = data['productos'] as List<dynamic>? ?? [];
    final items = rawProducts
        .map((p) => OrderProductItem.fromMap(Map<String, dynamic>.from(p as Map)))
        .toList();

    return OrderModel(
      id: doc.id,
      clienteId: data['clienteId'] ?? '',
      clienteNombre: data['clienteNombre'] ?? '',
      clienteTelefono: data['clienteTelefono'] ?? data['telefono'] ?? data['phone'],
      productos: items,
      total: (data['total'] is num) ? (data['total'] as num).toDouble() : 0.0,
      direccion: data['direccion'] ?? '',
      metodoPago: data['metodoPago'] ?? 'efectivo',
      estado: data['estado'] ?? 'pendiente',
      repartidorId: data['repartidorId'],
      repartidorNombre: data['repartidorNombre'],
      pagoEstado: data['pagoEstado'],
      transaccionId: data['transaccionId'],
      tarjetaUltimos4: data['tarjetaUltimos4'],
      fechaCreacion: fecha,
    );
  }

  // Compatibilidad con código previo de SQLite
  factory OrderModel.fromMap(Map<String, dynamic> map) => OrderModel(
    id: map['id'],
    clienteId: map['user_id']?.toString() ?? '',
    clienteNombre: map['client_name'] ?? '',
    total: map['total'] is int ? (map['total'] as int).toDouble() : (map['total'] ?? 0.0),
    estado: map['status'] ?? 'pendiente',
    fechaCreacion: map['date'] != null ? DateTime.tryParse(map['date'].toString()) : null,
  );

  int get userId => int.tryParse(clienteId) ?? 0;
  String get clientName => clienteNombre;
  String get date => fechaCreacion?.toIso8601String() ?? '';
  int get isNotified => 0;
  String get status => estado;
}

// Compatibilidad con imports antiguos
class OrderItem {
  final int? id;
  final int orderId;
  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  OrderItem({
    this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });
}
