// lib/src/core/db/daos/persons_dao.dart
// DAO برای persons: ایجاد جدول، مهاجرت و متدهای مرتبط با افراد (CRUD + next account code)
// به‌روزرسانی: افزودن ستون‌های type_* از جمله type_seller و ستون shareholder_percentage
// کامنت فارسی مختصر برای خوانایی

import 'package:sqflite/sqflite.dart';

Future<void> createPersonsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS persons (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      first_name TEXT,
      last_name TEXT,
      display_name TEXT,
      national_id TEXT,
      economic_code TEXT,
      phone TEXT,
      email TEXT,
      address TEXT,
      city TEXT,
      province TEXT,
      country TEXT,
      postal_code TEXT,
      avatar_url TEXT,
      avatar_local_path TEXT,
      birth_date TEXT,
      membership_date TEXT,
      account_code TEXT,
      category_id INTEGER,
      credit_limit REAL DEFAULT 0,
      balance REAL DEFAULT 0,
      notes TEXT,
      created_at INTEGER,
      -- type flags (default 0)
      type_customer INTEGER DEFAULT 0,
      type_supplier INTEGER DEFAULT 0,
      type_employee INTEGER DEFAULT 0,
      type_shareholder INTEGER DEFAULT 0,
      type_seller INTEGER DEFAULT 0,
      shareholder_percentage REAL DEFAULT 0
    )
  ''');
}

// مهاجرت محافظه‌کارانه: اگر ستون‌ها وجود ندارند اضافه می‌شوند
Future<void> migratePersonsTable(Database db) async {
  final info = await db.rawQuery("PRAGMA table_info(persons)");
  // اگر جدول اصلاً وجود ندارد، بساز
  if (info.isEmpty) {
    await createPersonsTable(db);
    return;
  }

  Future<void> maybeAdd(String colDef, String colName) async {
    if (!info.any((r) => (r['name']?.toString() ?? '') == colName)) {
      try {
        await db.execute('ALTER TABLE persons ADD COLUMN $colDef');
      } catch (_) {}
    }
  }

  // ستون‌های پایه
  await maybeAdd('account_code TEXT', 'account_code');
  await maybeAdd('avatar_local_path TEXT', 'avatar_local_path');
  await maybeAdd('category_id INTEGER DEFAULT 0', 'category_id');

  // ستون‌های نوع/پرچم‌ها
  await maybeAdd('type_customer INTEGER DEFAULT 0', 'type_customer');
  await maybeAdd('type_supplier INTEGER DEFAULT 0', 'type_supplier');
  await maybeAdd('type_employee INTEGER DEFAULT 0', 'type_employee');
  await maybeAdd('type_shareholder INTEGER DEFAULT 0', 'type_shareholder');
  await maybeAdd('type_seller INTEGER DEFAULT 0', 'type_seller');
  await maybeAdd(
      'shareholder_percentage REAL DEFAULT 0', 'shareholder_percentage');
}

Future<String> getNextAccountCode(Database db) async {
  try {
    final rows = await db.rawQuery(
        "SELECT MAX(CAST(account_code AS INTEGER)) as m FROM persons");
    final m = rows.isNotEmpty ? rows.first['m'] : null;
    int maxVal = 0;
    if (m is int) {
      maxVal = m;
    } else if (m is String) maxVal = int.tryParse(m) ?? 0;
    final next = (maxVal >= 1001) ? (maxVal + 1) : 1001;
    return next.toString();
  } catch (_) {
    return '1001';
  }
}

Future<int> savePerson(Database db, Map<String, dynamic> item) async {
  final insertItem = Map<String, dynamic>.from(item);
  insertItem['created_at'] ??= DateTime.now().millisecondsSinceEpoch;
  final provided = (insertItem['account_code']?.toString() ?? '').trim();
  if (provided.isEmpty) {
    final next = await getNextAccountCode(db);
    insertItem['account_code'] = next;
  } else {
    insertItem['account_code'] = provided;
  }
  return await db.insert('persons', insertItem);
}

Future<List<Map<String, dynamic>>> getPersons(Database db) async {
  return await db.query('persons', orderBy: 'created_at DESC');
}

Future<Map<String, dynamic>?> getPersonById(Database db, int id) async {
  final rows =
      await db.query('persons', where: 'id = ?', whereArgs: [id], limit: 1);
  if (rows.isEmpty) return null;
  return rows.first;
}

Future<int> deletePerson(Database db, int id) async {
  return await db.delete('persons', where: 'id = ?', whereArgs: [id]);
}
