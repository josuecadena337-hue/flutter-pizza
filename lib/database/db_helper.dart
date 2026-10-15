import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';
import '../models/order_model.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pizza_ventas.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 3, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        pizza_size TEXT NOT NULL,
        price REAL NOT NULL,
        stock INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        client_name TEXT NOT NULL,
        total REAL NOT NULL,
        date TEXT NOT NULL,
        is_notified INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pendiente',
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders (id)
      )
    ''');

    // Usuarios por defecto
    await db.insert('users', {
      'name': 'Administrador Pizzeria',
      'email': 'admin@pizza.com',
      'password': 'admin',
      'role': 'admin'
    });

    await db.insert('users', {
      'name': 'Repartidor Principal',
      'email': 'repartidor@pizza.com',
      'password': 'repartidor',
      'role': 'repartidor'
    });

    // Productos de ejemplo
    await _insertSeedProducts(db);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute("ALTER TABLE orders ADD COLUMN status TEXT DEFAULT 'pendiente'");
      } catch (_) {}
    }
    if (oldVersion < 3) {
      // Insertar productos si la tabla esta vacia
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM products'),
      ) ?? 0;
      if (count == 0) {
        await _insertSeedProducts(db);
      }
    }
  }

  static Future<void> _insertSeedProducts(Database db) async {
    final products = [
      {'name': 'Margherita Clásica',      'pizza_size': 'Mediana (10")', 'price': 28000.0, 'stock': 20},
      {'name': 'Pepperoni Especial',       'pizza_size': 'Grande (14")',  'price': 38000.0, 'stock': 15},
      {'name': 'Hawaiana Tropical',        'pizza_size': 'Mediana (10")', 'price': 32000.0, 'stock': 18},
      {'name': 'Cuatro Quesos',            'pizza_size': 'Grande (14")',  'price': 42000.0, 'stock': 10},
      {'name': 'BBQ Pollo',                'pizza_size': 'Grande (14")',  'price': 40000.0, 'stock': 12},
      {'name': 'Veggie Suprema',           'pizza_size': 'Mediana (10")', 'price': 30000.0, 'stock': 14},
      {'name': 'Carnívora Deluxe',         'pizza_size': 'Familiar (16")', 'price': 55000.0, 'stock': 8},
      {'name': 'Pepperoni Personal',       'pizza_size': 'Personal (6")', 'price': 18000.0, 'stock': 25},
      {'name': 'Mexicana Picante',         'pizza_size': 'Grande (14")',  'price': 41000.0, 'stock': 10},
      {'name': 'Funghi e Prosciutto',      'pizza_size': 'Mediana (10")', 'price': 35000.0, 'stock': 12},
    ];
    for (final p in products) {
      await db.insert('products', p);
    }
  }

  // ─── CRUD Productos ───────────────────────────────────────────────────────
  Future<int> insertProduct(Product product) async {
    final db = await instance.database;
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getProducts() async {
    final db = await instance.database;
    final result = await db.query('products');
    return result.map((json) => Product.fromMap(json)).toList();
  }

  Future<int> updateProduct(Product product) async {
    final db = await instance.database;
    return await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Autenticacion ────────────────────────────────────────────────────────
  Future<int> registerUser(User user) async {
    final db = await instance.database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> login(String email, String password) async {
    final db = await instance.database;
    final maps = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    if (maps.isNotEmpty) return User.fromMap(maps.first);
    return null;
  }

  // ─── Pedidos ──────────────────────────────────────────────────────────────
  Future<bool> createOrder(OrderModel order, List<Map<String, dynamic>> items) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final orderId = await txn.insert('orders', order.toMap());
      for (var item in items) {
        await txn.insert('order_items', {
          'order_id': orderId,
          'product_id': item['product'].id,
          'product_name': item['product'].name,
          'quantity': item['quantity'],
          'unit_price': item['product'].price,
        });
      }
      return true;
    });
  }

  Future<List<OrderModel>> getUnreadOrders() async {
    final db = await instance.database;
    final result = await db.query('orders', where: 'is_notified = 0', orderBy: 'id DESC');
    return result.map((json) => OrderModel.fromMap(json)).toList();
  }

  Future<void> markOrdersAsRead() async {
    final db = await instance.database;
    await db.update('orders', {'is_notified': 1}, where: 'is_notified = 0');
  }

  Future<List<OrderModel>> getAllOrders() async {
    final db = await instance.database;
    final result = await db.query('orders', orderBy: 'id DESC');
    return result.map((json) => OrderModel.fromMap(json)).toList();
  }

  /// Pedidos que el repartidor puede ver (pendiente y en_camino)
  Future<List<OrderModel>> getActiveOrders() async {
    final db = await instance.database;
    final result = await db.query(
      'orders',
      where: "status IN ('pendiente', 'en_camino')",
      orderBy: 'id DESC',
    );
    return result.map((json) => OrderModel.fromMap(json)).toList();
  }

  /// Actualizar el status de un pedido
  Future<int> updateOrderStatus(int orderId, String status) async {
    final db = await instance.database;
    return await db.update(
      'orders',
      {'status': status},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }
}
