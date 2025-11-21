// lib/src/core/db/daos/products_dao.dart
// DAO متمرکز برای محصولات، واحدها و نگهداری توالیها (sequences).
// بروزرسانی: افزودن ستون price و reorder_point و purchase_price به inventory_items (محصول)
// کامنت فارسی مختصر برای هر بخش گذاشته شده است.

import 'package:sqflite/sqflite.dart';

Future<void> createProductsTables(Database db) async {
  // جدول واحدها
  await db.execute('''
    CREATE TABLE IF NOT EXISTS units (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      abbr TEXT,
      created_at INTEGER
    )
  ''');

  // جدول محصولات (inventory_items) با ستونهای مرتبط با تصویر و بارکد و قیمت/نقطه سفارش و قیمت خرید
  await db.execute('''
    CREATE TABLE IF NOT EXISTS inventory_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      sku TEXT,
      product_code TEXT,
      barcode TEXT,
      barcode_store TEXT,
      barcode_global TEXT,
      barcode_type TEXT,
      barcode_image TEXT,
      image_path TEXT,
      description TEXT,
      unit TEXT,
      unit_id INTEGER,
      price REAL DEFAULT 0,
      purchase_price REAL DEFAULT 0,
      reorder_point REAL DEFAULT 0,
      created_at INTEGER
    )
  ''');

  // جدول sequences
  await db.execute('''
    CREATE TABLE IF NOT EXISTS sequences (
      name TEXT PRIMARY KEY,
      value INTEGER DEFAULT 0
    )
  ''');
}

Future<void> migrateProductsTables(Database db) async {
  try {
    final info = await db.rawQuery("PRAGMA table_info(inventory_items)");
    if (info.isEmpty) {
      await createProductsTables(db);
      return;
    }

    Future<void> maybeAdd(String colDef, String colName) async {
      if (!info.any((r) => (r['name']?.toString() ?? '') == colName)) {
        try {
          await db.execute('ALTER TABLE inventory_items ADD COLUMN $colDef');
        } catch (_) {}
      }
    }

    await maybeAdd('product_code TEXT', 'product_code');
    await maybeAdd('barcode_store TEXT', 'barcode_store');
    await maybeAdd('barcode_global TEXT', 'barcode_global');
    await maybeAdd('image_path TEXT', 'image_path');
    await maybeAdd('unit_id INTEGER', 'unit_id');
    await maybeAdd('barcode_type TEXT', 'barcode_type');
    await maybeAdd('barcode_image TEXT', 'barcode_image');

    // افزدون price و reorder_point و purchase_price اگر وجود ندارند
    await maybeAdd('price REAL DEFAULT 0', 'price');
    await maybeAdd('purchase_price REAL DEFAULT 0', 'purchase_price');
    await maybeAdd('reorder_point REAL DEFAULT 0', 'reorder_point');
  } catch (_) {
    try {
      await createProductsTables(db);
    } catch (_) {}
  }

  // جدول units
  try {
    final unitsInfo = await db.rawQuery("PRAGMA table_info(units)");
    if (unitsInfo.isEmpty) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS units (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          abbr TEXT,
          created_at INTEGER
        )
      ''');
    }
  } catch (_) {}
}

// ---------- sequences helpers ----------
Future<int> getNextSequence(Database db, String name) async {
  return await db.transaction<int>((txn) async {
    final rows =
        await txn.query('sequences', where: 'name = ?', whereArgs: [name]);
    if (rows.isEmpty) {
      await txn.insert('sequences', {'name': name, 'value': 1});
      return 1;
    } else {
      final cur = rows.first['value'];
      final int curVal =
          (cur is int) ? cur : int.tryParse(cur?.toString() ?? '0') ?? 0;
      final next = curVal + 1;
      await txn.update('sequences', {'value': next},
          where: 'name = ?', whereArgs: [name]);
      return next;
    }
  });
}

Future<int> getCurrentSequence(Database db, String name) async {
  final rows = await db.query('sequences',
      where: 'name = ?', whereArgs: [name], limit: 1);
  if (rows.isEmpty) return 0;
  final v = rows.first['value'];
  return (v is int) ? v : int.tryParse(v?.toString() ?? '0') ?? 0;
}

Future<String> generateNextProductCode(Database db) async {
  final seq = await getNextSequence(db, 'product_code_seq');
  final codeNumber = 1000 + seq;
  return 'p$codeNumber';
}

// ---------- products CRUD ----------
Future<int> saveProduct(Database db, Map<String, dynamic> item) async {
  final Map<String, dynamic> toSave = Map<String, dynamic>.from(item);
  toSave['created_at'] ??= DateTime.now().millisecondsSinceEpoch;
  if (toSave.containsKey('id') && toSave['id'] != null) {
    final id = toSave['id'];
    toSave.remove('id');
    return await db
        .update('inventory_items', toSave, where: 'id = ?', whereArgs: [id]);
  } else {
    return await db.insert('inventory_items', toSave);
  }
}

Future<List<Map<String, dynamic>>> getProducts(Database db, {String? q}) async {
  if (q != null && q.trim().isNotEmpty) {
    final s = '%${q.trim()}%';
    return await db.query('inventory_items',
        where:
            'name LIKE ? OR sku LIKE ? OR product_code LIKE ? OR barcode LIKE ? OR barcode_global LIKE ?',
        whereArgs: [s, s, s, s, s],
        orderBy: 'name ASC');
  }
  return await db.query('inventory_items', orderBy: 'name ASC');
}

Future<Map<String, dynamic>?> getProductById(Database db, int id) async {
  final rows = await db.query('inventory_items',
      where: 'id = ?', whereArgs: [id], limit: 1);
  if (rows.isEmpty) return null;
  return rows.first;
}

Future<int> deleteProduct(Database db, int id) async {
  try {
    await db.delete('stock_levels', where: 'item_id = ?', whereArgs: [id]);
    await db.delete('stock_movements', where: 'item_id = ?', whereArgs: [id]);
  } catch (_) {}
  return await db.delete('inventory_items', where: 'id = ?', whereArgs: [id]);
}

// ---------- units CRUD ----------
Future<int> saveUnit(Database db, Map<String, dynamic> unit) async {
  final Map<String, dynamic> toSave = Map<String, dynamic>.from(unit);
  toSave['created_at'] ??= DateTime.now().millisecondsSinceEpoch;
  if (toSave.containsKey('id') && toSave['id'] != null) {
    final id = toSave['id'];
    toSave.remove('id');
    return await db.update('units', toSave, where: 'id = ?', whereArgs: [id]);
  } else {
    return await db.insert('units', toSave);
  }
}

Future<List<Map<String, dynamic>>> getUnits(Database db) async {
  return await db.query('units', orderBy: 'name ASC');
}

Future<int> deleteUnit(Database db, int id) async {
  try {
    await db.update('inventory_items', {'unit_id': null, 'unit': null},
        where: 'unit_id = ?', whereArgs: [id]);
  } catch (_) {}
  return await db.delete('units', where: 'id = ?', whereArgs: [id]);
}
