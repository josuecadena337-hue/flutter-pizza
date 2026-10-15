import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../controllers/auth_controller.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/product_model.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/seed_data_service.dart';
import '../auth/welcome_screen.dart';
import 'product_form_screen.dart';

/// Panel de Control del Administrador (`AdminDashboardScreen`).
///
/// Contiene 2 pestañas principales:
/// 1. **Pedidos:** Lista y filtros en tiempo real, asignación de repartidores y cambio de estados.
/// 2. **Repartidores:** Creación y visualización de repartidores en Firebase sin cerrar la sesión del admin.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _orderFilter = 'todos'; // 'todos', 'pendiente', 'en_camino', 'entregado'
  String _productCategoryFilter = 'todos'; // 'todos', 'pizza', 'bebida'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Text('🍕', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Panel Administrador', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE64A19),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFF7043),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long), text: 'Pedidos'),
            Tab(icon: Icon(Icons.delivery_dining), text: 'Repartidores'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Productos'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cargar Catálogo Oficial',
            icon: const Icon(Icons.cloud_sync_rounded, color: Color(0xFFFFB74D)),
            onPressed: _runCatalogSeed,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle, color: Colors.white70),
            color: const Color(0xFF16213E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'logout') {
                auth.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  auth.currentUser?.name ?? 'Admin',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                enabled: false,
                child: Text('Rol: Administrador 🛡️', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Cerrar Sesión', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── PESTAÑA 1: GESTIÓN DE PEDIDOS ──────────────────────────────────
          _buildOrdersSection(),

          // ── PESTAÑA 2: GESTIÓN DE REPARTIDORES ──────────────────────────────
          _buildRepartidoresSection(),

          // ── PESTAÑA 3: GESTIÓN DE PRODUCTOS (PIZZAS Y BEBIDAS) ──────────────
          _buildProductsSection(),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECCIÓN 1: GESTIÓN DE PEDIDOS (STREAMBUILDER EN TIEMPO REAL)
  // ===========================================================================

  Widget _buildOrdersSection() {
    return Column(
      children: [
        // Filtros: Todos, Pendientes, En camino, Entregados
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFF16213E),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Todos', 'todos'),
                const SizedBox(width: 8),
                _filterChip('Pendientes ⏳', 'pendiente'),
                const SizedBox(width: 8),
                _filterChip('En camino 🛵', 'en_camino'),
                const SizedBox(width: 8),
                _filterChip('Entregados ✅', 'entregado'),
              ],
            ),
          ),
        ),

        // Lista reactiva de pedidos desde Firestore
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('orders').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFE64A19)));
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              final orders = docs.map((doc) => OrderModel.fromFirestore(doc)).toList()
                ..sort((a, b) {
                  if (a.fechaCreacion == null) return 1;
                  if (b.fechaCreacion == null) return -1;
                  return b.fechaCreacion!.compareTo(a.fechaCreacion!);
                });

              // Aplicar filtro seleccionado
              final filteredOrders = orders.where((o) {
                if (_orderFilter == 'todos') return true;
                return o.estado == _orderFilter;
              }).toList();

              if (filteredOrders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox, size: 64, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text(
                        'No hay pedidos en la categoría "$_orderFilter"',
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = filteredOrders[index];
                  return _AdminOrderCard(
                    order: order,
                    onTap: () => _showOrderDetailModal(order),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _orderFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _orderFilter = value),
      selectedColor: const Color(0xFFE64A19),
      backgroundColor: const Color(0xFF0F3460),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  /// Despliega el modal de detalle del pedido con asignación de repartidor
  void _showOrderDetailModal(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdminOrderDetailModal(order: order),
    );
  }

  // ===========================================================================
  // SECCIÓN 2: GESTIÓN DE REPARTIDORES
  // ===========================================================================

  Widget _buildRepartidoresSection() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRepartidorDialog,
        backgroundColor: const Color(0xFFE64A19),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Agregar Repartidor', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'repartidor')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE64A19)));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final repartidores = docs.map((d) => UserModel.fromFirestore(d)).toList();

          if (repartidores.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🛵', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    const Text(
                      'No hay repartidores registrados',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Crea cuentas para los domiciliarios del local usando el botón "+ Agregar Repartidor".',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
            itemCount: repartidores.length,
            itemBuilder: (ctx, index) {
              final rep = repartidores[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF0F3460),
                      child: const Text('🛵', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rep.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 14, color: Colors.white54),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  rep.email,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (rep.phone != null && rep.phone!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.phone_outlined, size: 14, color: Colors.white54),
                                const SizedBox(width: 4),
                                Text(
                                  rep.phone!,
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Activo',
                        style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Abre el formulario para registrar un repartidor en Firebase
  void _showCreateRepartidorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const _CreateRepartidorDialog(),
    );
  }

  /// Ejecuta la carga y sincronización del catálogo oficial de pizzas y bebidas en Cloud Firestore
  Future<void> _runCatalogSeed() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFFFFB74D)),
            SizedBox(width: 8),
            Text('Catálogo Oficial', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          '¿Deseas cargar/actualizar el menú completo de la pizzería en Cloud Firestore?\n\n'
          '• 8 Variedades de Pizzas artesanales\n'
          '• 7 Variedades de Bebidas heladas\n\n'
          'Cada producto cuenta con fotos reales en alta resolución, precios en COP y disponibilidad activa.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE64A19)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cargar Menú', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            color: Color(0xFF16213E),
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFFE64A19)),
                  SizedBox(height: 16),
                  Text('Sincronizando con Cloud Firestore...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final res = await SeedDataService.seedProductsToFirestore(overwrite: true);
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loader

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2E7D32),
          content: Text(
            '✅ Catálogo actualizado: ${res['total']} productos (${res['pizzas']} pizzas y ${res['bebidas']} bebidas).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error al cargar catálogo: $e'),
        ),
      );
    }
  }

  // ===========================================================================
  // SECCIÓN 3: GESTIÓN DE PRODUCTOS (PIZZAS Y BEBIDAS)
  // ===========================================================================

  Widget _buildProductsSection() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProductFormScreen()),
          );
        },
        backgroundColor: const Color(0xFFE64A19),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar Producto', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Barra de filtros por categoría
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFF16213E),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _productFilterChip('Todos ✨', 'todos'),
                        const SizedBox(width: 8),
                        _productFilterChip('Pizzas 🍕', 'pizza'),
                        const SizedBox(width: 8),
                        _productFilterChip('Bebidas 🥤', 'bebida'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _runCatalogSeed,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F3460),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFB74D).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_sync_rounded, color: Color(0xFFFFB74D), size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Sincronizar',
                          style: TextStyle(color: Color(0xFFFFB74D), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista en tiempo real de productos desde Firestore
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFE64A19)));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final allProducts = docs.map((doc) => ProductModel.fromFirestore(doc)).toList();

                final products = _productCategoryFilter == 'todos'
                    ? allProducts
                    : allProducts.where((p) => p.categoria.toLowerCase() == _productCategoryFilter).toList();

                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white24),
                        const SizedBox(height: 12),
                        Text(
                          'No hay productos en la categoría "$_productCategoryFilter"',
                          style: const TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ProductFormScreen()),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Crear Primer Producto'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE64A19),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _AdminProductCard(
                      product: product,
                      onEdit: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductFormScreen(product: product),
                          ),
                        );
                      },
                      onToggleAvailable: (bool newVal) async {
                        await FirebaseFirestore.instance
                            .collection('products')
                            .doc(product.id.toString())
                            .update({'available': newVal});
                      },
                      onDelete: () => _confirmDeleteProduct(product),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _productFilterChip(String label, String value) {
    final isSelected = _productCategoryFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _productCategoryFilter = value),
      selectedColor: const Color(0xFFE64A19),
      backgroundColor: const Color(0xFF0F3460),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  void _confirmDeleteProduct(ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Eliminar ${product.name}',
                style: const TextStyle(color: Colors.white, fontSize: 17),
              ),
            ),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este producto?\n\n'
          'Tip: Si solo está agotado temporalmente, es mejor desactivarlo con el interruptor sin necesidad de borrarlo.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('products')
                  .doc(product.id.toString())
                  .delete();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🗑️ "${product.name}" eliminado de Firestore'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// COMPONENTE: TARJETA DE PEDIDO PARA EL ADMINISTRADOR
