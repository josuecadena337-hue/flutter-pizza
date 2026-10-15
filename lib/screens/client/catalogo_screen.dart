import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/cart_controller.dart';
import '../../models/product_model.dart';
import 'cart_screen.dart';
import 'order_tracking_screen.dart';
import '../auth/welcome_screen.dart';

/// Pantalla de Catálogo para el Rol CLIENTE.
///
/// ¿Por qué usamos `StreamBuilder` con Firestore?
/// -------------------------------------------------------------
/// - `StreamBuilder` se suscribe a un flujo continuo de datos (`snapshots()`).
///   Firestore mantiene un canal en tiempo real: en cuanto un documento cambia,
///   se agrega o se oculta (`available: false`), Firestore empuja los nuevos datos
///   y el `StreamBuilder` redibuja la lista al instante sin recargar la pantalla.
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String _selectedCategory = 'pizza'; // 'pizza', 'bebida', 'todas'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: CustomScrollView(
        slivers: [
          // ── Header expandible con logo y acciones ─────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: const Color(0xFF16213E),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 14),
              title: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE64A19),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🍕', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Appizza',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE64A19), Color(0xFF16213E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.only(left: 16, top: 40),
                child: const Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    'Nuestras Pizzas Artesanales',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
            ),
            actions: [
              // Botón del carrito con Badge reactivo
              Consumer<CartController>(
                builder: (context, cart, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 26),
                        tooltip: 'Ver Carrito',
                        onPressed: () {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CartScreen()),
                          );
                        },
                      ),
                      if (cart.totalItemCount > 0)
                        Positioned(
                          right: 6,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE64A19),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              '${cart.totalItemCount}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              // Menú de usuario / Cerrar sesión
              Consumer<AuthController>(
                builder: (context, auth, _) {
                  final user = auth.currentUser;
                  final initial = (user != null && user.name.isNotEmpty)
                      ? user.name[0].toUpperCase()
                      : 'C';

                  return PopupMenuButton<String>(
                    icon: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFE64A19),
                      child: Text(
                        initial,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    color: const Color(0xFF16213E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) {
                      if (val == 'logout') {
                        auth.logout();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                          (route) => false,
                        );
                      } else if (val == 'orders') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OrderTrackingScreen()),
                        );
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        enabled: false,
                        child: Text(
                          user?.name ?? 'Cliente',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const PopupMenuItem(
                        enabled: false,
                        child: Text(
                          'Rol: Cliente 🛵',
                          style: TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'orders',
                        child: Row(
                          children: [
                            Icon(Icons.delivery_dining, color: Color(0xFFFF7043), size: 18),
                            SizedBox(width: 8),
                            Text('Mis Pedidos', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
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
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ── Selector de Categorías (Pizzas / Bebidas / Todo) ─────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryPill('pizza', '🍕 Pizzas', Icons.local_pizza_rounded),
                    const SizedBox(width: 8),
                    _buildCategoryPill('bebida', '🥤 Bebidas', Icons.local_drink_rounded),
                    const SizedBox(width: 8),
                    _buildCategoryPill('todas', '✨ Todo el Menú', Icons.restaurant_menu_rounded),
                  ],
                ),
              ),
            ),
          ),

          // ── StreamBuilder: Catálogo en Tiempo Real desde Firestore ─────────
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            // Consultamos la colección 'products' filtrando solo los que están disponibles (available: true)
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('available', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              // 1. Estado de carga inicial mientras conecta con Firestore
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE64A19)),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Cargando menú de pizzas...',
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // 2. Si ocurre algún error en la conexión o consulta
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off, size: 64, color: Colors.redAccent),
                          const SizedBox(height: 16),
                          const Text(
                            'Error al conectar con Firestore',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // 3. Mapear y filtrar productos por categoría seleccionada
              final docs = snapshot.data?.docs ?? [];
              final allProducts = docs.map((doc) => ProductModel.fromFirestore(doc)).toList();

              final products = _selectedCategory == 'todas'
                  ? allProducts
                  : allProducts.where((p) => p.categoria.toLowerCase() == _selectedCategory).toList();

              if (products.isEmpty) {
                final isDrink = _selectedCategory == 'bebida';
                return SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(isDrink ? '🥤' : '🍕', style: const TextStyle(fontSize: 64)),
                          const SizedBox(height: 16),
                          Text(
                            isDrink ? 'No hay bebidas disponibles' : 'No hay pizzas disponibles',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isDrink
                                ? 'Pronto agregaremos refrescantes bebidas a nuestro menú.'
                                : 'Agrega productos a la colección "products" en Firebase Console con "available": true.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // 4. Grid de tarjetas de pizzas y bebidas
              return SliverPadding(
                padding: const EdgeInsets.all(14),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.68,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = products[index];
                      return _ProductCard(
                        product: product,
                        onTap: () => _showProductDetailsModal(context, product),
                        onQuickAdd: () => _showAddedToCartSnackBar(product, 1),
                      );
                    },
                    childCount: products.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(String key, String label, IconData icon) {
    final isSelected = _selectedCategory == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE64A19) : const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF7043) : Colors.white12,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFE64A19).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : Colors.white60,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddedToCartSnackBar(ProductModel product, int quantity) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F3460),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        dismissDirection: DismissDirection.horizontal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Text('🍕', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Agregaste $quantity x ${product.name} al carrito',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Ver Carrito',
          textColor: const Color(0xFFFF7043),
          onPressed: () {
            messenger.clearSnackBars();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            );
          },
        ),
      ),
    );
  }

  /// Despliega el Modal Bottom Sheet con la información detallada de la pizza
  /// y el selector interactivo de cantidad (+ y -).
  void _showProductDetailsModal(BuildContext context, ProductModel product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductDetailModal(
        product: product,
        onAdded: (quantity) {
          _showAddedToCartSnackBar(product, quantity);
        },
      ),
    );
  }
}

