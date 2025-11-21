// lib/src/core/db/daos/business_dao.dart
// DAO مربوط به business_profile — ایجاد جدول، مهاجرت محافظه‌کارانه و توابع خواندن/نوشتن
// - این فایل مطمئن می‌شود تمام فیلدهای مربوط به تنظیمات چاپ/پروفایل کسب‌وکار
//   (مثل business_name, address, phone, website, logo_path, default_paper,
//    social_links (JSON string), print_ad_text, storage_path, created_at, updated_at)
//   در جدول وجود داشته باشند و به‌صورت ایمن خوانده/ذخیره شوند.
// - saveBusinessProfile اکنون یک upsert محافظه‌کارانه انجام می‌دهد:
//   اگر رکوردی وجود داشته باشد آن را آپدیت می‌کند، در غیر این صورت درج می‌کند.
// - social_links اگر به‌صورت لیست/مپ ارسال شود به JSON تبدیل می‌شود تا با sqflite سازگار باشد.
// - همهٔ ورودی‌ها قبل از ارسال به sqlite به نوع‌های پشتیبانی‌شده تبدیل می‌شوند.
// کامنت‌های فارسی مختصر در هر بخش قرار گرفته‌اند.

import 'dart:convert';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';

/// ایجاد جدول business_profile (در onCreate)
Future<void> createBusinessTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS business_profile (
      id INTEGER PRIMARY KEY,
      business_name TEXT,
      address TEXT,
      phone TEXT,
      website TEXT,
      logo_path TEXT,
      default_paper TEXT,
      social_links TEXT,
      print_ad_text TEXT,
      storage_path TEXT,
      created_at INTEGER,
      updated_at INTEGER
    )
  ''');
}

/// مهاجرت محافظه‌کارانه: اگر ستون جدیدی نیاز است اضافه کن
Future<void> migrateBusinessTable(Database db) async {
  try {
    final info = await db.rawQuery("PRAGMA table_info(business_profile)");
    if (info.isEmpty) {
      // جدول وجود ندارد، ایجاد کن
      await createBusinessTable(db);
      return;
    }

    final existing = info
        .map((r) => (r['name'] as String?)?.toLowerCase())
        .whereType<String>()
        .toSet();

    Future<void> maybeAdd(String colDef, String colName) async {
      if (!existing.contains(colName.toLowerCase())) {
        try {
          await db.execute('ALTER TABLE business_profile ADD COLUMN $colDef');
        } catch (_) {}
      }
    }

    await maybeAdd('logo_path TEXT', 'logo_path');
    await maybeAdd('default_paper TEXT', 'default_paper');
    await maybeAdd('social_links TEXT', 'social_links');
    await maybeAdd('print_ad_text TEXT', 'print_ad_text');
    await maybeAdd('storage_path TEXT', 'storage_path');
    await maybeAdd('created_at INTEGER', 'created_at');
    await maybeAdd('updated_at INTEGER', 'updated_at');
  } catch (e) {
    // مهاجرت خطا داد — نادیده بگیریم تا اپ کرش نکند
  }
}

/// خواندن پروفایل کسب‌وکار (اولین رکورد)
Future<Map<String, dynamic>?> getBusinessProfile(Database db) async {
  final rows = await db.query('business_profile', limit: 1);
  if (rows.isEmpty) return null;
  final r = Map<String, dynamic>.from(rows.first);

  // اگر social_links رشتهٔ JSON است و قابل decode است، برگردان
  final sl = r['social_links'];
  if (sl is String && sl.isNotEmpty) {
    try {
      final dec = json.decode(sl);
      r['social_links'] = dec;
    } catch (_) {
      // اگر decode نشد، همان رشته نگه داشته می‌شود
    }
  }

  return r;
}

/// برگرداندن وجود پروفایل (true/false)
Future<bool> hasBusinessProfile(Database db) async {
  final c = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(1) as c FROM business_profile'));
  return (c ?? 0) > 0;
}

/// حذف پروفایل (اگر بخواهیم پاک کنیم)
Future<int> deleteBusinessProfile(Database db) async {
  return await db.delete('business_profile');
}

/// ذخیره یا بروزرسانی پروفایل کسب‌وکار
/// ورودی: Map<String,dynamic> item — ممکن است شامل کلیدهایی مثل
/// business_name, address, phone, website, logo_path, default_paper,
/// social_links (List/Map یا JSON string), print_ad_text, storage_path, created_at, updated_at
Future<int> saveBusinessProfile(Database db, Map<String, dynamic> item) async {
  // نرمال‌سازی فیلدها برای sqlite (sqflite فقط num, String, Uint8List پشتیبانی می‌کند)
  final data = <String, dynamic>{};

  void putIfPresent(String key) {
    if (item.containsKey(key)) {
      final v = item[key];
      if (v == null) return;
      if (v is String || v is num || v is Uint8List) {
        data[key] = v;
      } else {
        // اگر مقدار پیچیده است (Map/List) آن را به JSON تبدیل کن
        try {
          data[key] = json.encode(v);
        } catch (_) {
          data[key] = v.toString();
        }
      }
    }
  }

  putIfPresent('business_name');
  putIfPresent('address');
  putIfPresent('phone');
  putIfPresent('website');
  putIfPresent('logo_path'); // مسیر یا نام فایل لوگو
  putIfPresent('default_paper');
  // social_links را اگر لیست/مپ است به JSON تبدیل می‌کنیم
  if (item.containsKey('social_links')) {
    final sl = item['social_links'];
    if (sl == null) {
      // نادیده بگیر
    } else if (sl is String) {
      data['social_links'] = sl;
    } else {
      // تلاش برای encode
      try {
        data['social_links'] = json.encode(sl);
      } catch (_) {
        data['social_links'] = sl.toString();
      }
    }
  }
  putIfPresent('print_ad_text');
  putIfPresent('storage_path');

  // updated_at را همیشه بر اساس ورودی یا زمان فعلی تنظیم کن
  if (item.containsKey('updated_at')) {
    final v = item['updated_at'];
    if (v is int) {
      data['updated_at'] = v;
    } else {
      final parsed = int.tryParse(v?.toString() ?? '');
      if (parsed != null) data['updated_at'] = parsed;
    }
  } else {
    data['updated_at'] = DateTime.now().millisecondsSinceEpoch;
  }

  // اگر created_at داده شده بود آن را هم نگه دار
  if (item.containsKey('created_at')) {
    final v = item['created_at'];
    if (v is int) {
      data['created_at'] = v;
    } else {
      final parsed = int.tryParse(v?.toString() ?? '');
      if (parsed != null) data['created_at'] = parsed;
    }
  }

  // اگر قبلاً یک رکورد وجود دارد، update کن؛ در غیر این صورت insert کن.
  final exists = await hasBusinessProfile(db);
  if (exists) {
    try {
      // update همهٔ فیلدهای موجود
      final res = await db
          .update('business_profile', data, where: 'id = ?', whereArgs: [1]);
      // اگر هیچ ردیفی آپدیت نشد (به هر دلیلی)، تلاش برای insert انجام بده
      if (res == 0) {
        // تعیین id=1 برای هماهنگی (single-row profile)
        data['id'] = 1;
        try {
          await db.insert('business_profile', data,
              conflictAlgorithm: ConflictAlgorithm.replace);
          return 1;
        } catch (_) {
          // fallback: اجرای update بدون where (احتمالاً رکورد وجود دارد)
          await db.update('business_profile', data);
          return 1;
        }
      }
      return 1;
    } catch (e) {
      // اگر خطای ستون missing داده شد، تلاش کن ستون‌ها را اضافه کنی (اما این کار در migrate انجام میشود)
      rethrow;
    }
  } else {
    // insert جدید با id ثابت 1 (پروفایل تک)
    try {
      // اگر created_at موجود نیست اضافه کن
      if (!data.containsKey('created_at')) {
        data['created_at'] = DateTime.now().millisecondsSinceEpoch;
      }
      data['id'] = 1;
      await db.insert('business_profile', data,
          conflictAlgorithm: ConflictAlgorithm.replace);
      return 1;
    } catch (e) {
      rethrow;
    }
  }
}
