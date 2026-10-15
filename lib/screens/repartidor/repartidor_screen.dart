import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/auth_controller.dart';
import '../../models/order_model.dart';

/// Pantalla del Repartidor (`RepartidorScreen`).
///
/// ¿Cómo funciona la consulta reactiva?
/// -------------------------------------------------------------
/// Se suscribe al Stream de la colección 'orders' filtrando con:
///   `.where('repartidorId', isEqualTo: user.uid)`
///
/// De este modo:
/// 1. El repartidor SOLO ve los pedidos que el Administrador le asignó a él.
/// 2. Si el Administrador le asigna una nueva orden mientras el repartidor tiene
///    la app abierta en su moto, la orden aparece de inmediato en su pantalla.
/// 3. Al tocar "Marcar como Entregado", la orden pasa a 'entregado', actualizando
///    simultáneamente la pantalla del Admin y la pantalla del Cliente en vivo.
class RepartidorScreen extends StatefulWidget {
  const RepartidorScreen({super.key});

  @override
  State<RepartidorScreen> createState() => _RepartidorScreenState();
}

class _RepartidorScreenState extends State<RepartidorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Abre la dirección del cliente directamente en Google Maps o Waze con múltiples estrategias de soporte
  Future<void> _openInMaps(String address) async {
    final cleanAddress = address.trim();
    if (cleanAddress.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Este pedido no tiene una dirección registrada.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final query = Uri.encodeComponent(cleanAddress);

    // 1. URI geo: estándar (dispositivos Android/iOS abren Google Maps o Waze)
    final geoUri = Uri.parse('geo:0,0?q=$query');

    // 2. URI de navegación directa de Google Maps
    final navUri = Uri.parse('google.navigation:q=$query');

    // 3. URL web oficial de Google Maps
    final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(navUri)) {
        await launchUrl(navUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    // Fallback incondicional
    try {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      Clipboard.setData(ClipboardData(text: cleanAddress));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir Maps ($e). ¡Dirección copiada al portapapeles! 📋'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
  }

  /// Copia la dirección al portapapeles
  void _copyAddress(String address) {
    final clean = address.trim();
    if (clean.isEmpty) return;
    Clipboard.setData(ClipboardData(text: clean));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Dirección copiada al portapapeles.'),
        backgroundColor: Color(0xFFE64A19),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Realiza una llamada telefónica al cliente
  Future<void> _callClient(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      await launchUrl(uri);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar llamada: $e')),
      );
    }
  }

  /// Abre chat de WhatsApp con el cliente
  Future<void> _openWhatsApp(String phone, String clientName) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final fullNumber = digits.length == 10 ? '57$digits' : digits;
    final msg = Uri.encodeComponent('Hola $clientName, soy el repartidor de Appizza con tu pedido. 🛵🍕');
    final uri = Uri.parse('https://wa.me/$fullNumber?text=$msg');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir WhatsApp: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE64A19))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Text('🛵', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Panel de Repartidor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Hola, ${user.name}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE64A19),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFF7043),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.delivery_dining), text: 'Por Entregar'),
            Tab(icon: Icon(Icons.check_circle_outline), text: 'Entregados'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Cerrar Sesión',
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // ── Consulta Firestore: Solo pedidos asignados a este repartidor ─────
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('repartidorId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE64A19)));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Error al cargar entregas: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final allOrders = docs.map((d) => OrderModel.fromFirestore(d)).toList()
            ..sort((a, b) {
              if (a.fechaCreacion == null) return 1;
              if (b.fechaCreacion == null) return -1;
              return b.fechaCreacion!.compareTo(a.fechaCreacion!);
            });

          // Filtramos: pedidos en camino (pendientes por entregar) vs entregados
          final pendingDeliveries = allOrders.where((o) => o.estado == 'en_camino').toList();
          final completedDeliveries = allOrders.where((o) => o.estado == 'entregado').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              // ── Pestaña 1: Por entregar ────────────────────────────────────
              _buildDeliveriesList(
                orders: pendingDeliveries,
                emptyMessage: 'No tienes entregas asignadas en este momento.\nCuando el administrador te asigne un pedido, aparecerá aquí.',
                emptyIcon: '🎉',
                isPendingTab: true,
              ),

              // ── Pestaña 2: Entregados (Historial) ──────────────────────────
              _buildDeliveriesList(
                orders: completedDeliveries,
                emptyMessage: 'Aún no has completado ninguna entrega.',
                emptyIcon: '📦',
                isPendingTab: false,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeliveriesList({
    required List<OrderModel> orders,
    required String emptyMessage,
    required String emptyIcon,
    required bool isPendingTab,
  }) {
    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emptyIcon, style: const TextStyle(fontSize: 54)),
              const SizedBox(height: 16),
              Text(
                isPendingTab ? '¡Todo entregado!' : 'Sin entregas registradas',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.white60, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _RepartidorOrderCard(
          order: order,
          onTap: () => _showOrderDetail(order),
          onOpenMaps: () => _openInMaps(order.direccion),
          onMarkDelivered: () => _confirmAndMarkDelivered(order),
        );
      },
    );
  }

  /// Muestra el modal con el detalle completo del pedido
  void _showOrderDetail(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RepartidorOrderDetailModal(
        order: order,
        onOpenMaps: () => _openInMaps(order.direccion),
        onCopyAddress: () => _copyAddress(order.direccion),
        onCallClient: (phone) => _callClient(phone),
        onOpenWhatsApp: (phone, name) => _openWhatsApp(phone, name),
        onMarkDelivered: () => _confirmAndMarkDelivered(order),
      ),
    );
  }

  /// Pide confirmación antes de marcar como entregado para evitar errores accidentales
  Future<void> _confirmAndMarkDelivered(OrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Confirmar Entrega', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '¿Confirmas que entregaste el pedido al cliente ${order.clienteNombre}?',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sí, Entregado'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('orders').doc(order.id.toString()).update({
        'estado': 'entregado',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 ¡Pedido marcado como entregado con éxito!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar entrega: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }
}

// =============================================================================
// COMPONENTE: TARJETA DE PEDIDO PARA EL REPARTIDOR
// =============================================================================

class _RepartidorOrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;
  final VoidCallback onOpenMaps;
  final VoidCallback onMarkDelivered;

  const _RepartidorOrderCard({
    required this.order,
    required this.onTap,
    required this.onOpenMaps,
    required this.onMarkDelivered,
  });

  @override
  Widget build(BuildContext context) {
    final isCash = order.metodoPago == 'efectivo';
    final isPending = order.estado == 'en_camino';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isPending ? const Color(0xFF2196F3).withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.3),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Encabezado: Cliente y Estado ─────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.person_pin, color: Color(0xFFFF7043), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.clienteNombre.isNotEmpty ? order.clienteNombre : 'Cliente',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPending ? const Color(0xFF2196F3).withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPending ? const Color(0xFF2196F3) : Colors.green,
                    ),
                  ),
                  child: Text(
                    isPending ? 'En Camino 🛵' : 'Entregado ✅',
                    style: TextStyle(
                      color: isPending ? const Color(0xFF2196F3) : Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Dirección con botón de Google Maps ────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F3460),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFFE64A19), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.direccion,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.map_outlined, color: Color(0xFFFF7043), size: 20),
                    tooltip: 'Abrir en Google Maps',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onOpenMaps,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Indicador de Cobro (Efectivo vs En línea) ────────────────────
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCash ? Colors.amber.withValues(alpha: 0.1) : Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCash ? Colors.amber.withValues(alpha: 0.4) : Colors.teal.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCash ? Icons.attach_money : Icons.check_circle_outline,
                    color: isCash ? Colors.amber : Colors.tealAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCash ? 'COBRAR EN EFECTIVO' : 'PAGADO EN LÍNEA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCash ? Colors.amber : Colors.tealAccent,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          isCash ? '\$${order.total.toStringAsFixed(0)} al entregar' : '\$0 a cobrar (ya pagado con tarjeta)',
                          style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Botón de Acción rápida si está pendiente ─────────────────────
            if (isPending)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onMarkDelivered,
                  icon: const Icon(Icons.check, size: 20),
                  label: const Text('MARCAR COMO ENTREGADO', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// MODAL: DETALLE COMPLETO DEL PEDIDO PARA EL REPARTIDOR
// =============================================================================

class _RepartidorOrderDetailModal extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onOpenMaps;
  final VoidCallback onCopyAddress;
  final ValueChanged<String> onCallClient;
  final void Function(String phone, String name) onOpenWhatsApp;
  final VoidCallback onMarkDelivered;

  const _RepartidorOrderDetailModal({
    required this.order,
    required this.onOpenMaps,
    required this.onCopyAddress,
    required this.onCallClient,
    required this.onOpenWhatsApp,
    required this.onMarkDelivered,
  });

  @override
  State<_RepartidorOrderDetailModal> createState() => _RepartidorOrderDetailModalState();
}

