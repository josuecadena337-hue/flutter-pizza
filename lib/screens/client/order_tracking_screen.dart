import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../controllers/auth_controller.dart';
import '../../models/order_model.dart';

/// Pantalla de Seguimiento de Pedidos en Tiempo Real (`OrderTrackingScreen`).
///
/// ¿Por qué es en tiempo real?
/// -------------------------------------------------------------
/// Se suscribe al Stream de la colección 'orders' en Firestore filtrado por `clienteId`.
/// Cuando el Administrador o el Repartidor cambie el estado del pedido:
///   'pendiente' ➔ 'en_camino' ➔ 'entregado'
/// Firestore notifica al teléfono en milisegundos y el `StreamBuilder` actualiza
/// el indicador de pasos en la pantalla del cliente sin recargar nada.
class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final user = auth.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          title: const Text('Mis Pedidos'),
          backgroundColor: const Color(0xFF16213E),
        ),
        body: const Center(
          child: Text('Debes iniciar sesión para ver tus pedidos.', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Row(
          children: [
            Text('🛵', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Seguimiento de Pedidos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // Escuchamos todos los pedidos de este cliente en tiempo real
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('clienteId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // 1. Estado de carga
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE64A19)),
            );
          }

          // 2. Error
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar pedidos: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          // Convertimos y ordenamos en memoria por fecha más reciente
          final allOrders = docs.map((d) => OrderModel.fromFirestore(d)).toList()
            ..sort((a, b) {
              if (a.fechaCreacion == null) return 1;
              if (b.fechaCreacion == null) return -1;
              return b.fechaCreacion!.compareTo(a.fechaCreacion!);
            });

          // Filtramos los pedidos activos (que aún no han sido entregados)
          final activeOrders = allOrders.where((o) => o.estado != 'entregado').toList();
          final completedOrders = allOrders.where((o) => o.estado == 'entregado').toList();

          if (allOrders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('📦', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    const Text(
                      'No tienes pedidos activos',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cuando pidas pizzas a domicilio, aquí podrás ver en tiempo real cómo avanza tu orden.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.white60),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE64A19),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Ir al Menú'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (activeOrders.isNotEmpty) ...[
                const Row(
                  children: [
                    Icon(Icons.bolt, color: Color(0xFFFF7043), size: 20),
                    SizedBox(width: 6),
                    Text(
                      'PEDIDOS EN CURSO',
                      style: TextStyle(
                        color: Color(0xFFFF7043),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...activeOrders.map((order) => _OrderTrackingCard(order: order)),
                const SizedBox(height: 20),
              ],

              if (completedOrders.isNotEmpty) ...[
                const Row(
                  children: [
                    Icon(Icons.history, color: Colors.white60, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'HISTORIAL DE ENTREGAS',
                      style: TextStyle(
                        color: Colors.white60,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...completedOrders.map((order) => _OrderTrackingCard(order: order)),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Tarjeta detallada con indicador de pasos ("Pendiente → En camino → Entregado")
class _OrderTrackingCard extends StatelessWidget {
  final OrderModel order;

  const _OrderTrackingCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: order.estado != 'entregado' ? const Color(0xFFE64A19).withValues(alpha: 0.4) : Colors.white10,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado: ID del pedido y Total ─────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Orden #${order.id.toString().substring(0, order.id.toString().length > 6 ? 6 : order.id.toString().length).toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
              ),
              Text(
                '\$${order.total.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Color(0xFFFF7043),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Dirección y método de pago
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.white54),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  order.direccion,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: order.metodoPago == 'efectivo' ? const Color(0xFF0F3460) : Colors.teal.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: order.metodoPago == 'efectivo' ? Colors.transparent : Colors.tealAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  order.metodoPago == 'efectivo'
                      ? '💵 Efectivo'
                      : (order.tarjetaUltimos4 != null
                          ? '💳 Pagado (•••• ${order.tarjetaUltimos4})'
                          : '💳 Pagado Online'),
                  style: TextStyle(
                    color: order.metodoPago == 'efectivo' ? Colors.white70 : Colors.tealAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),

          // ── Indicador Visual de Pasos (Pendiente → En camino → Entregado) ──
          _buildStepTracker(order.estado),
          const Divider(color: Colors.white12, height: 24),

          // ── Lista de pizzas del pedido ───────────────────────────────────
          const Text(
            'Detalle de pizzas:',
            style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          ...order.productos.map((prod) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${prod.cantidad}x ${prod.nombre}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '\$${prod.subtotal.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  /// Construye el Stepper visual interactivo con círculos y líneas de progreso
  Widget _buildStepTracker(String estado) {
    // Definimos el paso numérico activo:
    // 1: Pendiente (en cocina)
    // 2: En camino (con el repartidor)
    // 3: Entregado (completado)
    int currentStep = 1;
    if (estado == 'en_camino') currentStep = 2;
    if (estado == 'entregado') currentStep = 3;

    return Row(
      children: [
        _stepNode(
          stepNumber: 1,
          label: 'Pendiente',
          icon: Icons.soup_kitchen_outlined,
          isActive: currentStep >= 1,
          isCurrent: currentStep == 1,
        ),
        _stepLine(isActive: currentStep >= 2),
        _stepNode(
          stepNumber: 2,
          label: 'En camino',
          icon: Icons.delivery_dining,
          isActive: currentStep >= 2,
          isCurrent: currentStep == 2,
        ),
        _stepLine(isActive: currentStep >= 3),
        _stepNode(
          stepNumber: 3,
          label: 'Entregado',
          icon: Icons.check_circle_outline,
          isActive: currentStep >= 3,
          isCurrent: currentStep == 3,
        ),
      ],
    );
  }

  Widget _stepNode({
    required int stepNumber,
    required String label,
    required IconData icon,
    required bool isActive,
    required bool isCurrent,
  }) {
    final color = isActive ? (isCurrent ? const Color(0xFFFF7043) : Colors.green) : Colors.white24;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive ? color.withValues(alpha: 0.15) : const Color(0xFF0F3460),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: isCurrent ? 2.5 : 1.5),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.white : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepLine({required bool isActive}) {
    return Container(
      width: 30,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isActive ? Colors.green : Colors.white12,
    );
  }
}
