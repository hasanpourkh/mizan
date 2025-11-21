// lib/src/core/db/database_init.dart
// مدیریت مقداردهی/باز کردن دیتابیس sqlite.
// اصلاح مهم: دیگر از candidateهای خودکار (مثل Documents) به‌عنوان fallback استفاده نمی‌شود.
// اگر ConfigManager مسیر دیتابیس را نداده باشد، init خطا می‌دهد و از caller
// خواسته می‌شود که مسیر را صریحاً تنظیم کند (مثلاً از طریق Settings یا اسکریپت bin/db_migrate.dart).
//
// مزیت: دیتابیس تنها در مسیری که کاربر صریحاً انتخاب کرده ذخیره/ایجاد می‌شود.
// کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../config/config_manager.dart';
import 'database_schema.dart' as schema;

const int _DB_VERSION = 8;

Database? _internalDb;
String? _internalDbFilePath;
Completer<void>? _initCompleter; // جلوگیری از race condition

/// getter امن: اگر init نشده باشد تلاش به init خودکار نمیکند (تصمیم: باید init صریح انجام شود)
/// اما برای انعطاف‌پذیری اگر init قبلاً در حال اجرا باشد منتظر آن می‌ماند.
Future<Database> get db async {
  if (_internalDb != null) return _internalDb!;
  if (_initCompleter != null) {
    await _initCompleter!.future;
    if (_internalDb != null) return _internalDb!;
  }
  // اگر تا اینجا دیتابیس مقداردهی نشده، ارور واضح میدهیم تا caller بداند باید مسیر را ست کند.
  throw Exception(
      'دیتابیس مقداردهی نشده است. مسیر دیتابیس تنظیم نشده یا init اجرا نشده است. لطفاً مسیر فایل .db را در تنظیمات برنامه مشخص کن یا از اسکریپت bin/db_migrate.dart استفاده کن.');
}

/// مقداردهی اولیه دیتابیس بر اساس مسیر صریحی که در ConfigManager ذخیره شده است.
/// رفتار: صرفاً از ConfigManager.getDbFilePath() استفاده میکند.
/// - اگر مسیر تنظیم نشده یا خالی باشد، Exception پرتاب می‌کند (هیچ fallback ایجاد نمیشود).
/// - اگر مسیر تنظیم شده باشد اما باز کردن/ساخت fail شود، Exception با پیام واضح بازمیگردد.
Future<void> init() async {
  if (_internalDb != null) return;
  if (_initCompleter != null) return _initCompleter!.future;

  _initCompleter = Completer<void>();
  try {
    // خواندن مسیر صریح از ConfigManager
    String? cfgPath;
    try {
      cfgPath = await ConfigManager.getDbFilePath();
    } catch (e) {
      cfgPath = null;
    }

    if (cfgPath == null || cfgPath.trim().isEmpty) {
      throw Exception(
          'مسیر دیتابیس پیکربندی نشده است. لطفاً مسیر فایل .db را در تنظیمات برنامه مشخص کنید یا از اسکریپت "dart run bin/db_migrate.dart" استفاده نمائید.');
    }

    final chosen = cfgPath.trim();

    // تلاش برای باز کردن/ایجاد دیتابیس در مسیر انتخابی
    await _openDatabaseAtPath(chosen);
    _internalDbFilePath = chosen;

    // مهاجرت‌ها در onOpen handled inside _openDatabaseAtPath via schema.migrateAllTables
    _initCompleter!.complete();
  } catch (e) {
    try {
      _initCompleter!.completeError(e);
    } catch (_) {}
    _initCompleter = null;
    rethrow;
  } finally {
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      try {
        _initCompleter!.complete();
      } catch (_) {}
      _initCompleter = null;
    }
  }
}