class _RepartidorOrderDetailModalState extends State<_RepartidorOrderDetailModal> {
  String? _clientPhone;

  @override
  void initState() {
    super.initState();
    _clientPhone = widget.order.clienteTelefono;
    if (_clientPhone == null || _clientPhone!.isEmpty) {
      _fetchClientPhone();
    }
  }

  Future<void> _fetchClientPhone() async {
    if (widget.order.clienteId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.order.clienteId).get();
      if (doc.exists && mounted) {
        final phone = doc.data()?['phone']?.toString();
        if (phone != null && phone.isNotEmpty) {
          setState(() => _clientPhone = phone);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isCash = order.metodoPago == 'efectivo';
    final isPending = order.estado == 'en_camino';
    final phone = _clientPhone ?? '';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de agarre
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Encabezado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Detalle del Pedido #${order.id.toString().substring(0, order.id.toString().length > 6 ? 6 : order.id.toString().length).toUpperCase()}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── DATOS DEL CLIENTE Y CONTACTO ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F3460),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.person, color: Color(0xFFFF7043), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order.clienteNombre.isNotEmpty ? order.clienteNombre : 'Cliente sin nombre',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (phone.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.phone, color: Colors.greenAccent, size: 20),
                                tooltip: 'Llamar al cliente',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => widget.onCallClient(phone),
                              ),
                              const SizedBox(width: 14),
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366), size: 20),
                                tooltip: 'Escribir por WhatsApp',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => widget.onOpenWhatsApp(phone, order.clienteNombre),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('📞 $phone', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                    const SizedBox(height: 10),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 10),