// =============================================================================

class _AdminOrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const _AdminOrderCard({required this.order, required this.onTap});

  static Color statusColor(String status) {
    switch (status) {
      case 'en_camino':
        return const Color(0xFF2196F3); // Azul vibrante
      case 'entregado':
        return const Color(0xFF4CAF50); // Verde esmeralda
      case 'pendiente':
      default:
        return const Color(0xFFFFB300); // Ámbar
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'en_camino':
        return 'En Camino 🛵';
      case 'entregado':
        return 'Entregado ✅';
      case 'pendiente':
      default:
        return 'Pendiente ⏳';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sColor = statusColor(order.estado);

    // Resumen de productos en una sola línea
    final productsSummary = order.productos.map((p) => '${p.cantidad}x ${p.nombre}').join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sColor.withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado: Cliente y Badge de estado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: Colors.white70, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              order.clienteNombre.isNotEmpty ? order.clienteNombre : 'Cliente',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: sColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        statusLabel(order.estado),
                        style: TextStyle(color: sColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Productos y cantidades
                Text(
                  productsSummary.isNotEmpty ? productsSummary : 'Sin productos listados',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Dirección
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.white38),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.direccion,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Repartidor asignado si ya está en camino
                if (order.repartidorNombre != null && order.repartidorNombre!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.two_wheeler_rounded, size: 14, color: Color(0xFFFFB74D)),
                      const SizedBox(width: 4),
                      Text(
                        'Repartidor: ${order.repartidorNombre}',
                        style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],

                const Divider(color: Colors.white12, height: 16),

                // Pie: Total y Método de Pago
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.metodoPago == 'efectivo'
                          ? '💵 Efectivo contra entrega'
                          : (order.tarjetaUltimos4 != null
                              ? '💳 En línea (•••• ${order.tarjetaUltimos4})'
                              : '💳 Pago en línea (Aprobado)'),
                      style: TextStyle(
                        color: order.metodoPago == 'efectivo' ? Colors.white54 : Colors.tealAccent,
                        fontSize: 12,
                        fontWeight: order.metodoPago == 'efectivo' ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                    Text(
                      '\$${order.total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF7043),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// MODAL: DETALLE DEL PEDIDO Y ASIGNACIÓN DE REPARTIDOR
// =============================================================================

class _AdminOrderDetailModal extends StatefulWidget {
  final OrderModel order;

  const _AdminOrderDetailModal({required this.order});

  @override
  State<_AdminOrderDetailModal> createState() => _AdminOrderDetailModalState();
}

class _AdminOrderDetailModalState extends State<_AdminOrderDetailModal> {
  String? _selectedRepartidorId;
  String? _selectedRepartidorNombre;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _selectedRepartidorId = widget.order.repartidorId;
    _selectedRepartidorNombre = widget.order.repartidorNombre;
  }

  Future<void> _assignRepartidor() async {
    if (_selectedRepartidorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona un repartidor de la lista primero'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.order.id.toString()).update({
        'repartidorId': _selectedRepartidorId,
        'repartidorNombre': _selectedRepartidorNombre ?? 'Repartidor',
        'estado': 'en_camino',
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🛵 Pedido asignado a $_selectedRepartidorNombre y puesto "En camino"'),
          backgroundColor: const Color(0xFFE64A19),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al asignar: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _markDelivered() async {
    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.order.id.toString()).update({
        'estado': 'entregado',
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Pedido marcado como "Entregado" exitosamente'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final sColor = _AdminOrderCard.statusColor(order.estado);
    final sLabel = _AdminOrderCard.statusLabel(order.estado);
    final idShort = order.id.toString().substring(0, order.id.toString().length > 6 ? 6 : order.id.toString().length).toUpperCase();

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

              // Encabezado: ID del Pedido, Badge de Estado y Total
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pedido #$idShort',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: sColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: sColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            sLabel,
                            style: TextStyle(color: sColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${order.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFF7043),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tarjeta de Datos del Cliente y Entrega
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
                      children: [
                        const Icon(Icons.delivery_dining, color: Color(0xFFFF7043), size: 18),
                        const SizedBox(width: 6),
                        const Text(
                          'DATOS DE ENTREGA',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: order.metodoPago == 'efectivo'
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            order.metodoPago == 'efectivo'
                                ? '💵 Efectivo'
                                : (order.tarjetaUltimos4 != null
                                    ? '💳 Pagado (•••${order.tarjetaUltimos4})'
                                    : '💳 En línea'),
                            style: TextStyle(
                              color: order.metodoPago == 'efectivo' ? Colors.greenAccent : Colors.lightBlueAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.person, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.clienteNombre.isNotEmpty ? order.clienteNombre : 'Cliente sin nombre',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, color: Colors.white54, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.direccion.isNotEmpty ? order.direccion : 'Dirección no especificada',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    if (order.repartidorNombre != null && order.repartidorNombre!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.two_wheeler_rounded, color: Color(0xFFFFB74D), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Repartidor: ${order.repartidorNombre}',
                              style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Lista de productos solicitados
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
                          'PRODUCTOS (${order.productos.length})',
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
                        const Text(
                          'Total a Cobrar',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
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
              const SizedBox(height: 16),

              // ── SECCIÓN ASIGNAR REPARTIDOR ─────────────────────────────────
              const Text(
                '🛵 Asignar Domiciliario:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'repartidor')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator(color: Color(0xFFE64A19));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final drivers = docs.map((d) => UserModel.fromFirestore(d)).toList();

                  if (drivers.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amberAccent, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No tienes domiciliarios registrados aún.',
                              style: TextStyle(color: Colors.amberAccent, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F3460),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<String>(
                        dropdownColor: const Color(0xFF16213E),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        initialValue: _selectedRepartidorId,
                        hint: const Text('Seleccionar domiciliario', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.delivery_dining, color: Color(0xFFFF7043)),
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        items: drivers.map((d) {
                          return DropdownMenuItem<String>(
                            value: d.uid,
                            child: Text(
                              '${d.name} (${d.phone != null && d.phone!.isNotEmpty ? d.phone : 'Sin cel'})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedRepartidorId = val;
                            final found = drivers.firstWhere((d) => d.uid == val);
                            _selectedRepartidorNombre = found.name;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Botón 1: Asignar y marcar "En camino"
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isUpdating ? null : _assignRepartidor,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE64A19),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _isUpdating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.two_wheeler_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              order.estado == 'en_camino'
                                  ? 'Reasignar Domiciliario'
                                  : 'Asignar y Poner "En camino"',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),

              // Botón 2: Marcar como "Entregado"
              if (order.estado != 'entregado') ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isUpdating ? null : _markDelivered,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Marcar como "Entregado"',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
              ] else ...[
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
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// DIÁLOGO: AGREGAR REPARTIDOR USANDO INSTANCIA SECUNDARIA DE FIREBASE
// =============================================================================

class _CreateRepartidorDialog extends StatefulWidget {
  const _CreateRepartidorDialog();

  @override
  State<_CreateRepartidorDialog> createState() => _CreateRepartidorDialogState();
}

class _CreateRepartidorDialogState extends State<_CreateRepartidorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Usamos el servicio con instancia secundaria para no cerrar la sesión del admin
      final authService = FirebaseAuthService();
      await authService.createRepartidor(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🛵 Repartidor ${_nameController.text.trim()} creado con éxito.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF16213E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Text('🛵', style: TextStyle(fontSize: 24)),
          SizedBox(width: 8),
          Text('Nuevo Repartidor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa el nombre' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Ingresa el correo';
                  if (!val.contains('@')) return 'Correo no válido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Celular / Teléfono',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Contraseña temporal',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (val) => val != null && val.length < 6 ? 'Mínimo 6 caracteres' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE64A19),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Crear Repartidor'),
        ),
      ],
    );
  }
}

/// Tarjeta individual de administración para cada producto
class _AdminProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleAvailable;
  final VoidCallback onDelete;

  const _AdminProductCard({
    required this.product,
    required this.onEdit,
    required this.onToggleAvailable,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDrink = product.categoria.toLowerCase() == 'bebida';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: product.available
              ? const Color(0xFF1F2F56)
              : Colors.redAccent.withValues(alpha: 0.3),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Fila Superior: Miniatura + Info del producto + Menú contextual
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: product.imageUrl.isNotEmpty
                            ? Image.network(
                                product.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _fallbackThumbnail(isDrink),
                              )
                            : _fallbackThumbnail(isDrink),
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  product.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDrink
                                      ? Colors.blueAccent.withValues(alpha: 0.2)
                                      : const Color(0xFFE64A19).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isDrink ? '🥤 Bebida' : '🍕 Pizza',
                                  style: TextStyle(
                                    color: isDrink ? Colors.lightBlueAccent : const Color(0xFFFF7043),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '\$${product.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Color(0xFFFF7043),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              if (product.pizzaSize.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '• ${product.pizzaSize}',
                                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.more_vert, color: Colors.white60),
                      color: const Color(0xFF0F3460),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      onSelected: (action) {
                        if (action == 'edit') onEdit();
                        if (action == 'delete') onDelete();
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.white70, size: 18),
                              SizedBox(width: 8),
                              Text('Editar', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                              SizedBox(width: 8),
                              Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 8),

                // Fila Inferior: Indicador de Estado + Switch interactivo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: product.available
                            ? Colors.greenAccent.withValues(alpha: 0.12)
                            : Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: product.available
                              ? Colors.greenAccent.withValues(alpha: 0.3)
                              : Colors.redAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: product.available ? Colors.greenAccent : Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            product.available ? 'Activo en Catálogo' : 'Desactivado (Oculto)',
                            style: TextStyle(
                              color: product.available ? Colors.greenAccent : Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product.available ? 'Disponible' : 'Agotado',
                          style: TextStyle(
                            color: product.available ? const Color(0xFFFF7043) : Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: product.available,
                            activeThumbColor: const Color(0xFFE64A19),
                            activeTrackColor: const Color(0xFFFF7043).withValues(alpha: 0.4),
                            inactiveThumbColor: Colors.grey,
                            inactiveTrackColor: Colors.white12,
                            onChanged: onToggleAvailable,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackThumbnail(bool isDrink) {
    return Container(
      color: const Color(0xFF0F3460),
      child: Center(
        child: Text(isDrink ? '🥤' : '🍕', style: const TextStyle(fontSize: 26)),
      ),
    );
  }
}

