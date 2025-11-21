// lib/src/core/db/db_migrations.dart
// مجموعهٔ مهاجرت‌ها و helperهای schema دیتابیس که جدا در یک فایل نگهداری شده‌اند.
// هدف: تمام ALTER / PRAGMA / CREATE TABLE های محافظه‌کارانه که ممکن است در نسخه‌های مختلف دیتابیس غایب باشند
// در اینجا متمرکز شده‌اند تا AppDatabase فقط آنها را import و اجرا کند.
// کامنت فارسی مختصر برای هر فانکشن قرار دارد.

import 'package:sqflite/sqflite.dart';

/// مهاجرت محافظه‌کارانهٔ جدول sales: اضافه کردن ستون‌های مورد نیاز اگر وجود نداشتند.
Future<void> migrateSalesSchema(Database db) async {
  try {
    final info = await db.rawQuery("PRAGMA table_info('sales')");
    final existingCols = <String>{};
    for (final r in info) {
      final name = (r['name'] ?? r['column_name'])?.toString();
      if (name != null) existingCols.add(name.toLowerCase());
    }

    final needed = <String, String>{
      'title': 'TEXT',
      'subtotal': 'REAL',
      'discount': 'REAL',
      'tax': 'REAL',
      'extra_charges': 'REAL',
      'notes': 'TEXT',
      'created_at': 'INTEGER',
    };

    for (final entry in needed.entries) {
      final col = entry.key;
      final def = entry.value;
      if (!existingCols.contains(col.toLowerCase())) {
        try {
          await db.execute("ALTER TABLE sales ADD COLUMN $col $def");
        } catch (_) {
          // ALTER ممکن است در بعضی وضعیت‌ها خطا دهد؛ به‌صورت محافظه‌کارانه نادیده می‌گیریم
        }
      }
    }
  } catch (_) {
    // نادیده گرفتن خطا تا init متوقف نشود
  }
}

/// مهاجرت محافظه‌کارانهٔ جدول sale_lines: اضافه کردن ستون‌هایی که UI/DAO جدید انتظار دارند.
/// ستون‌های رایج که ممکن است غایب باشند:
/// - name TEXT           (عنوان/نام قلم در خط فاکتور)
/// - tax_percent REAL
/// - is_service INTEGER DEFAULT 0
/// - note TEXT
/// - purchase_price REAL
Future<void> migrateSaleLinesSchema(Database db) async {
  try {
    final info = await db.rawQuery("PRAGMA table_info('sale_lines')");
    final existingCols = <String>{};
    for (final r in info) {
      final name = (r['name'] ?? r['column_name'])?.toString();
      if (name != null) existingCols.add(name.toLowerCase());
    }

    final needed = <String, String>{
      'name': 'TEXT',
      'tax_percent': 'REAL',
      'is_service': 'INTEGER',
      'note': 'TEXT',
      'purchase_price': 'REAL',
    };

    for (final entry in needed.entries) {
      final col = entry.key;
      final def = entry.value;
      if (!existingCols.contains(col.toLowerCase())) {
        try {
          await db.execute("ALTER TABLE sale_lines ADD COLUMN $col $def");
        } catch (_) {
          // ignore errors (sqlite limitations etc) — migration should be best-effort
        }
      }
    }
  } catch (_) {
    // ignore
  }
}

/// اطمینان از وجود جداول کمکی جدید که ممکن است در نسخه‌های قدیمی نبودند.
/// این متد CREATE TABLE IF NOT EXISTS را اجرا میکند.
Future<void> ensureAuxTables(Database db) async {
  try {
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

    // product_categories used by some DAOs
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        slug TEXT,
        parent_id INTEGER,
        notes TEXT,
        updated_at INTEGER,
        created_at INTEGER
      )
    ''');
  } catch (_) {
    // fail silently — best-effort
  }
}

/// متد جامع که همهٔ مهاجرت‌های مرتبط با sales و sale_lines و جداول کمکی را اجرا میکند.
/// میتوان مستقیماً از AppDatabase فراخوانی کرد تا یک نقطهٔ مرکزی برای مهاجرت‌ها وجود داشته باشد.
Future<void> runSalesRelatedMigrations(Database db) async {
  await Future.wait([
    migrateSalesSchema(db),
    migrateSaleLinesSchema(db),
    ensureAuxTables(db),
  ]);
}