                    // Dirección de entrega
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 18, color: Color(0xFFFF7043)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.direccion.isNotEmpty ? order.direccion : 'Sin dirección especificada',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Botones de acción: Abrir en Maps y Copiar Dirección
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: widget.onOpenMaps,
                            icon: const Icon(Icons.navigation_rounded, size: 18),
                            label: const Text(
                              'Cómo llegar (Abrir Maps)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE64A19),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: widget.onCopyAddress,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: 'Copiar dirección',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF16213E),
                            foregroundColor: Colors.white70,
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: Colors.white12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── COBRO A REALIZAR ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCash ? Colors.amber.withValues(alpha: 0.12) : Colors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isCash ? Colors.amber.withValues(alpha: 0.4) : Colors.teal.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCash ? Icons.attach_money : Icons.check_circle_outline,
                          color: isCash ? Colors.amber : Colors.tealAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isCash ? 'Monto a Cobrar (Efectivo):' : 'Estado del Pago:',
                          style: TextStyle(
                            color: isCash ? Colors.amber : Colors.tealAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      isCash ? '\$${order.total.toStringAsFixed(0)}' : 'Ya Pagado (\$0)',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── CONTENIDO DEL PEDIDO ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F3460).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CONTENIDO DEL PEDIDO (${order.productos.length})',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const Text(
                          'Subtotal',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...order.productos.map((p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE64A19).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${p.cantidad}x',
                              style: const TextStyle(
                                color: Color(0xFFFF7043),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p.nombre,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '\$${p.subtotal.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )),
                    const Divider(color: Colors.white12, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total a Cobrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                          '\$${order.total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Color(0xFFFF7043),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── BOTÓN DE ENTREGA ──────────────────────────────────────────
              if (isPending)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Cierra el modal primero
                      widget.onMarkDelivered();
                    },
                    icon: const Icon(Icons.check_circle, size: 22),
                    label: const Text(
                      'MARCAR COMO ENTREGADO',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Pedido Entregado con éxito',
                        style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
