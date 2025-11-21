// lib/src/core/db/daos/warehouses_dao.dart
// DAO مدیریت انبارها (warehouses) — ایجاد جدول و متدهای CRUD ساده.
// کامنت فارسی مختصر: هر متد یک وظیفهٔ مشخص دارد.

import 'package:sqflite/sqflite.dart';

Future<void> createWarehousesTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS warehouses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      code TEXT,
      address TEXT,
      phone TEXT,
      email TEXT,
      manager TEXT,
      created_at INTEGER
    )
  ''');
}

// مهاجرت محافظه‌کارانه: اگر جدول وجود ندارد آن را ایجاد کن، وگرنه فقط ستون‌های جدید را اضافه کن
Future<void> migrateWarehousesTable(Database db) async {
  try {
    // بررسی وجود جدول با PRAGMA table_info
    final info = await db.rawQuery("PRAGMA table_info(warehouses)");
    if (info.isEmpty) {
      // جدول وجود ندارد -> ایجاد جدول کامل
      await createWarehousesTable(db);
      return;
    }

    // اگر ستون code وجود ندارد آن را اضافه کن
    if (!info.any((r) => (r['name']?.toString() ?? '') == 'code')) {
      try {
        await db.execute("ALTER TABLE warehouses ADD COLUMN code TEXT");
      } catch (_) {}
    }
    // اگر ستون manager وجود ندارد آن را اضافه کن
    if (!info.any((r) => (r['name']?.toString() ?? '') == 'manager')) {
      try {
        await db.execute("ALTER TABLE warehouses ADD COLUMN manager TEXT");
      } catch (_) {}
    }
  } catch (_) {
    // در هر صورت برای ایمنی تلاش به ایجاد جدول کن (محافظه‌کارانه)
    try {
      await createWarehousesTable(db);
    } catch (_) {}
  }
}

Future<int> saveWarehouse(Database db, Map<String, dynamic> item) async {
  final Map<String, dynamic> toSave = Map<String, dynamic>.from(item);
  toSave['created_at'] ??= DateTime.now().millisecondsSinceEpoch;
  if (toSave.containsKey('id') && toSave['id'] != null) {
    final id = toSave['id'];
    toSave.remove('id');
    return await db
        .update('warehouses', toSave, where: 'id = ?', whereArgs: [id]);
  } else {
    return await db.insert('warehouses', toSave);
  }
}

Future<List<Map<String, dynamic>>> getWarehouses(Database db) async {
  return await db.query('warehouses', orderBy: 'name ASC');
}

Future<Map<String, dynamic>?> getWarehouseById(Database db, int id) async {
  final rows =
      await db.query('warehouses', where: 'id = ?', whereArgs: [id], limit: 1);
  if (rows.isEmpty) return null;
  return rows.first;
}

Future<int> deleteWarehouse(Database db, int id) async {
  // قبل از حذف، ممکن است بخواهیم اقدامات وابسته انجام دهیم (در آینده)
  return await db.delete('warehouses', where: 'id = ?', whereArgs: [id]);
}
