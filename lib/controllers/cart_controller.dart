import 'package:flutter/material.dart';
import '../models/product_model.dart';

/// Representa un elemento dentro del carrito de compras.
class CartItem {
  final ProductModel product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  /// Subtotal dinámico: precio unitario multiplicado por la cantidad elegida
  double get subtotal => product.price * quantity;
}

/// Controlador del Carrito con Provider (`ChangeNotifier`).
///
/// ¿Por qué usamos `ChangeNotifier` aquí?
/// -------------------------------------------------------------
/// 1. `ChangeNotifier` es una clase de Flutter que implementa el patrón Observador (Observer).
/// 2. Cuando el cliente agrega una pizza, modifica una cantidad o elimina un ítem,
///    este controlador altera la lista interna y luego ejecuta `notifyListeners()`.
/// 3. `notifyListeners()` emite una señal a todos los widgets que están "escuchando"
///    a este `CartController` (como el badge con el número en el Catálogo y la lista en el Carrito).
/// 4. Flutter redibuja instantáneamente solo los widgets afectados, sin tener que pasar
///    callbacks entre pantallas ni llamar a `setState()` en toda la aplicación.
class CartController with ChangeNotifier {
  // Mapa de ítems en memoria: la clave es el id del producto (String)
  final Map<String, CartItem> _items = {};

  /// Mapa de productos en el carrito
  Map<String, CartItem> get items => _items;

  /// Lista ordenada de elementos en el carrito
  List<CartItem> get cartItems => _items.values.toList();

  /// Cantidad de productos distintos (variedades de pizza)
  int get distinctItemCount => _items.length;

  /// Cantidad total de unidades de pizza sumando todas las porciones
  int get totalItemCount => _items.values.fold(0, (sum, item) => sum + item.quantity);

  /// Monto total general acumulado a pagar
  double get totalAmount => _items.values.fold(0.0, (sum, item) => sum + item.subtotal);

  /// ¿El carrito está vacío?
  bool get isEmpty => _items.isEmpty;

  /// Agrega un producto al carrito.
  /// Si el producto ya existía, suma la cantidad recibida en lugar de duplicarlo.
  void addItem(ProductModel product, {int quantity = 1}) {
    final key = product.id.toString();

    if (_items.containsKey(key)) {
      // Si ya está, aumentamos su cantidad
      _items.update(
        key,
        (existing) => CartItem(
          product: existing.product,
          quantity: existing.quantity + quantity,
        ),
      );
    } else {
      // Si es nuevo, lo agregamos al mapa
      _items.putIfAbsent(
        key,
        () => CartItem(product: product, quantity: quantity),
      );
    }

    // Notificamos a la UI (Catálogo, Badge, Carrito) para que se actualicen
    notifyListeners();
  }

  /// Disminuye en 1 la cantidad de un producto. Si llega a 0, lo retira.
  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) return;

    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
        (existing) => CartItem(
          product: existing.product,
          quantity: existing.quantity - 1,
        ),
      );
    } else {
      _items.remove(productId);
    }

    notifyListeners();
  }

  /// Elimina un producto por completo del carrito, sin importar la cantidad que tuviera
  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  /// Vacía todo el carrito
  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
