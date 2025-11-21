// lib/src/core/db/daos/requests_dao.dart
// DAO برای requests: ایجاد جدول، مهاجرت و متدهای CRUD ساده
// کامنت فارسی مختصر برای هر متد.

import 'package:sqflite/sqflite.dart';

Future<void> createRequestsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT,
      first_name TEXT,
      last_name TEXT,
      username TEXT,
      phone TEXT,
      store_name TEXT,
      device_hash TEXT,
      status TEXT DEFAULT 'pending',
      created_at INTEGER
    )
  ''');
}

Future<void> migrateRequestsTable(Database db) async {
  final info = await db.rawQuery("PRAGMA table_info(requests)");
  if (!info.any((r) => r['name'] == 'status')) {
    try {
      await db.execute(
          "ALTER TABLE requests ADD COLUMN status TEXT DEFAULT 'pending'");
    } catch (_) {}
  }
}

Future<int> insertPendingRequest(Database db, Map<String, dynamic> item) async {
  final insertItem = Map<String, dynamic>.from(item);
  insertItem['created_at'] ??= DateTime.now().millisecondsSinceEpoch;
  insertItem['status'] ??= 'pending';
  return await db.insert('requests', insertItem);
}

Future<List<Map<String, dynamic>>> getRequests(Database db,
    {String? status}) async {
  if (status != null && status.isNotEmpty) {
    return await db.query('requests',
        where: 'status = ?', whereArgs: [status], orderBy: 'created_at DESC');
  }
  return await db.query('requests', orderBy: 'created_at DESC');
}

Future<Map<String, dynamic>?> getRequestByEmailOrDevice(Database db,
    {String? email, String? deviceHash}) async {
  String where = '';
  final args = <dynamic>[];
  if (deviceHash != null && deviceHash.isNotEmpty) {
    where = 'device_hash = ?';
    args.add(deviceHash);
  } else if (email != null && email.isNotEmpty) {
    where = 'email = ?';
    args.add(email);
  } else {
    return null;
  }
  final rows =
      await db.query('requests', where: where, whereArgs: args, limit: 1);
  if (rows.isEmpty) return null;
  return rows.first;
}

Future<int> updateRequestStatusByEmailOrDevice(Database db,
    {String? email, String? deviceHash, required String status}) async {
  String where = '';
  final args = <dynamic>[];
  if (deviceHash != null && deviceHash.isNotEmpty) {
    where = 'device_hash = ?';
    args.add(deviceHash);
  }
  if (email != null && email.isNotEmpty) {
    if (where.isNotEmpty) where += ' OR ';
    where += 'email = ?';
    args.add(email);
  }
  if (where.isEmpty) return 0;
  return await db.update('requests', {'status': status},
      where: where, whereArgs: args);
}

Future<int> deleteRequestsByEmailOrDevice(Database db,
    {String? email, String? deviceHash}) async {
  String where = '';
  final args = <dynamic>[];
  if (deviceHash != null && deviceHash.isNotEmpty) {
    where = 'device_hash = ?';
    args.add(deviceHash);
  }
  if (email != null && email.isNotEmpty) {
    if (where.isNotEmpty) where += ' OR ';
    where += 'email = ?';
    args.add(email);
  }
  if (where.isEmpty) return 0;
  return await db.delete('requests', where: where, whereArgs: args);
}
