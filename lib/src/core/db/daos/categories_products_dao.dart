// lib/src/core/db/daos/categories_products_dao.dart
// DAO مربوط به دسته‌بندی محصولات (product categories).
// - توابع: ایجاد جدول، مهاجرت محافظه‌کارانه، لیست خواندن، درج/ویرایش، حذف.
// - کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'package:sqflite/sqflite.dart';

/// ایجاد جدول product_categories در زمان ساخت دیتابیس
Future<void> createProductsCategoriesTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS product_categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      slug TEXT,
      parent_id INTEGER DEFAULT 0,
      notes TEXT,
      created_at INTEGER,
      updated_at INTEGER
    )
  ''');
}

/// مهاجرت محافظه‌کارانه: اگر ستون جدیدی لازم باشد اضافه کند (سکوت در صورت خطا)
Future<void> migrateProductsCategoriesTable(Database db) async {
  try {
    final info = await db.rawQuery("PRAGMA table_info(product_categories)");
    final names = info.map((r) => r['name']?.toString() ?? '').toList();

    if (!names.contains('slug')) {
      try {
        await db.execute('ALTER TABLE product_categories ADD COLUMN slug TEXT');
      } catch (_) {}
    }
    if (!names.contains('parent_id')) {
      try {
        await db.execute(
            'ALTER TABLE product_categories ADD COLUMN parent_id INTEGER DEFAULT 0');
      } catch (_) {}
    }
    if (!names.contains('notes')) {
      try {
        await db
            .execute('ALTER TABLE product_categories ADD COLUMN notes TEXT');
      } catch (_) {}
    }
    if (!names.contains('created_at')) {
      try {
        await db.execute(
            'ALTER TABLE product_categories ADD COLUMN created_at INTEGER');
      } catch (_) {}
    }
    if (!names.contains('updated_at')) {
      try {
        await db.execute(
            'ALTER TABLE product_categories ADD COLUMN updated_at INTEGER');
      } catch (_) {}
    }
  } catch (_) {
    // اگر PRAGMA یا ALTER خطا داد، نادیده گرفته می‌شود تا مهاجرت کلی متوقف نگردد.
  }
}

/// دریافت همهٔ دسته‌ها (مرتب بر اساس نام)
Future<List<Map<String, dynamic>>> getProductCategories(Database db) async {
  try {
    final rows = await db.query('product_categories',
        orderBy: 'name COLLATE NOCASE ASC');
    return rows;
  } catch (e) {
    return <Map<String, dynamic>>[];
  }
}

/// ذخیرهٔ دسته (درج یا بروزرسانی بر اساس وجود id)
/// ورودی: Map<String,dynamic> item (میتواند {id, name, slug, parent_id, notes})
/// خروجی: id رکورد ذخیره‌شده (int)
Future<int> saveProductCategory(Database db, Map<String, dynamic> item) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final m = <String, dynamic>{
    'name': item['name']?.toString() ?? '',
    'slug': item['slug']?.toString() ?? '',
    'parent_id': (item['parent_id'] is int)
        ? item['parent_id'] as int
        : int.tryParse(item['parent_id']?.toString() ?? '') ?? 0,
    'notes': item['notes']?.toString() ?? '',
    'updated_at': now,
  };

  try {
    if (item.containsKey('id') &&
        item['id'] != null &&
        (item['id'] is int ||
            int.tryParse(item['id']?.toString() ?? '') != null)) {
      final id = (item['id'] is int)
          ? item['id'] as int
          : int.parse(item['id'].toString());
      // update
      await db
          .update('product_categories', m, where: 'id = ?', whereArgs: [id]);
      return id;
    } else {
      // insert: اضافه کردن created_at
      m['created_at'] = now;
      final id = await db.insert('product_categories', m);
      return id;
    }
  } catch (e) {
    rethrow;
  }
}

/// حذف دسته بر اساس id
Future<int> deleteProductCategory(Database db, int id) async {
  try {
    return await db
        .delete('product_categories', where: 'id = ?', whereArgs: [id]);
  } catch (e) {
    return 0;
  }
}
