// lib/src/core/db/daos/categories_dao.dart
// DAO برای categories: مدیریت درختی ساده (parent_id) — ایجاد جدول و متدهای CRUD

import 'package:sqflite/sqflite.dart';

Future<void> createCategoriesTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      slug TEXT,
      parent_id INTEGER DEFAULT 0,
      created_at INTEGER
    )
  ''');
}

Future<void> migrateCategoriesTable(Database db) async {
  // فعلاً نیاز به مهاجرت خاصی نیست
}

Future<int> saveCategory(Database db, Map<String, dynamic> item) async {
  final Map<String, dynamic> toSave = Map<String, dynamic>.from(item);
  toSave['created_at'] ??= DateTime.now().millisecondsSinceEpoch;
  if (toSave.containsKey('id') && toSave['id'] != null) {
    final id = toSave['id'];
    toSave.remove('id');
    return await db
        .update('categories', toSave, where: 'id = ?', whereArgs: [id]);
  } else {
    return await db.insert('categories', toSave);
  }
}

Future<List<Map<String, dynamic>>> getCategories(Database db) async {
  return await db.query('categories', orderBy: 'parent_id ASC, name ASC');
}

Future<int> deleteCategory(Database db, int id) async {
  await db.update('categories', {'parent_id': 0},
      where: 'parent_id = ?', whereArgs: [id]);
  return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
}
