import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/cart_controller.dart';
import 'checkout_screen.dart';

/// Pantalla del Carrito de Compras para el Rol CLIENTE.
///
/// ¿Cómo interactúa con Provider?
/// -------------------------------------------------------------
/// Esta pantalla se suscribe a `CartController` mediante `Consumer<CartController>`.
/// Cada vez que el usuario presiona '+' o '-' o 'eliminar', el `CartController`
/// actualiza la memoria y llama a `notifyListeners()`. En ese instante, este widget
/// se redibuja automáticamente mostrando los nuevos subtotales y el total acumulado.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Limpiamos cualquier notificación flotante previa para que no obstruya el carrito
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Row(
          children: [
            Text('🛒', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Mi Carrito de Pizzas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Consumer<CartController>(
            builder: (context, cart, _) {
              if (cart.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                tooltip: 'Vaciar Carrito',
                onPressed: () => _confirmClearCart(context, cart),
              );
            },
          ),
        ],
      ),
      body: Consumer<CartController>(
        builder: (context, cart, _) {
          // ── 1. Estado cuando el carrito está vacío ─────────────────────────
          if (cart.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16213E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Text('🍕', style: TextStyle(fontSize: 64)),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Tu carrito está vacío',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Aún no has agregado ninguna pizza a tu orden. Explora el menú y elige tus favoritas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.white60, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.restaurant_menu),
                      label: const Text('Explorar Menú'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE64A19),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // ── 2. Lista de productos agregados ────────────────────────────────
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.cartItems.length,
                  itemBuilder: (ctx, index) {
                    final item = cart.cartItems[index];
                    return _CartItemCard(item: item, cart: cart);
                  },
                ),
              ),

              // ── 3. Barra inferior de Total y Confirmar Pedido ──────────────
              _CartFooter(cart: cart),
            ],
          );
        },
      ),
    );
  }

  void _confirmClearCart(BuildContext context, CartController cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('¿Vaciar carrito?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Se eliminarán todas las pizzas de tu orden actual.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () {
              cart.clearCart();
              Navigator.pop(ctx);
            },
            child: const Text('Vaciar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta individual para cada pizza en el carrito.
class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final CartController cart;

  const _CartItemCard({required this.item, required this.cart});

  @override
  Widget build(BuildContext context) {
    final product = item.product;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Imagen pequeña de la pizza
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: product.imageUrl.isNotEmpty
                  ? Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _fallbackImage(),
                    )
                  : _fallbackImage(),
            ),
          ),
          const SizedBox(width: 12),

          // Información: Nombre, Precio unitario y Subtotal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '\$${product.price.toStringAsFixed(0)} c/u',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
                const SizedBox(height: 6),
                Text(
                  'Subtotal: \$${item.subtotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFF7043),
                  ),
                ),
              ],
            ),
          ),

          // Controles de cantidad: - [cant] +
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F3460),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18, color: Colors.white),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () => cart.removeSingleItem(product.id.toString()),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18, color: Color(0xFFFF7043)),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () => cart.addItem(product, quantity: 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),

          // Botón para eliminar completamente el producto
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            tooltip: 'Eliminar',
            onPressed: () => cart.removeItem(product.id.toString()),
          ),
        ],
      ),
    );
  }

  Widget _fallbackImage() {
    final isDrink = item.product.categoria.toLowerCase() == 'bebida';
    return Container(
      color: const Color(0xFF0F3460),
      child: Center(
        child: Icon(
          isDrink ? Icons.local_drink_outlined : Icons.local_pizza,
          size: 32,
          color: Colors.white30,
        ),
      ),
    );
  }
}

/// Pie de página con el monto total y botón de confirmar pedido.
class _CartFooter extends StatelessWidget {
  final CartController cart;

  const _CartFooter({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Resumen de cantidad y Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total (${cart.totalItemCount} pizzas):',
                      style: const TextStyle(fontSize: 13, color: Colors.white60),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${cart.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF7043),
                      ),
                    ),
                  ],
                ),
                // Botón Confirmar Pedido
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE64A19),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Confirmar pedido',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
