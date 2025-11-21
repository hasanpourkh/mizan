// lib/src/core/db/mizan_db/migrations.dart
// توابع کمکی مهاجرت/ایجاد جداول کوچک و ثابت.
// این فایل توسط mizan_db و سرویسها استفاده میشود.
// کامنت فارسی مختصر برای هر قسمت.

import 'package:sqflite/sqflite.dart';

Future<void> ensureProfitAndReturnsTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS profit_shares (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sale_id INTEGER,
      sale_line_id INTEGER,
      person_id INTEGER,
      percent REAL,
      amount REAL,
      is_adjustment INTEGER DEFAULT 0,
      note TEXT,
      created_at INTEGER
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS sale_returns (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sale_id INTEGER,
      created_at INTEGER,
      actor TEXT,
      notes TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS sale_return_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      return_id INTEGER,
      sale_line_id INTEGER,
      product_id INTEGER,
      quantity REAL,
      unit_price REAL,
      purchase_price REAL,
      line_total REAL
    )
  ''');
}
