// lib/src/core/db/daos/license_dao.dart
// DAO برای local_license: ایجاد جدول و متدهای ساده ذخیره/خواندن/حذف

import 'package:sqflite/sqflite.dart';

Future<void> createLicenseTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS local_license (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      license_key TEXT,
      license_token TEXT,
      issued_at INTEGER,
      expires_at INTEGER
    )
  ''');
}

Future<void> migrateLicenseTable(Database db) async {
  // جدول ساده است؛ فعلاً نیازی به مهاجرت نداریم
}

Future<int> saveLocalLicense(Database db, Map<String, dynamic> item) async {
  await db.delete('local_license');
  final insertItem = Map<String, dynamic>.from(item);
  insertItem['issued_at'] ??= DateTime.now().millisecondsSinceEpoch;
  return await db.insert('local_license', insertItem);
}

Future<Map<String, dynamic>?> getLocalLicense(Database db) async {
  final rows = await db.query('local_license', limit: 1);
  if (rows.isEmpty) return null;
  return rows.first;
}

Future<int> deleteLocalLicense(Database db) async {
  return await db.delete('local_license');
}
