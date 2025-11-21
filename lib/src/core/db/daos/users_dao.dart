// lib/src/core/db/daos/users_dao.dart
// DAO برای جدول users (حساب‌های کاربری فروشندگان/کارمندان)
// - شامل ایجاد جدول، مهاجرت محافظه‌کارانه و CRUD ساده
// - پسورد به صورت hash و salt ذخیره میشود (hash از سمت UI تولید میشود)
// کامنت‌های فارسی مختصر برای هر تابع قرار دارد.

import 'package:sqflite/sqflite.dart';

Future<void> createUsersTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      password_salt TEXT NOT NULL,
      role TEXT DEFAULT 'seller',
      person_id INTEGER,
      created_at INTEGER,
      active INTEGER DEFAULT 1
    )
  ''');
}

Future<void> migrateUsersTable(Database db) async {
  // محافظه‌کارانه بررسی میکنیم و در صورت نبود جدول آن را ایجاد میکنیم
  final info = await db.rawQuery("PRAGMA table_info(users)");
  if (info.isEmpty) {
    await createUsersTable(db);
    return;
  }
  // اگر ستون جدید نیاز بود در اینجا اضافه کنید (مثال محافظه‌کارانه)
  final names = info.map((r) => r['name']?.toString() ?? '').toList();
  if (!names.contains('active')) {
    try {
      await db.execute('ALTER TABLE users ADD COLUMN active INTEGER DEFAULT 1');
    } catch (_) {}
  }
}

Future<int> saveUser(Database db, Map<String, dynamic> item) async {
  // اگر id موجود باشد update کن، در غیر اینصورت insert کن
  final now = DateTime.now().millisecondsSinceEpoch;
  final copy = Map<String, dynamic>.from(item);
  copy['created_at'] ??= now;

  if (copy.containsKey('id') && copy['id'] != null) {
    final id = copy['id'];
    // حذف id از map قبل از update
    copy.remove('id');
    return await db.update('users', copy, where: 'id = ?', whereArgs: [id]);
  } else {
    return await db.insert('users', copy);
  }
}

Future<List<Map<String, dynamic>>> getUsers(Database db,
    {int limit = 100, int offset = 0}) async {
  return await db.query('users',
      orderBy: 'created_at DESC', limit: limit, offset: offset);
}

Future<Map<String, dynamic>?> getUserById(Database db, int id) async {
  final rows =
      await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
  if (rows.isEmpty) return null;
  return rows.first;
}

Future<Map<String, dynamic>?> getUserByUsername(
    Database db, String username) async {
  final rows = await db.query('users',
      where: 'username = ?', whereArgs: [username], limit: 1);
  if (rows.isEmpty) return null;
  return rows.first;
}

Future<int> deleteUser(Database db, int id) async {
  return await db.delete('users', where: 'id = ?', whereArgs: [id]);
}