/// باز کردن یا ایجاد دیتابیس در مسیر مشخص.
/// توجه: این تابع دایرکتوری مسیر را در صورت نیاز ایجاد می‌کند (اگر کاربر مسیری داد که قابل نوشتن باشد).
Future<void> _openDatabaseAtPath(String fullPath) async {
  try {
    final dir = Directory(dirname(fullPath));
    if (!await dir.exists()) {
      // تلاش برای ایجاد مسیر؛ اگر permission نداشته باشیم، exception پرتاب خواهد شد
      try {
        await dir.create(recursive: true);
      } catch (e) {
        throw Exception(
            'عدم امکان ایجاد پوشهٔ مسیر دیتابیس (${dir.path}): $e\nلطفاً مسیر دیگری انتخاب کنید یا دسترسی نوشتن را بررسی کنید.');
      }
    }
  } catch (e) {
    throw Exception('خطا در آماده‌سازی مسیر دیتابیس: $e');
  }

  try {
    _internalDb = await openDatabase(
      fullPath,
      version: _DB_VERSION,
      onCreate: (db, version) async {
        await schema.createAllTables(db);
      },
      onOpen: (db) async {
        await schema.migrateAllTables(db);
      },
    );
  } catch (e) {
    _internalDb = null;
    throw Exception(
        'ناتوانی در باز کردن/ایجاد فایل دیتابیس در مسیر "$fullPath": $e\nلطفاً مسیر را بررسی کن یا مسیر دیگری انتخاب کن.');
  }
}

/// تغییر مسیر دیتابیس در زمان اجرا (مثلاً وقتی کاربر در Settings مسیر جدید را انتخاب کرد).
/// این متد مسیر را اعتبارسنجی میکند (تلاش برای باز کردن فایل در مسیر جدید) و در صورت موفقیت آن را ذخیره میکند.
Future<void> setDbPath(String fullPath) async {
  Database? newDb;
  // اگر init هم‌اکنون در حال اجراست، صبر کن
  if (_initCompleter != null) await _initCompleter!.future;
  try {
    final dir = Directory(dirname(fullPath));
    if (!await dir.exists()) {
      try {
        await dir.create(recursive: true);
      } catch (e) {
        throw Exception(
            'عدم اجازهٔ ایجاد پوشهٔ مسیر دیتابیس: ${dir.path}. خطا: $e');
      }
    }

    // تلاش برای باز کردن/ساخت دیتابیس در مسیر جدید
    newDb = await openDatabase(
      fullPath,
      version: _DB_VERSION,
      onCreate: (db, version) async {
        await schema.createAllTables(db);
      },
      onOpen: (db) async {
        await schema.migrateAllTables(db);
      },
    );
  } catch (e) {
    try {
      if (newDb != null && newDb.isOpen) await newDb.close();
    } catch (_) {}
    throw Exception('تنظیم مسیر دیتابیس ناموفق بود: $e');
  }

  // اگر باز کردن موفق بود، دیتابیس قدیمی را ببند و مسیر جدید را جایگزین کن
  try {
    if (_internalDb != null && _internalDb!.isOpen) await _internalDb!.close();
  } catch (_) {}
  _internalDb = newDb;
  _internalDbFilePath = fullPath;

  // ذخیره مسیر جدید در ConfigManager (برای اجراهای بعدی)
  try {
    await ConfigManager.setDbFilePath(fullPath);
  } catch (_) {}
}

/// بستن دیتابیس فعلی
Future<void> close() async {
  try {
    if (_internalDb != null && _internalDb!.isOpen) await _internalDb!.close();
  } catch (_) {}
  _internalDb = null;
  _internalDbFilePath = null;
}

/// بازگرداندن مسیر فعلی فایل دیتابیس (در صورت وجود)
Future<String?> getCurrentDbFilePath() async {
  if (_internalDbFilePath != null) return _internalDbFilePath;
  try {
    final cfg = await ConfigManager.getDbFilePath();
    return cfg;
  } catch (_) {
    return null;
  }
}