/// Tarjeta individual para cada pizza en el catálogo.
class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback onQuickAdd;

  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Foto del producto ───────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (product.imageUrl.isNotEmpty)
                    Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _fallbackImage(),
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE64A19)),
                        );
                      },
                    )
                  else
                    _fallbackImage(),
                  // Gradiente oscuro inferior para resaltar el texto
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 30,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Color(0xFF16213E)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Información: Nombre, Descripción y Precio ────────────────────
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white60,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF7043),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            final cart = Provider.of<CartController>(context, listen: false);
                            cart.addItem(product, quantity: 1);
                            onQuickAdd();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE64A19),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackImage() {
    final isDrink = product.categoria.toLowerCase() == 'bebida';
    return Container(
      color: const Color(0xFF0F3460),
      child: Center(
        child: Icon(
          isDrink ? Icons.local_drink_outlined : Icons.local_pizza_outlined,
          size: 48,
          color: Colors.white30,
        ),
      ),
    );
  }
}

/// Modal Bottom Sheet para ver el detalle de la pizza y elegir cantidad.
class _ProductDetailModal extends StatefulWidget {
  final ProductModel product;
  final void Function(int quantity) onAdded;

  const _ProductDetailModal({
    required this.product,
    required this.onAdded,
  });

  @override
  State<_ProductDetailModal> createState() => _ProductDetailModalState();
}

class _ProductDetailModalState extends State<_ProductDetailModal> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final total = product.price * _quantity;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra superior de agarre del modal
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Foto grande
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _fallbackImage(),
                      )
                    : _fallbackImage(),
              ),
            ),
            const SizedBox(height: 16),

            // Nombre y Precio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  '\$${product.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFF7043),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Descripción completa / Ingredientes
            Text(
              product.description.isNotEmpty
                  ? product.description
                  : 'Deliciosa pizza artesanal preparada con ingredientes frescos.',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Selector de Cantidad (- y +)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cantidad:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F3460),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.white),
                        onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                      ),
                      Text(
                        '$_quantity',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Color(0xFFFF7043)),
                        onPressed: () => setState(() => _quantity++),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Botón de Confirmación para Agregar al Carrito
            ElevatedButton(
              onPressed: () {
                // 1. Agregamos al CartController
                final cart = Provider.of<CartController>(context, listen: false);
                cart.addItem(product, quantity: _quantity);

                // 2. Cerramos el modal
                Navigator.pop(context);

                // 3. Notificamos al catálogo padre para mostrar el SnackBar usando el context válido
                widget.onAdded(_quantity);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE64A19),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_shopping_cart, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Agregar al carrito • \$${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackImage() {
    final isDrink = widget.product.categoria.toLowerCase() == 'bebida';
    return Container(
      color: const Color(0xFF0F3460),
      child: Center(
        child: Icon(
          isDrink ? Icons.local_drink_outlined : Icons.local_pizza,
          size: 64,
          color: Colors.white30,
        ),
      ),
    );
  }
}
