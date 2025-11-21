// lib/src/core/db/daos/services_dao.dart
// DAO مربوط به جدول خدمات (services).
// - جدول services شامل: id, name, code, price, unit, category_id, description, active, created_at, updated_at
// - متدها: createServicesTable, migrateServicesTable, saveService, getServices, getServiceById, deleteService
// - کامنت فارسی مختصر برای هر بخش قرار گرفته است.

import 'package:sqflite/sqflite.dart';

Future<void> createServicesTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS services (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      code TEXT,
      price REAL DEFAULT 0,
      unit TEXT,
      category_id INTEGER,
      description TEXT,
      active INTEGER DEFAULT 1,
      created_at INTEGER,
      updated_at INTEGER
    )
  ''');
}

Future<void> migrateServicesTable(Database db) async {
  try {
    final info = await db.rawQuery("PRAGMA table_info(services)");
    if (info.isEmpty) {
      await createServicesTable(db);
      return;
    }

    Future<void> _maybeAdd(String colDef, String colName) async {
      if (!info.any((r) => (r['name']?.toString() ?? '') == colName)) {
        try {
          await db.execute('ALTER TABLE services ADD COLUMN $colDef');
        } catch (_) {}
      }
    }

    await _maybeAdd('code TEXT', 'code');
    await _maybeAdd('price REAL DEFAULT 0', 'price');
    await _maybeAdd('unit TEXT', 'unit');
    await _maybeAdd('category_id INTEGER', 'category_id');
    await _maybeAdd('description TEXT', 'description');
    await _maybeAdd('active INTEGER DEFAULT 1', 'active');
    await _maybeAdd('created_at INTEGER', 'created_at');
    await _maybeAdd('updated_at INTEGER', 'updated_at');
  } catch (_) {
    try {
      await createServicesTable(db);
    } catch (_) {}
  }
}

/// ذخیرهٔ خدمت (درج یا بروزرسانی)
/// item: Map با کلیدهایی مانند {id?, name, code?, price?, unit?, category_id?, description?, active?}
Future<int> saveService(Database db, Map<String, dynamic> item) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final m = <String, dynamic>{
    'name': item['name']?.toString() ?? '',
    'code': item['code']?.toString() ?? '',
    'price': (item['price'] is num)
        ? (item['price'] as num).toDouble()
        : double.tryParse(item['price']?.toString() ?? '') ?? 0.0,
    'unit': item['unit']?.toString() ?? '',
    'category_id': (item['category_id'] is int)
        ? item['category_id'] as int
        : (item['category_id'] != null
            ? int.tryParse(item['category_id'].toString())
            : null),
    'description': item['description']?.toString() ?? '',
    'active': (item['active'] is int)
        ? item['active']
        : ((item['active'] is bool)
            ? ((item['active'] as bool) ? 1 : 0)
            : (item['active']?.toString() == '1' ? 1 : 1)),
    'updated_at': now,
  };

  try {
    if (item.containsKey('id') && item['id'] != null) {
      final id = (item['id'] is int)
          ? item['id'] as int
          : int.tryParse(item['id'].toString()) ?? 0;
      if (id > 0) {
        await db.update('services', m, where: 'id = ?', whereArgs: [id]);
        return id;
      }
    }
    m['created_at'] = now;
    final id = await db.insert('services', m);
    return id;
  } catch (e) {
    rethrow;
  }
}

/// دریافت لیست خدمات (قابل فیلتر با q روی نام یا code)
Future<List<Map<String, dynamic>>> getServices(Database db, {String? q}) async {
  try {
    if (q != null && q.trim().isNotEmpty) {
      final s = '%${q.trim()}%';
      return await db.query('services',
          where: 'name LIKE ? OR code LIKE ?',
          whereArgs: [s, s],
          orderBy: 'name COLLATE NOCASE ASC');
    }
    return await db.query('services', orderBy: 'name COLLATE NOCASE ASC');
  } catch (e) {
    return <Map<String, dynamic>>[];
  }
}

/// دریافت یک خدمت بر اساس id
Future<Map<String, dynamic>?> getServiceById(Database db, int id) async {
  final rows =
      await db.query('services', where: 'id = ?', whereArgs: [id], limit: 1);
  if (rows.isEmpty) return null;
  return rows.first;
}

/// حذف یک خدمت
Future<int> deleteService(Database db, int id) async {
  try {
    return await db.delete('services', where: 'id = ?', whereArgs: [id]);
  } catch (e) {
    return 0;
  }
}
