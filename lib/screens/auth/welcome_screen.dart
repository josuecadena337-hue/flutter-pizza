import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../controllers/auth_controller.dart';
import '../../models/product_model.dart';
import '../../services/seed_data_service.dart';
import 'auth_wrapper.dart';
import 'login_screen.dart';

/// Pantalla de Bienvenida Pública (WelcomeScreen).
///
/// Primera pantalla que ve cualquier persona al abrir la app antes de iniciar sesión.
/// Muestra el menú completo (pizzas y bebidas) en tiempo real con Firestore en modo
/// 'solo vista' (sin agregar al carrito), con filtros por categoría y accesos para
/// iniciar sesión o registrarse.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String _selectedCategory = 'pizza'; // Por defecto muestra pizzas

  @override
  void initState() {
    super.initState();
    // Si el usuario ya tenía sesión abierta en este dispositivo, lo dirigimos a su panel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingSession();
      SeedDataService.seedIfMissing();
    });
  }

  void _checkExistingSession() {
    final auth = Provider.of<AuthController>(context, listen: false);
    if (auth.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
      );
    }
  }

  void _goToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: CustomScrollView(
            slivers: [
              // ── Header expandible de bienvenida ───────────────────────────
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                backgroundColor: const Color(0xFF16213E),
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
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
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Degradado cálido nocturno
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFE64A19), Color(0xFF1A1A2E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      // Texto de bienvenida en el encabezado
                      Positioned(
                        top: 50,
                        left: 20,
                        right: 100,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '🔥 Menú Artesanal Disponible',
                                style: TextStyle(
                                  color: Color(0xFFFFB74D),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '¡Bienvenido a Appizza!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Pide tus pizzas favoritas y bebidas heladas directo a tu puerta.',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton.icon(
                    onPressed: _goToLogin,
                    icon: const Icon(Icons.login_rounded, color: Colors.white, size: 18),
                    label: const Text(
                      'Entrar',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFE64A19).withValues(alpha: 0.8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),

              // ── Selector de Categorías (Pizzas / Bebidas / Todo) ───────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Explora Nuestro Catálogo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Solo Vista',
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildCategoryChip('pizza', '🍕 Pizzas', Icons.local_pizza_rounded),
                            const SizedBox(width: 8),
                            _buildCategoryChip('bebida', '🥤 Bebidas', Icons.local_drink_rounded),
                            const SizedBox(width: 8),
                            _buildCategoryChip('todas', '✨ Todo el Menú', Icons.restaurant_menu_rounded),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── StreamBuilder en Tiempo Real desde Cloud Firestore ─────────
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .where('available', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
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
                              'Cargando menú en tiempo real...',
                              style: TextStyle(color: Colors.white60, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off, size: 56, color: Colors.redAccent),
                              const SizedBox(height: 12),
                              const Text(
                                'Error al sincronizar con Firestore',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
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

                  final docs = snapshot.data?.docs ?? [];
                  final allProducts = docs.map((doc) => ProductModel.fromFirestore(doc)).toList();

                  final filteredProducts = _selectedCategory == 'todas'
                      ? allProducts
                      : allProducts.where((p) => p.categoria.toLowerCase() == _selectedCategory).toList();

                  if (filteredProducts.isEmpty) {
                    final isDrink = _selectedCategory == 'bebida';
                    return SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(isDrink ? '🥤' : '🍕', style: const TextStyle(fontSize: 56)),
                              const SizedBox(height: 12),
                              Text(
                                isDrink ? 'No hay bebidas registradas' : 'No hay productos disponibles',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isDrink
                                    ? 'Agrega bebidas en la colección "products" con categoria: "bebida".'
                                    : 'Asegúrate de tener productos en Firestore con available: true.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // Grid de productos en modo solo vista
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.68,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = filteredProducts[index];
                          return _PublicProductCard(
                            product: product,
                            onTap: () => _showProductDetailsModal(context, product),
                            onOrderTap: _goToLogin,
                          );
                        },
                        childCount: filteredProducts.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
  }

  Widget _buildCategoryChip(String key, String label, IconData icon) {
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

  /// Despliega el modal de detalle informativo (solo vista) con invitación a iniciar sesión
  void _showProductDetailsModal(BuildContext context, ProductModel product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PublicProductDetailModal(
        product: product,
        onOrderTap: () {
          Navigator.of(ctx).pop();
          _goToLogin();
        },
      ),
    );
  }
}

/// Tarjeta individual del producto en modo Solo Vista para WelcomeScreen
class _PublicProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback onOrderTap;

  const _PublicProductCard({
    required this.product,
    required this.onTap,
    required this.onOrderTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDrink = product.categoria.toLowerCase() == 'bebida';

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
            // ── Foto con Badge de Categoría ─────────────────────────────────
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (product.imageUrl.isNotEmpty)
                    Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _fallbackImage(isDrink),
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE64A19)),
                        );
                      },
                    )
                  else
                    _fallbackImage(isDrink),

                  // Badge de Categoría (Pill)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isDrink ? '🥤 Bebida' : '🍕 Pizza',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  // Gradiente inferior
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 28,
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

            // ── Info: Nombre, Descripción y Precio (Sin botón de añadir a carrito)
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
                    const SizedBox(height: 3),
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '\$${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF7043),
                          ),
                        ),
                        // Botón informativo "Ver"
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F3460),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Ver',
                                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_right, size: 14, color: Colors.white60),
                            ],
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

  Widget _fallbackImage(bool isDrink) {
    return Container(
      color: const Color(0xFF0F3460),
      child: Center(
        child: Text(
          isDrink ? '🥤' : '🍕',
          style: const TextStyle(fontSize: 34),
        ),
      ),
    );
  }
}

/// Modal Bottom Sheet informativo para la vista previa de un producto en WelcomeScreen
class _PublicProductDetailModal extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onOrderTap;

  const _PublicProductDetailModal({
    required this.product,
    required this.onOrderTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDrink = product.categoria.toLowerCase() == 'bebida';

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
            // Asa superior
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
                        errorBuilder: (context, error, stackTrace) => _fallbackImage(isDrink),
                      )
                    : _fallbackImage(isDrink),
              ),
            ),
            const SizedBox(height: 16),

            // Nombre y Precio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDrink ? 'Categoría: Bebida 🥤' : 'Categoría: Pizza Artesanal 🍕',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFFF7043)),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${product.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFF7043),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Descripción
            Text(
              product.description.isNotEmpty
                  ? product.description
                  : (isDrink ? 'Refrescante bebida servida bien helada.' : 'Deliciosa pizza artesanal preparada al horno.'),
              style: const TextStyle(
                fontSize: 13.5,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Botón CTA para iniciar sesión
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onOrderTap,
                icon: const Icon(Icons.login_rounded),
                label: const Text(
                  'INICIAR SESIÓN PARA ORDENAR',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE64A19),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackImage(bool isDrink) {
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
