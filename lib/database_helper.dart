import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Product {
  final int? id;
  final String name;
  final double price;
  final String category;

  Product({this.id, required this.name, required this.price, required this.category});

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      price: (map['price'] as num).toDouble(),
      category: map['category'],
    );
  }
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get subtotal => product.price * quantity;
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos_master.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        category TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payment_method TEXT NOT NULL,
        total REAL NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER,
        product_name TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        subtotal REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE void_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_name TEXT NOT NULL,
        reason TEXT NOT NULL,
        cashier_name TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    // Tabel Key Manajer eksklusif buatan Developer
    await db.execute('''
      CREATE TABLE manager_keys (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        manager_name TEXT NOT NULL,
        secret_key TEXT UNIQUE NOT NULL,
        bound_device_id TEXT DEFAULT NULL
      )
    ''');

    // Seed Data Produk Awal
    await db.insert('products', {'name': 'Tahu Crispy Original', 'price': 15000.0, 'category': 'Makanan'});
    await db.insert('products', {'name': 'Tahu Walik Sambal Kecap', 'price': 18000.0, 'category': 'Makanan'});
    await db.insert('products', {'name': 'Es Teh Manis', 'price': 5000.0, 'category': 'Minuman'});
    await db.insert('products', {'name': 'Es Jeruk Nipis', 'price': 7000.0, 'category': 'Minuman'});

    // Seed Key Manajer (Dibuat oleh Developer)
    await db.insert('manager_keys', {'manager_name': 'Manajer Cabang 1', 'secret_key': 'KEY-MGR-01', 'bound_device_id': null});
    await db.insert('manager_keys', {'manager_name': 'Manajer Cabang 2', 'secret_key': 'KEY-MGR-02', 'bound_device_id': null});
  }

  // Fungsi Validasi & Binding Key agar 1 Key hanya untuk 1 Device
  Future<Map<String, dynamic>?> validateAndBindKey(String inputKey, String currentDeviceId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> result = await db.query(
      'manager_keys',
      where: 'secret_key = ?',
      whereArgs: [inputKey],
    );

    if (result.isEmpty) return null;

    final keyData = result.first;
    String? boundDevice = keyData['bound_device_id'] as String?;

    if (boundDevice == null) {
      await db.update(
        'manager_keys',
        {'bound_device_id': currentDeviceId},
        where: 'secret_key = ?',
        whereArgs: [inputKey],
      );
      return {'status': 'success', 'manager': keyData['manager_name']};
    } else if (boundDevice == currentDeviceId) {
      return {'status': 'success', 'manager': keyData['manager_name']};
    } else {
      return {'status': 'device_mismatch', 'bound_device': boundDevice};
    }
  }

  Future<List<Product>> getProducts() async {
    final db = await instance.database;
    final result = await db.query('products');
    return result.map((json) => Product.fromMap(json)).toList();
  }

  Future<void> saveTransactionWithPayment(String paymentMethod, double total, List<CartItem> cart) async {
    final db = await instance.database;
    int txId = await db.insert('transactions', {
      'payment_method': paymentMethod,
      'total': total,
      'date': DateTime.now().toIso8601String(),
    });

    for (var item in cart) {
      await db.insert('transaction_items', {
        'transaction_id': txId,
        'product_name': item.product.name,
        'payment_method': paymentMethod,
        'quantity': item.quantity,
        'subtotal': item.subtotal,
      });
    }
  }

  Future<void> logVoid(String productName, String reason, String cashierName) async {
    final db = await instance.database;
    await db.insert('void_logs', {
      'product_name': productName,
      'reason': reason,
      'cashier_name': cashierName,
      'date': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> getRecapData() async {
    final db = await instance.database;
    final txResult = await db.rawQuery('SELECT payment_method, SUM(total) as total_omset FROM transactions GROUP BY payment_method');
    Map<String, double> omset = {};
    for (var row in txResult) {
      omset[row['payment_method'].toString()] = (row['total_omset'] as num).toDouble();
    }

    final itemResult = await db.rawQuery('''
      SELECT payment_method, product_name, SUM(quantity) as total_qty, SUM(subtotal) as total_price 
      FROM transaction_items 
      GROUP BY payment_method, product_name
    ''');

    Map<String, List<Map<String, dynamic>>> items = {};
    for (var row in itemResult) {
      String method = row['payment_method'].toString();
      if (!items.containsKey(method)) items[method] = [];
      items[method]!.add({
        'name': row['product_name'],
        'qty': row['total_qty'],
        'total_price': row['total_price'],
      });
    }

    return {'omset': omset, 'items': items};
  }
}
