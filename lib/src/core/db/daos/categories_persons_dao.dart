// lib/src/core/db/daos/categories_persons_dao.dart
// DAO دستهبندیهای اشخاص (ساختار شبیه taxonomy/terms وردپرس)
// فیلدها: id, name, slug, description, parent_id, count, created_at
// متدها: ایجاد جدول، مهاجرت (اگر جدول وجود نداشته باشد آن را ایجاد می‌کند)، ذخیره (insert/update)، خواندن، حذف (انتقال فرزندان به والد 0)
// کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'package:sqflite/sqflite.dart';

Future<void> createPersonsCategoriesTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS persons_categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      slug TEXT NOT NULL,
      description TEXT,
      parent_id INTEGER DEFAULT 0,
      count INTEGER DEFAULT 0,
      created_at INTEGER
    )
  ''');
}

Future<void> migratePersonsCategoriesTable(Database db) async {
  // بررسی وجود جدول در sqlite_master؛ اگر جدول وجود نداشت آن را کامل ایجاد کن
  try {
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='persons_categories'");
    if (tables.isEmpty) {
      // جدول وجود ندارد -> ایجاد می‌کنیم
      await createPersonsCategoriesTable(db);
      return;
    }
  } catch (_) {
    // در صورت هر خطا در query، تلاش محافظه‌کارانه برای ایجاد جدول
    try {
      await createPersonsCategoriesTable(db);
      return;
    } catch (_) {}
  }

  // اگر جدول وجود داشت، بررسی ستون‌ها و افزودن ستون‌های جدید در صورت نیاز
  try {
    final info = await db.rawQuery("PRAGMA table_info(persons_categories)");
    if (!info.any((r) => r['name'] == 'count')) {
      try {
        await db.execute(
            "ALTER TABLE persons_categories ADD COLUMN count INTEGER DEFAULT 0");
      } catch (_) {}
    }
    if (!info.any((r) => r['name'] == 'description')) {
      try {
        await db.execute(
            "ALTER TABLE persons_categories ADD COLUMN description TEXT");
      } catch (_) {}
    }
  } catch (_) {
    // نادیده گرفتن خطاهای مهاجرت برای جلوگیری از crash
  }
}

Future<int> savePersonCategory(Database db, Map<String, dynamic> item) async {
  final Map<String, dynamic> toSave = Map<String, dynamic>.from(item);
  toSave['created_at'] ??= DateTime.now().millisecondsSinceEpoch;
  toSave['parent_id'] = toSave['parent_id'] ?? 0;
  toSave['slug'] =
      (toSave['slug']?.toString() ?? toSave['name']?.toString() ?? '')
          .toLowerCase()
          .replaceAll(' ', '-');
  if (toSave.containsKey('id') && toSave['id'] != null) {
    final id = toSave['id'];
    toSave.remove('id');
    return await db
        .update('persons_categories', toSave, where: 'id = ?', whereArgs: [id]);
  } else {
    return await db.insert('persons_categories', toSave);
  }
}

Future<List<Map<String, dynamic>>> getPersonCategories(Database db) async {
  // بازگرداندن لیست دسته‌ها (ترتیب بر اساس parent سپس نام)
  return await db.query('persons_categories',
      orderBy: 'parent_id ASC, name ASC');
}

Future<int> deletePersonCategory(Database db, int id) async {
  // فرزندها به parent 0 منتقل شوند سپس حذف
  await db.update('persons_categories', {'parent_id': 0},
      where: 'parent_id = ?', whereArgs: [id]);
  return await db
      .delete('persons_categories', where: 'id = ?', whereArgs: [id]);
}
