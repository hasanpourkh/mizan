// lib/src/core/db/daos/persons_meta_dao.dart
// DAO جدا برای منطق meta/نوع اشخاص و مدیریت درصد سهام.
// - مهاجرت محافظه‌کارانه: اگر ستون‌های مربوطه در جدول persons وجود ندارند، اضافه می‌شوند.
// - محاسبه مجموع درصد سهامداران و بررسی امکان اضافه‌کردن سهامدار جدید.
// - به‌روزرسانی فیلدهای نوع شخص برای یک رکورد person (پس از درج اصلی در جدول persons).
//
// کامنت فارسی مختصر برای فهم سریع هر متد.

import 'package:sqflite/sqflite.dart';

Future<void> migratePersonsMetaTable(Database db) async {
  // بررسی وجود ستونها در جدول persons؛ در صورت نبود، آنها را اضافه میکنیم.
  try {
    final info = await db.rawQuery("PRAGMA table_info(persons)");
    final names = info.map((r) => r['name']?.toString() ?? '').toList();

    if (!names.contains('type_customer')) {
      try {
        await db.execute(
            "ALTER TABLE persons ADD COLUMN type_customer INTEGER DEFAULT 0");
      } catch (_) {}
    }
    if (!names.contains('type_supplier')) {
      try {
        await db.execute(
            "ALTER TABLE persons ADD COLUMN type_supplier INTEGER DEFAULT 0");
      } catch (_) {}
    }
    if (!names.contains('type_shareholder')) {
      try {
        await db.execute(
            "ALTER TABLE persons ADD COLUMN type_shareholder INTEGER DEFAULT 0");
      } catch (_) {}
    }
    if (!names.contains('type_employee')) {
      try {
        await db.execute(
            "ALTER TABLE persons ADD COLUMN type_employee INTEGER DEFAULT 0");
      } catch (_) {}
    }
    if (!names.contains('shareholder_percentage')) {
      try {
        await db.execute(
            "ALTER TABLE persons ADD COLUMN shareholder_percentage REAL DEFAULT 0");
      } catch (_) {}
    }
  } catch (_) {
    // اگر PRAGMA به هر دلیلی خطا داد تلاش محافظه‌کارانه برای افزودن ستون‌ها
    try {
      await db.execute(
          "ALTER TABLE persons ADD COLUMN type_customer INTEGER DEFAULT 0");
    } catch (_) {}
    try {
      await db.execute(
          "ALTER TABLE persons ADD COLUMN type_supplier INTEGER DEFAULT 0");
    } catch (_) {}
    try {
      await db.execute(
          "ALTER TABLE persons ADD COLUMN type_shareholder INTEGER DEFAULT 0");
    } catch (_) {}
    try {
      await db.execute(
          "ALTER TABLE persons ADD COLUMN type_employee INTEGER DEFAULT 0");
    } catch (_) {}
    try {
      await db.execute(
          "ALTER TABLE persons ADD COLUMN shareholder_percentage REAL DEFAULT 0");
    } catch (_) {}
  }
}

// محاسبه مجموع درصد سهامداران (اعداد ممکن است null یا رشته باشند)
Future<double> getTotalSharePercentage(Database db) async {
  try {
    final rows = await db.rawQuery(
        "SELECT SUM(COALESCE(shareholder_percentage,0)) AS s FROM persons WHERE COALESCE(type_shareholder,0)=1");
    if (rows.isNotEmpty) {
      final s = rows.first['s'];
      if (s is num) return s.toDouble();
      if (s is String) return double.tryParse(s) ?? 0.0;
    }
    return 0.0;
  } catch (_) {
    return 0.0;
  }
}

// بررسی اینکه آیا با افزودن درصد جدید (additional) مجموع از 100 بیشتر میشود یا نه
Future<bool> canAddShareholder(Database db, double additional) async {
  final total = await getTotalSharePercentage(db);
  return (total + additional) <= 100.0;
}

// به‌روزرسانی فیلدهای نوع برای person با id مشخص
// types keys: 'type_customer', 'type_supplier', 'type_shareholder', 'type_employee', 'shareholder_percentage'
Future<int> updatePersonTypes(
    Database db, int personId, Map<String, dynamic> types) async {
  final Map<String, dynamic> toUpdate = {};
  if (types.containsKey('type_customer')) {
    toUpdate['type_customer'] =
        (types['type_customer'] == true || types['type_customer'] == 1) ? 1 : 0;
  }
  if (types.containsKey('type_supplier')) {
    toUpdate['type_supplier'] =
        (types['type_supplier'] == true || types['type_supplier'] == 1) ? 1 : 0;
  }
  if (types.containsKey('type_shareholder')) {
    toUpdate['type_shareholder'] =
        (types['type_shareholder'] == true || types['type_shareholder'] == 1)
            ? 1
            : 0;
  }
  if (types.containsKey('type_employee')) {
    toUpdate['type_employee'] =
        (types['type_employee'] == true || types['type_employee'] == 1) ? 1 : 0;
  }
  if (types.containsKey('shareholder_percentage')) {
    final p = types['shareholder_percentage'];
    double val = 0.0;
    if (p is num) {
      val = p.toDouble();
    } else if (p is String) val = double.tryParse(p) ?? 0.0;
    toUpdate['shareholder_percentage'] = val;
  }

  if (toUpdate.isEmpty) return 0;
  try {
    return await db
        .update('persons', toUpdate, where: 'id = ?', whereArgs: [personId]);
  } catch (e) {
    return 0;
  }
}

// helper: اگر لازم بود بتوانیم درصد یک شخص را بخوانیم
Future<double> getPersonSharePercentage(Database db, int personId) async {
  try {
    final rows = await db.query('persons',
        columns: ['shareholder_percentage', 'type_shareholder'],
        where: 'id = ?',
        whereArgs: [personId],
        limit: 1);
    if (rows.isEmpty) return 0.0;
    final r = rows.first;
    final enabled = (r['type_shareholder'] is int)
        ? (r['type_shareholder'] as int) == 1
        : (r['type_shareholder']?.toString() == '1');
    if (!enabled) return 0.0;
    final p = r['shareholder_percentage'];
    if (p is num) return p.toDouble();
    if (p is String) return double.tryParse(p) ?? 0.0;
    return 0.0;
  } catch (_) {
    return 0.0;
  }
}
