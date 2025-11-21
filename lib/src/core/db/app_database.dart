// lib/src/core/db/app_database.dart
// Façade یکپارچهٔ دیتابیس sqlite برای پروژه — نسخهٔ کامل و سازگار با ساختار فعلی ریپو
// توضیح خیلی خیلی کوتاه: این فایل تمام wrapperهای دیتابیس را فراهم میکند (init, migrations, DAO wrappers)
// و پشتیبانی از "خدمات" (services)، لیست مشترک قابلفروش (محصول+خدمت)، ثبت حرکت انبار و ثبت مرجوعی را دارد.
// - تغییر مهم: حذف export 'database.dart' تا circular export و ambiguous_export رخ ندهد.
// - کامنتهای فارسی برای بخشهای مهم قرار گرفته‌اند.

import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../config/config_manager.dart';
import 'package:path_provider/path_provider.dart'; // fallback امن برای موبایل/دسکتاپ

// DAOها - انتظار میرود این فایلها در lib/src/core/db/daos/ باشند
import 'daos/persons_dao.dart' as persons_dao;
import 'daos/persons_meta_dao.dart' as persons_meta_dao;
import 'daos/business_dao.dart' as business_dao;
import 'daos/categories_dao.dart' as categories_dao;
import 'daos/requests_dao.dart' as requests_dao;
import 'daos/license_dao.dart' as license_dao;

import 'daos/categories_persons_dao.dart' as persons_cat_dao;
import 'daos/categories_products_dao.dart' as products_cat_dao;

import 'daos/products_dao.dart' as products_dao;
import 'daos/inventory_dao.dart' as inventory_dao;
import 'daos/warehouses_dao.dart' as warehouses_dao;
import 'daos/sales_dao.dart' as sales_dao;

// خدمات (services) — اگر فایل موجود نیست باید lib/src/core/db/daos/services_dao.dart اضافه شود
import 'daos/services_dao.dart' as services_dao;

// NOTE: این فایل دیگر چیزی را re-export نمیکند تا از ambiguous_export جلوگیری شود.

class AppDatabase {
  AppDatabase._(); // سازنده خصوصی

  static Database? _db;
  static String? _dbFilePath;
  static const int _version = 8;
  static const String _defaultDbFileName = 'mizan.db'; // نام فایل دیتابیس

  // ---------- init محافظهکارانه و خودکار ----------
  static Future<void> init() async {
    if (_db != null) return;

    try {
      final cfgPath = await ConfigManager.getDbFilePath();
      if (cfgPath != null && cfgPath.trim().isNotEmpty) {
        _dbFilePath = cfgPath;
        await _openDatabaseAtPath(_dbFilePath!);
        // اطمینان از وجود جداول جدید اگر DB از قبل موجود بوده باشد
        await _ensureReturnsAndProfitTables();
        // مهاجرت خدمات اگر نیاز داشته باشد
        try {
          final d = await db;
          await services_dao.migrateServicesTable(d);
        } catch (_) {}
        return;
      }
    } catch (_) {}

    String? candidate;
    try {
      candidate = await _computeInstallFolderPath();
    } catch (_) {
      candidate = null;
    }

    if (candidate != null) {
      try {
        await setDbPath(candidate);
        // setDbPath خودش _ensure را اجرا میکند
        // migrate services table
        try {
          final d = await db;
          await services_dao.migrateServicesTable(d);
        } catch (_) {}
        return;
      } catch (_) {}
    }

    try {
      final fallback = await _computeAppSupportPath();
      await setDbPath(fallback);
      // migrate services table
      try {
        final d = await db;
        await services_dao.migrateServicesTable(d);
      } catch (_) {}
      return;
    } catch (e) {
      throw Exception(
          'عدم امکان تعیین مسیر دیتابیس بهصورت خودکار: $e. لطفاً مجوزهای فایل/پوشه را بررسی کنید.');
    }
  }

  // مسیر کنار executable برای دسکتاپ
  static Future<String?> _computeInstallFolderPath() async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final exe = Platform.resolvedExecutable;
        final exeDir = File(exe).parent.path;
        final candidateDir = join(exeDir, 'mizan_data');
        final candidatePath = join(candidateDir, _defaultDbFileName);

        final dir = Directory(candidateDir);
        if (!await dir.exists()) {
          try {
            await dir.create(recursive: true);
          } catch (_) {
            return null;
          }
        }

        try {
          final f = File(candidatePath);
          if (!await f.exists()) {
            await f.create();
            await f.delete();
          } else {
            final raf = await f.open(mode: FileMode.append);
            await raf.close();
          }
        } catch (_) {
          return null;
        }
        return candidatePath;
      } else {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  // مسیر امن اپلیکیشن
  static Future<String> _computeAppSupportPath() async {
    final dir = await getApplicationSupportDirectory();
    final dataDir = join(dir.path, 'mizan_data');
    final d = Directory(dataDir);
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return join(dataDir, _defaultDbFileName);
  }

  // باز کردن دیتابیس و ایجاد/مهاجرت جداول
  static Future<void> _openDatabaseAtPath(String fullPath) async {
    try {
      final dir = Directory(dirname(fullPath));
      if (!await dir.exists()) {
        try {
          await dir.create(recursive: true);
        } catch (e) {
          throw Exception(
              'عدم امکان ایجاد دایرکتوری مسیر دیتابیس (${dir.path}): $e');
        }
      }
    } catch (e) {
      throw Exception('خطا در آماده‌سازی مسیر دیتابیس: $e');
    }

    try {
      _db = await openDatabase(
        fullPath,
        version: _version,
        onCreate: (db, version) async {
          // ایجاد جداول پایه از DAOها
          await requests_dao.createRequestsTable(db);
          await license_dao.createLicenseTable(db);
          await business_dao.createBusinessTable(db);
          await persons_dao.createPersonsTable(db);
          await categories_dao.createCategoriesTable(db);
          await products_dao.createProductsTables(db);
          await inventory_dao.createInventoryTables(db);
          await warehouses_dao.createWarehousesTable(db);
          await sales_dao.createSalesTables(db);

          // ایجاد جدول services هم در ایجاد اولیه (اگر DAOs/services وجود داشته باشد)
          try {
            await services_dao.createServicesTable(db);
          } catch (_) {}

          // جدول شیفتها مستقیماً اینجا ایجاد میشود
          await db.execute('''
            CREATE TABLE IF NOT EXISTS shifts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              person_id INTEGER NOT NULL,
              started_at INTEGER NOT NULL,
              ended_at INTEGER,
              terminal_id TEXT,
              notes TEXT,
              active INTEGER DEFAULT 1
            )
          ''');

          // جداول جدید: profit_shares و sale_returns و sale_return_lines
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

          await persons_cat_dao.createPersonsCategoriesTable(db);
          await products_cat_dao.createProductsCategoriesTable(db);

          try {
            await persons_meta_dao.migratePersonsMetaTable(db);
          } catch (_) {}
        },
        onOpen: (db) async {
          // مهاجرت محافظه‌کارانه برای همهٔ DAOها
          try {
            await requests_dao.migrateRequestsTable(db);
          } catch (_) {}
          try {
            await license_dao.migrateLicenseTable(db);
          } catch (_) {}
          try {
            await business_dao.migrateBusinessTable(db);
          } catch (_) {}
          try {
            await persons_dao.migratePersonsTable(db);
          } catch (_) {}
          try {
            await categories_dao.migrateCategoriesTable(db);
          } catch (_) {}
          try {
            await products_dao.migrateProductsTables(db);
          } catch (_) {}
          try {
            await inventory_dao.migrateInventoryTables(db);
          } catch (_) {}
          try {
            await warehouses_dao.migrateWarehousesTable(db);
          } catch (_) {}
          try {
            await sales_dao.migrateSalesTables(db);
          } catch (_) {}

          // اطمینان از وجود جداول جدید (در صورت DBهای قدیمی)
          await _ensureReturnsAndProfitTables();
          try {
            await persons_cat_dao.migratePersonsCategoriesTable(db);
          } catch (_) {}
          try {
            await products_cat_dao.migrateProductsCategoriesTable(db);
          } catch (_) {}
          try {
            await services_dao.migrateServicesTable(db);
          } catch (_) {}
          try {
            await persons_meta_dao.migratePersonsMetaTable(db);
          } catch (_) {}
        },
      );
    } catch (e) {
      _db = null;
      throw Exception(
          'ناتوانی در باز کردن/ایجاد فایل دیتابیس در مسیر "$fullPath": $e');
    }
  }

  // ---------- ایجاد مطمئنِ جداول جدید ----------
  static Future<void> _ensureReturnsAndProfitTables() async {
    try {
      final d = await db;
      await d.execute('''
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
      await d.execute('''
        CREATE TABLE IF NOT EXISTS sale_returns (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sale_id INTEGER,
          created_at INTEGER,
          actor TEXT,
          notes TEXT
        )
      ''');
      await d.execute('''
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
      // اطمینان از وجود product_categories تا خطای INSERT در DAO جلوگیری شود.
      await d.execute('''
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
      // اگر خطایی باشد نادیده میگیریم تا init متوقف نشود؛ UI میتواند خطا را نشان دهد.
    }
  }

  // ---------- تغییر یا تعیین مسیر دیتابیس (استفاده داخلی) ----------
  static Future<void> setDbPath(String fullPath) async {
    Database? newDb;
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

      newDb = await openDatabase(
        fullPath,
        version: _version,
        onCreate: (db, version) async {
          await requests_dao.createRequestsTable(db);
          await license_dao.createLicenseTable(db);
          await business_dao.createBusinessTable(db);
          await persons_dao.createPersonsTable(db);
          await categories_dao.createCategoriesTable(db);
          await products_dao.createProductsTables(db);
          await inventory_dao.createInventoryTables(db);
          await warehouses_dao.createWarehousesTable(db);
          await sales_dao.createSalesTables(db);
          // ایجاد جدول services نیز در onCreate
          try {
            await services_dao.createServicesTable(db);
          } catch (_) {}
          // shifts
          await db.execute('''
            CREATE TABLE IF NOT EXISTS shifts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              person_id INTEGER NOT NULL,
              started_at INTEGER NOT NULL,
              ended_at INTEGER,
              terminal_id TEXT,
              notes TEXT,
              active INTEGER DEFAULT 1
            )
          ''');
          await persons_cat_dao.createPersonsCategoriesTable(db);
          await products_cat_dao.createProductsCategoriesTable(db);

          // حاشیه امنیتی: product_categories
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

          // جداول جدید برای profit_shares و returns
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
        },
        onOpen: (db) async {
          try {
            await requests_dao.migrateRequestsTable(db);
          } catch (_) {}
          try {
            await business_dao.migrateBusinessTable(db);
          } catch (_) {}
          try {
            await persons_dao.migratePersonsTable(db);
          } catch (_) {}
          try {
            await categories_dao.migrateCategoriesTable(db);
          } catch (_) {}
          try {
            await license_dao.migrateLicenseTable(db);
          } catch (_) {}
          try {
            await products_dao.migrateProductsTables(db);
          } catch (_) {}
          try {
            await inventory_dao.migrateInventoryTables(db);
          } catch (_) {}
          try {
            await warehouses_dao.migrateWarehousesTable(db);
          } catch (_) {}
          try {
            await sales_dao.migrateSalesTables(db);
          } catch (_) {}

          await _ensureReturnsAndProfitTables();
        },
      );
    } catch (e) {
      try {
        if (newDb != null && newDb.isOpen) await newDb.close();
      } catch (_) {}
      throw Exception('تنظیم مسیر دیتابیس ناموفق بود: $e');
    }

    // جایگزینی امن
    try {
      if (_db != null && _db!.isOpen) await _db!.close();
    } catch (_) {}
    _db = newDb;
    _dbFilePath = fullPath;

    // ذخیره مسیر در ConfigManager برای اطلاعرسانی یا نمایش (اختیاری)
    try {
      await ConfigManager.setDbFilePath(fullPath);
    } catch (_) {}
  }

  // ---------- مسیر فعلی ----------
  static Future<String?> getCurrentDbFilePath() async {
    if (_dbFilePath != null) return _dbFilePath;
    return await ConfigManager.getDbFilePath();
  }

  // ---------- دسترسی به Database ----------
  static Future<Database> get db async {
    if (_db == null) {
      throw Exception(
          'دیتابیس مقداردهی نشده است. قبل از استفاده AppDatabase.init() را اجرا کنید.');
    }
    return _db!;
  }

  // ================= Utility داخلی =================
  static bool _flagIsTrue(dynamic v) {
    if (v == null) return false;
    if (v is int) return v == 1;
    if (v is bool) return v;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  // ================= Requests / License / Business =================
  static Future<int> insertPendingRequest(Map<String, dynamic> item) async {
    final d = await db;
    return await requests_dao.insertPendingRequest(d, item);
  }

  static Future<List<Map<String, dynamic>>> getRequests(
      {String? status}) async {
    final d = await db;
    return await requests_dao.getRequests(d, status: status);
  }

  static Future<Map<String, dynamic>?> getRequestByEmailOrDevice(
      {String? email, String? deviceHash}) async {
    final d = await db;
    return await requests_dao.getRequestByEmailOrDevice(d,
        email: email, deviceHash: deviceHash);
  }

  static Future<int> updateRequestStatusByEmailOrDevice(
      {String? email, String? deviceHash, required String status}) async {
    final d = await db;
    return await requests_dao.updateRequestStatusByEmailOrDevice(d,
        email: email, deviceHash: deviceHash, status: status);
  }

  static Future<int> deleteRequestsByEmailOrDevice(
      {String? email, String? deviceHash}) async {
    final d = await db;
    return await requests_dao.deleteRequestsByEmailOrDevice(d,
        email: email, deviceHash: deviceHash);
  }

  static Future<int> saveLocalLicense(Map<String, dynamic> item) async {
    final d = await db;
    return await license_dao.saveLocalLicense(d, item);
  }

  static Future<Map<String, dynamic>?> getLocalLicense() async {
    final d = await db;
    return await license_dao.getLocalLicense(d);
  }

  static Future<int> deleteLocalLicense() async {
    final d = await db;
    return await license_dao.deleteLocalLicense(d);
  }

  static Future<int> saveBusinessProfile(Map<String, dynamic> item) async {
    final d = await db;
    return await business_dao.saveBusinessProfile(d, item);
  }

  static Future<Map<String, dynamic>?> getBusinessProfile() async {
    final d = await db;
    return await business_dao.getBusinessProfile(d);
  }

  static Future<bool> hasBusinessProfile() async {
    final d = await db;
    return await business_dao.hasBusinessProfile(d);
  }

  static Future<int> deleteBusinessProfile() async {
    final d = await db;
    return await business_dao.deleteBusinessProfile(d);
  }

  // ================= Persons =================
  static Future<String> getNextAccountCode() async {
    final d = await db;
    return await persons_dao.getNextAccountCode(d);
  }

  static Future<int> savePerson(Map<String, dynamic> item) async {
    final d = await db;
    return await persons_dao.savePerson(d, item);
  }

  static Future<List<Map<String, dynamic>>> getPersons() async {
    final d = await db;
    return await persons_dao.getPersons(d);
  }

  static Future<Map<String, dynamic>?> getPersonById(int id) async {
    final d = await db;
    return await persons_dao.getPersonById(d, id);
  }

  static Future<int> deletePerson(int id) async {
    final d = await db;
    return await persons_dao.deletePerson(d, id);
  }

  static Future<double> getTotalSharePercentage() async {
    final d = await db;
    return await persons_meta_dao.getTotalSharePercentage(d);
  }

  static Future<bool> canAddShareholder(double additional) async {
    final d = await db;
    return await persons_meta_dao.canAddShareholder(d, additional);
  }

  static Future<int> updatePersonTypes(
      int personId, Map<String, dynamic> types) async {
    final d = await db;
    return await persons_meta_dao.updatePersonTypes(d, personId, types);
  }

  static Future<double> getPersonSharePercentage(int personId) async {
    final d = await db;
    return await persons_meta_dao.getPersonSharePercentage(d, personId);
  }

  // ================= Shifts / Sessions =================
  static Future<int> startShift(Map<String, dynamic> item) async {
    final d = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await d.transaction<int>((txn) async {
      final personIdRaw = item['person_id'];
      final personId = (personIdRaw is int)
          ? personIdRaw
          : int.tryParse(personIdRaw?.toString() ?? '') ?? 0;
      final terminalId = item['terminal_id']?.toString();

      if (terminalId != null && terminalId.isNotEmpty) {
        try {
          await txn.update('shifts', {'ended_at': now, 'active': 0},
              where: 'terminal_id = ? AND active = 1', whereArgs: [terminalId]);
        } catch (_) {}
      }

      if (personId > 0) {
        try {
          await txn.update('shifts', {'ended_at': now, 'active': 0},
              where: 'person_id = ? AND active = 1', whereArgs: [personId]);
        } catch (_) {}
      }

      final toInsert = <String, dynamic>{
        'person_id': personId,
        'started_at': now,
        'ended_at': null,
        'terminal_id': terminalId,
        'notes': item['notes'],
        'active': 1,
      };
      final id = await txn.insert('shifts', toInsert);
      return id;
    });
  }

  static Future<int> endShift(int shiftId) async {
    final d = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await d.update('shifts', {'ended_at': now, 'active': 0},
        where: 'id = ?', whereArgs: [shiftId]);
  }

  static Future<Map<String, dynamic>?> getActiveShift(
      {String? terminalId}) async {
    final d = await db;
    try {
      if (terminalId != null && terminalId.isNotEmpty) {
        final rows = await d.query('shifts',
            where: 'terminal_id = ? AND active = 1',
            whereArgs: [terminalId],
            limit: 1);
        if (rows.isNotEmpty) {
          final r = Map<String, dynamic>.from(rows.first);
          try {
            final pid = r['person_id'] is int
                ? r['person_id'] as int
                : int.tryParse(r['person_id']?.toString() ?? '') ?? 0;
            if (pid > 0) {
              final p = await d.query('persons',
                  where: 'id = ?', whereArgs: [pid], limit: 1);
              if (p.isNotEmpty) {
                r['person_name'] = p.first['display_name'] ??
                    '${p.first['first_name'] ?? ''} ${p.first['last_name'] ?? ''}';
              }
            }
          } catch (_) {}
          return r;
        }
      }
      final rows = await d.query('shifts', where: 'active = 1', limit: 1);
      if (rows.isEmpty) return null;
      final r = Map<String, dynamic>.from(rows.first);
      try {
        final pid = r['person_id'] is int
            ? r['person_id'] as int
            : int.tryParse(r['person_id']?.toString() ?? '') ?? 0;
        if (pid > 0) {
          final p = await d.query('persons',
              where: 'id = ?', whereArgs: [pid], limit: 1);
          if (p.isNotEmpty) {
            r['person_name'] = p.first['display_name'] ??
                '${p.first['first_name'] ?? ''} ${p.first['last_name'] ?? ''}';
          }
        }
      } catch (_) {}
      return r;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getShiftById(int id) async {
    final d = await db;
    final rows =
        await d.query('shifts', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final r = Map<String, dynamic>.from(rows.first);
    try {
      final pid = r['person_id'] is int
          ? r['person_id'] as int
          : int.tryParse(r['person_id']?.toString() ?? '') ?? 0;
      if (pid > 0) {
        final p = await d.query('persons',
            where: 'id = ?', whereArgs: [pid], limit: 1);
        if (p.isNotEmpty) {
          r['person_name'] = p.first['display_name'] ??
              '${p.first['first_name'] ?? ''} ${p.first['last_name'] ?? ''}';
        }
      }
    } catch (_) {}
    return r;
  }

  static Future<List<Map<String, dynamic>>> getShifts(
      {int? personId, int limit = 100, int offset = 0}) async {
    final d = await db;
    final args = <dynamic>[];
    String sql =
        'SELECT s.*, p.display_name as person_name FROM shifts s LEFT JOIN persons p ON p.id = s.person_id';
    if (personId != null) {
      sql += ' WHERE s.person_id = ?';
      args.add(personId);
    }
    sql += ' ORDER BY s.started_at DESC LIMIT ? OFFSET ?';
    args.add(limit);
    args.add(offset);
    final rows = await d.rawQuery(sql, args);
    return rows;
  }

  // ================= Categories / Products / Inventory / Sales etc. =================
  static Future<int> saveCategory(Map<String, dynamic> item) async {
    final d = await db;
    return await categories_dao.saveCategory(d, item);
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    final d = await db;
    return await categories_dao.getCategories(d);
  }

  static Future<int> deleteCategory(int id) async {
    final d = await db;
    return await categories_dao.deleteCategory(d, id);
  }

  static Future<int> savePersonCategory(Map<String, dynamic> item) async {
    final d = await db;
    return await persons_cat_dao.savePersonCategory(d, item);
  }

  static Future<List<Map<String, dynamic>>> getPersonCategories() async {
    final d = await db;
    return await persons_cat_dao.getPersonCategories(d);
  }

  static Future<int> deletePersonCategory(int id) async {
    final d = await db;
    return await persons_cat_dao.deletePersonCategory(d, id);
  }

  static Future<int> saveProductCategory(Map<String, dynamic> item) async {
    final d = await db;
    return await products_cat_dao.saveProductCategory(d, item);
  }

  static Future<List<Map<String, dynamic>>> getProductCategories() async {
    final d = await db;
    return await products_cat_dao.getProductCategories(d);
  }

  static Future<int> deleteProductCategory(int id) async {
    final d = await db;
    return await products_cat_dao.deleteProductCategory(d, id);
  }

  static Future<int> saveProduct(Map<String, dynamic> item) async {
    final d = await db;
    return await products_dao.saveProduct(d, item);
  }

  static Future<List<Map<String, dynamic>>> getProducts({String? q}) async {
    final d = await db;
    return await products_dao.getProducts(d, q: q);
  }

  static Future<Map<String, dynamic>?> getProductById(int id) async {
    final d = await db;
    return await products_dao.getProductById(d, id);
  }

  static Future<int> deleteProduct(int id) async {
    try {
      final d = await db;
      await d.delete('stock_levels', where: 'item_id = ?', whereArgs: [id]);
      await d.delete('stock_movements', where: 'item_id = ?', whereArgs: [id]);
      return await products_dao.deleteProduct(d, id);
    } catch (_) {
      return 0;
    }
  }

  static Future<int> saveUnit(Map<String, dynamic> unit) async {
    final d = await db;
    return await products_dao.saveUnit(d, unit);
  }

  static Future<List<Map<String, dynamic>>> getUnits() async {
    final d = await db;
    return await products_dao.getUnits(d);
  }

  static Future<int> deleteUnit(int id) async {
    try {
      final d = await db;
      await d.update('inventory_items', {'unit_id': null, 'unit': null},
          where: 'unit_id = ?', whereArgs: [id]);
    } catch (_) {}
    final d = await db;
    return await products_dao.deleteUnit(d, id);
  }

  static Future<int> getNextSequence(String name) async {
    final d = await db;
    return await products_dao.getNextSequence(d, name);
  }

  static Future<String> generateNextProductCode() async {
    final d = await db;
    return await products_dao.generateNextProductCode(d);
  }

  // Inventory / Stock wrappers
  static Future<int> saveInventoryItem(Map<String, dynamic> item) async {
    final d = await db;
    return await inventory_dao.saveInventoryItem(d, item);
  }

  static Future<List<Map<String, dynamic>>> getInventoryItems(
      {String? q}) async {
    final d = await db;
    return await inventory_dao.getInventoryItems(d, q: q);
  }

  static Future<Map<String, dynamic>?> getInventoryItemById(int id) async {
    final d = await db;
    return await inventory_dao.getInventoryItemById(d, id);
  }

  static Future<int> deleteInventoryItem(int id) async {
    final d = await db;
    return await inventory_dao.deleteInventoryItem(d, id);
  }

  /// ثبت حرکت stock_movements — wrapper امن که به DAO ارجاع میدهد
  static Future<int> registerStockMovement({
    required int itemId,
    required int warehouseId,
    required String type,
    required double qty,
    String? reference,
    String? notes,
    String? actor,
  }) async {
    final d = await db;
    return await inventory_dao.registerStockMovement(d,
        itemId: itemId,
        warehouseId: warehouseId,
        type: type,
        qty: qty,
        reference: reference,
        notes: notes,
        actor: actor);
  }

  /// بروزرسانی حرکت موجودی — wrapper با transaction و recompute
  static Future<int> updateStockMovement(
      int id, Map<String, dynamic> changes) async {
    final d = await db;
    return await d.transaction<int>((txn) async {
      final existing = await txn.query('stock_movements',
          where: 'id = ?', whereArgs: [id], limit: 1);
      if (existing.isEmpty) return 0;
      final prev = Map<String, dynamic>.from(existing.first);
      final prevItemId = (prev['item_id'] is int)
          ? prev['item_id'] as int
          : int.tryParse(prev['item_id']?.toString() ?? '') ?? 0;
      final prevWarehouseId = (prev['warehouse_id'] is int)
          ? prev['warehouse_id'] as int
          : int.tryParse(prev['warehouse_id']?.toString() ?? '') ?? 0;

      final affected = await txn
          .update('stock_movements', changes, where: 'id = ?', whereArgs: [id]);

      int finalItemId = prevItemId;
      int finalWarehouseId = prevWarehouseId;
      if (changes.containsKey('item_id')) {
        finalItemId = (changes['item_id'] is int)
            ? changes['item_id'] as int
            : int.tryParse(changes['item_id']?.toString() ?? '') ?? finalItemId;
      }
      if (changes.containsKey('warehouse_id')) {
        finalWarehouseId = (changes['warehouse_id'] is int)
            ? changes['warehouse_id'] as int
            : int.tryParse(changes['warehouse_id']?.toString() ?? '') ??
                finalWarehouseId;
      }

      try {
        await inventory_dao.recomputeStockLevelsForPair(
            txn, prevItemId, prevWarehouseId);
      } catch (_) {}
      if (finalItemId != prevItemId || finalWarehouseId != prevWarehouseId) {
        try {
          await inventory_dao.recomputeStockLevelsForPair(
              txn, finalItemId, finalWarehouseId);
        } catch (_) {}
      }

      return affected;
    });
  }

  static Future<List<Map<String, dynamic>>> getStockLevels(
      {int? warehouseId, int? itemId}) async {
    final d = await db;
    return await inventory_dao.getStockLevels(d,
        warehouseId: warehouseId, itemId: itemId);
  }

  static Future<List<Map<String, dynamic>>> getStockMovements(
      {int? warehouseId, int? itemId, int limit = 100, int offset = 0}) async {
    final d = await db;
    return await inventory_dao.getStockMovements(d,
        warehouseId: warehouseId, itemId: itemId, limit: limit, offset: offset);
  }

  static Future<double> getQtyForItemInWarehouse(
      int itemId, int warehouseId) async {
    try {
      if (warehouseId == 0) {
        final levels = await getStockLevels(itemId: itemId);
        if (levels.isEmpty) return 0.0;
        double sum = 0.0;
        for (final r in levels) {
          final q = r['quantity'];
          if (q == null) continue;
          if (q is num)
            sum += q.toDouble();
          else
            sum += double.tryParse(q.toString()) ?? 0.0;
        }
        return sum;
      }

      final levels =
          await getStockLevels(warehouseId: warehouseId, itemId: itemId);
      if (levels.isEmpty) return 0.0;
      final q = levels.first['quantity'];
      if (q == null) return 0.0;
      if (q is num) return q.toDouble();
      return double.tryParse(q.toString()) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  // Warehouses
  static Future<int> saveWarehouse(Map<String, dynamic> item) async {
    final d = await db;
    return await warehouses_dao.saveWarehouse(d, item);
  }

  static Future<List<Map<String, dynamic>>> getWarehouses() async {
    final d = await db;
    return await warehouses_dao.getWarehouses(d);
  }

  static Future<Map<String, dynamic>?> getWarehouseById(int id) async {
    final d = await db;
    return await warehouses_dao.getWarehouseById(d, id);
  }

  static Future<int> deleteWarehouse(int id) async {
    final d = await db;
    return await warehouses_dao.deleteWarehouse(d, id);
  }

  // Sales (wrapper)
  static Future<int> saveSale(
      Map<String, dynamic> sale, List<Map<String, dynamic>> lines) async {
    final d = await db;
    final id = await sales_dao.saveSale(d, sale, lines);
    try {
      await d.execute('''
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
      await createProfitSharesForSale(d, id);
    } catch (_) {}
    return id;
  }

  static Future<List<Map<String, dynamic>>> getSales(
      {int limit = 100, int offset = 0}) async {
    final d = await db;
    return await sales_dao.getSales(d, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>?> getSaleById(int id) async {
    final d = await db;
    return await sales_dao.getSaleById(d, id);
  }

  static Future<int> deleteSale(int id) async {
    final d = await db;
    return await sales_dao.deleteSale(d, id);
  }

  // ذخیره/خواندن payment_info از sales_dao
  static Future<int> setSalePaymentInfo(
      int saleId, Map<String, dynamic>? info) async {
    final d = await db;
    return await sales_dao.setSalePaymentInfo(d, saleId, info);
  }

  static Future<Map<String, dynamic>?> getSalePaymentInfo(int saleId) async {
    final d = await db;
    return await sales_dao.getSalePaymentInfo(d, saleId);
  }

  // جستجوی سادهٔ فاکتورها برای نمایش در فرم مرجوعی (search by invoice/customer/notes)
  static Future<List<Map<String, dynamic>>> searchSales(String q,
      {int limit = 200}) async {
    final d = await db;
    final qLike = '%${q.replaceAll('%', '')}%';
    final rows = await d.rawQuery('''
      SELECT s.*, p.display_name as customer_name
      FROM sales s
      LEFT JOIN persons p ON p.id = s.customer_id
      WHERE s.invoice_no LIKE ? OR (p.display_name LIKE ?) OR (s.notes LIKE ?)
      ORDER BY s.created_at DESC
      LIMIT ?
    ''', [qLike, qLike, qLike, limit]);
    return rows;
  }

  // ================= Profit shares / Returns =================

  static Future<void> createProfitSharesForSale(Database d, int saleId) async {
    try {
      final lines = await d
          .query('sale_lines', where: 'sale_id = ?', whereArgs: [saleId]);
      if (lines.isEmpty) return;

      final persons = await d.query('persons');
      final shareholders = <Map<String, dynamic>>[];
      for (final p in persons) {
        final v = p['type_shareholder'];
        if (_flagIsTrue(v)) {
          double perc = 0.0;
          final sp = p['shareholder_percentage'];
          if (sp != null) {
            perc = _toDouble(sp);
          } else {
            try {
              final pid = (p['id'] is int)
                  ? p['id'] as int
                  : int.tryParse(p['id']?.toString() ?? '') ?? 0;
              final sp2 = await persons_meta_dao.getPersonSharePercentage(
                  await db, pid);
              perc = sp2;
            } catch (_) {}
          }
          if (perc > 0.0) {
            final copy = Map<String, dynamic>.from(p);
            copy['share_percent'] = perc;
            shareholders.add(copy);
          }
        }
      }

      if (shareholders.isEmpty) return;

      final now = DateTime.now().millisecondsSinceEpoch;

      for (final ln in lines) {
        final saleLineId = (ln['id'] is int)
            ? ln['id'] as int
            : int.tryParse(ln['id']?.toString() ?? '') ?? 0;
        final qty = _toDouble(ln['quantity']);
        final unitPrice = _toDouble(ln['unit_price']);
        final purchasePrice = _toDouble(ln['purchase_price']);
        final discount = _toDouble(ln['discount'] ?? 0.0);

        final discountPerUnit = (qty > 0) ? (discount / qty) : 0.0;
        final profitPerUnit = (unitPrice - purchasePrice);
        final profitLine = (profitPerUnit * qty) - (discountPerUnit * qty);

        if (profitLine.abs() < 0.0001) continue;

        for (final sh in shareholders) {
          final pid = (sh['id'] is int)
              ? sh['id'] as int
              : int.tryParse(sh['id']?.toString() ?? '') ?? 0;
          final percent = _toDouble(
              sh['share_percent'] ?? sh['shareholder_percentage'] ?? 0.0);
          if (percent <= 0.0) continue;
          final amount = profitLine * (percent / 100.0);

          await d.insert('profit_shares', {
            'sale_id': saleId,
            'sale_line_id': saleLineId,
            'person_id': pid,
            'percent': percent,
            'amount': double.parse(amount.toStringAsFixed(4)),
            'is_adjustment': 0,
            'note': 'initial allocation',
            'created_at': now
          });
        }
      }
    } catch (e) {
      // ignore
    }
  }

  /// registerSaleReturn:
  /// - returnLines: لیست { sale_line_id, product_id, quantity, unit_price, purchase_price, warehouse_id }
  /// - تغییرات انجام شده:
  ///   * ثبت sale_return_lines داخل txn
  ///   * ثبت حرکت انبار برای هر ردیف با استفاده از txn و نوع 'in' (افزایش موجودی)
  ///   * محاسبهٔ مجموع مبلغ مرجوعی و کسر از persons.balance مشتری (اگر customer_id موجود باشد)
  ///   * درج تعدیلات profit_shares در صورت نیاز
  ///   * اگر باقیماندهای روی فاکتور بود split انجام میشود و فاکتور اصلی کانسل یا بروزرسانی میشود
  static Future<int> registerSaleReturn(
      int saleId, List<Map<String, dynamic>> returnLines,
      {String? actor, String? notes}) async {
    final d = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await d.transaction<int>((txn) async {
      // بررسی وجود جدولها (در DBهای قدیمی ممکن است نباشند)
      try {
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS sale_returns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sale_id INTEGER,
            created_at INTEGER,
            actor TEXT,
            notes TEXT
          )
        ''');
        await txn.execute('''
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
        await txn.execute('''
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
      } catch (_) {}

      // درج رکورد return
      final returnId = await txn.insert('sale_returns', {
        'sale_id': saleId,
        'created_at': now,
        'actor': actor ?? '',
        'notes': notes ?? ''
      });

      // خواندن خطوط اصلی فاکتور
      final existingLines = await txn
          .query('sale_lines', where: 'sale_id = ?', whereArgs: [saleId]);
      // Map از sale_line_id -> خط
      final Map<int, Map<String, dynamic>> existingMap = {};
      for (final l in existingLines) {
        final lid = (l['id'] is int)
            ? (l['id'] as int)
            : int.tryParse(l['id']?.toString() ?? '') ?? 0;
        existingMap[lid] = Map<String, dynamic>.from(l);
      }

      // گرفتن customer_id فاکتور (برای اصلاح حساب مشتری)
      int? customerId;
      try {
        final saleRows = await txn.query('sales',
            where: 'id = ?', whereArgs: [saleId], limit: 1);
        if (saleRows.isNotEmpty) {
          customerId = (saleRows.first['customer_id'] is int)
              ? saleRows.first['customer_id'] as int
              : int.tryParse(saleRows.first['customer_id']?.toString() ?? '');
        }
      } catch (_) {
        customerId = null;
      }

      // محاسبهٔ مجموع مرجوعی برای هر sale_line_id (چون کاربر ممکن است چند خط را انتخاب کند)
      final Map<int, double> toReturnByLine = {};
      for (final rl in returnLines) {
        final slid = (rl['sale_line_id'] is int)
            ? rl['sale_line_id'] as int
            : int.tryParse(rl['sale_line_id']?.toString() ?? '') ?? 0;
        final qty = _toDouble(rl['quantity']);
        if (qty <= 0) continue;
        toReturnByLine[slid] = (toReturnByLine[slid] ?? 0.0) + qty;
      }

      // خواندن لیست سهامداران برای محاسبهٔ تعدیل در صورت نیاز
      final persons = await txn.query('persons');
      final shareholders = <Map<String, dynamic>>[];
      for (final p in persons) {
        final v = p['type_shareholder'];
        if (_flagIsTrue(v)) {
          double perc = 0.0;
          final sp = p['shareholder_percentage'];
          if (sp != null) {
            perc = _toDouble(sp);
          } else {
            try {
              final pid = (p['id'] is int)
                  ? p['id'] as int
                  : int.tryParse(p['id']?.toString() ?? '') ?? 0;
              final sp2 = await persons_meta_dao.getPersonSharePercentage(
                  txn as Database, pid);
              perc = sp2;
            } catch (_) {}
          }
          if (perc > 0.0) {
            final copy = Map<String, dynamic>.from(p);
            copy['share_percent'] = perc;
            shareholders.add(copy);
          }
        }
      }

      // محاسبات remainingByLine
      final Map<int, double> remainingByLine = {};
      for (final entry in existingMap.entries) {
        final lid = entry.key;
        final ln = entry.value;
        final origQty = _toDouble(ln['quantity']);
        final retQty = toReturnByLine[lid] ?? 0.0;
        final newQty = (origQty - retQty).clamp(0.0, double.infinity);
        remainingByLine[lid] = newQty;
      }

      // درج sale_return_lines و ثبت حرکت انبار برای مرجوعیها
      double totalReturnedAmount =
          0.0; // جمع مبلغ مرجوعی (برای اصلاح حساب مشتری)

      for (final rl in returnLines) {
        final saleLineId = (rl['sale_line_id'] is int)
            ? rl['sale_line_id'] as int
            : int.tryParse(rl['sale_line_id']?.toString() ?? '') ?? 0;
        final productId = (rl['product_id'] is int)
            ? rl['product_id'] as int
            : int.tryParse(rl['product_id']?.toString() ?? '') ?? 0;
        final retQty = _toDouble(rl['quantity']);
        final unitPrice = _toDouble(rl['unit_price']);
        final purchasePrice = _toDouble(rl['purchase_price']);
        final warehouseId = (rl['warehouse_id'] is int)
            ? rl['warehouse_id'] as int
            : int.tryParse(rl['warehouse_id']?.toString() ?? '') ?? 0;

        if (retQty <= 0) continue;

        final lineTotal = double.parse((unitPrice * retQty).toStringAsFixed(4));
        totalReturnedAmount += lineTotal;

        await txn.insert('sale_return_lines', {
          'return_id': returnId,
          'sale_line_id': saleLineId,
          'product_id': productId,
          'quantity': retQty,
          'unit_price': unitPrice,
          'purchase_price': purchasePrice,
          'line_total': lineTotal
        });

        // ثبت حرکت انبار: استفاده از txn تا در همان تراکنش ثبت شود.
        // از نوع 'in' استفاده میکنیم تا موجودی افزوده شود؛ reference شامل returnId است.
        try {
          await inventory_dao.registerStockMovement(txn,
              itemId: productId,
              warehouseId: warehouseId,
              type: 'in',
              qty: retQty,
              reference: 'sale_return:$returnId',
              notes: 'Return from sale $saleId (return:$returnId)',
              actor: actor);
        } catch (_) {}

        // محاسبهٔ سود برگشتی و درج تعدیل برای سهامداران
        final ex = existingMap[saleLineId];
        if (ex == null) continue;
        final origQty = _toDouble(ex['quantity']);
        final origDiscount = _toDouble(ex['discount'] ?? 0.0);
        final discountPerUnit = (origQty > 0) ? (origDiscount / origQty) : 0.0;
        final returnedDiscount = discountPerUnit * retQty;
        final profitReturned =
            (unitPrice - purchasePrice) * retQty - returnedDiscount;

        if (shareholders.isNotEmpty && profitReturned.abs() >= 0.000001) {
          for (final sh in shareholders) {
            final pid = (sh['id'] is int)
                ? sh['id'] as int
                : int.tryParse(sh['id']?.toString() ?? '') ?? 0;
            final percent = _toDouble(
                sh['share_percent'] ?? sh['shareholder_percentage'] ?? 0.0);
            if (percent <= 0.0) continue;
            final amount =
                -(profitReturned * (percent / 100.0)); // منفی برای تعدیل
            await txn.insert('profit_shares', {
              'sale_id': saleId,
              'sale_line_id': saleLineId,
              'person_id': pid,
              'percent': percent,
              'amount': double.parse(amount.toStringAsFixed(4)),
              'is_adjustment': 1,
              'note': 'return adjustment for return_id:$returnId',
              'created_at': now
            });
          }
        }
      } // end for each returnLines entry

      // اگر مشتری مشخص است، از حساب او مبلغ مرجوعی را کم کن (balance -= totalReturnedAmount)
      try {
        if (customerId != null && customerId > 0 && totalReturnedAmount > 0.0) {
          await txn.rawUpdate(
              'UPDATE persons SET balance = COALESCE(balance,0) - ? WHERE id = ?',
              [totalReturnedAmount, customerId]);
        }
      } catch (_) {
        // اگر بهروزرسانی حساب مشتری ناموفق بود، ادامه بده (برای جلوگیری از rollback غیرمنتظره)
      }

      // بررسی remaining و ایجاد sale جدید / کانسل کردن اصلی
      bool anyRemaining = false;
      for (final v in remainingByLine.values) {
        if ((v).abs() > 0.000001) {
          anyRemaining = true;
          break;
        }
      }

      if (!anyRemaining) {
        try {
          await txn.update(
              'sales',
              {
                'total': 0.0,
                'notes':
                    '${(await txn.query('sales', where: 'id = ?', whereArgs: [
                      saleId
                    ])).first['notes']}\n[cancelled: full return #$returnId]'
              },
              where: 'id = ?',
              whereArgs: [saleId]);
        } catch (_) {}
        return returnId;
      }

      final saleRowList = await txn.query('sales',
          where: 'id = ?', whereArgs: [saleId], limit: 1);
      if (saleRowList.isEmpty) {
        double newTotal = 0.0;
        for (final e in remainingByLine.entries) {
          final orig = existingMap[e.key];
          if (orig == null) continue;
          final newQty = e.value;
          if (newQty <= 0) continue;
          final up = _toDouble(orig['unit_price']);
          final discPerUnit = (_toDouble(orig['discount'] ?? 0.0) /
              (_toDouble(orig['quantity']) > 0
                  ? _toDouble(orig['quantity'])
                  : 1));
          final newLineTotal = (up * newQty) - (discPerUnit * newQty);
          newTotal += newLineTotal;
        }
        try {
          await txn.update(
              'sales', {'total': double.parse(newTotal.toStringAsFixed(4))},
              where: 'id = ?', whereArgs: [saleId]);
        } catch (_) {}
        return returnId;
      }

      final origSale = Map<String, dynamic>.from(saleRowList.first);
      final origInvoiceNo = origSale['invoice_no']?.toString() ?? '';
      final newInvoiceNo = '${origInvoiceNo}_SPLIT_$now';

      double newSaleTotal = 0.0;
      final List<Map<String, dynamic>> newSaleLines = [];
      for (final e in remainingByLine.entries) {
        final lid = e.key;
        final remainQty = e.value;
        if (remainQty <= 0.000001) continue;
        final origLine = existingMap[lid];
        if (origLine == null) continue;
        final up = _toDouble(origLine['unit_price']);
        final purchasePrice = _toDouble(origLine['purchase_price']);
        final origDiscount = _toDouble(origLine['discount'] ?? 0.0);
        final origQty = _toDouble(origLine['quantity']);
        final discountPerUnit = (origQty > 0) ? (origDiscount / origQty) : 0.0;
        final newDiscount = discountPerUnit * remainQty;
        final newLineTotal =
            double.parse(((up * remainQty) - newDiscount).toStringAsFixed(4));
        newSaleTotal += newLineTotal;

        newSaleLines.add({
          'product_id': (origLine['product_id'] is int)
              ? origLine['product_id']
              : int.tryParse(origLine['product_id']?.toString() ?? '') ?? 0,
          'quantity': remainQty,
          'unit_price': up,
          'purchase_price': purchasePrice,
          'discount': double.parse(newDiscount.toStringAsFixed(4)),
          'line_total': newLineTotal,
          'warehouse_id': (origLine['warehouse_id'] is int)
              ? origLine['warehouse_id']
              : int.tryParse(origLine['warehouse_id']?.toString() ?? '') ?? 0,
        });
      }

      final newSaleMap = <String, dynamic>{
        'invoice_no': newInvoiceNo,
        'customer_id': origSale['customer_id'],
        'total': double.parse(newSaleTotal.toStringAsFixed(4)),
        'notes': 'Split from sale:$saleId — original invoice: $origInvoiceNo',
        'actor': origSale['actor'],
        'created_at': now,
      };
      final newSaleId = await txn.insert('sales', newSaleMap);

      for (final l in newSaleLines) {
        final toInsert = Map<String, dynamic>.from(l);
        toInsert['sale_id'] = newSaleId;
        await txn.insert('sale_lines', toInsert);
      }

      try {
        await txn
            .delete('sale_lines', where: 'sale_id = ?', whereArgs: [saleId]);
      } catch (_) {}

      try {
        final oldNotes = origSale['notes']?.toString() ?? '';
        final newNotes =
            '$oldNotes\n[cancelled: split to sale:$newSaleId via return:$returnId]';
        await txn.update('sales', {'total': 0.0, 'notes': newNotes},
            where: 'id = ?', whereArgs: [saleId]);
      } catch (_) {}

      return returnId;
    });
  }

  // ---------- services wrappers (محصول=product, خدمت=service) ----------
  /// ذخیرهٔ خدمت (insert/update)
  static Future<int> saveService(Map<String, dynamic> item) async {
    try {
      final d = await db;
      return await services_dao.saveService(d, item);
    } catch (_) {
      rethrow;
    }
  }

  /// لیست خدمات
  static Future<List<Map<String, dynamic>>> getServices({String? q}) async {
    try {
      final d = await db;
      return await services_dao.getServices(d, q: q);
    } catch (_) {
      return [];
    }
  }

  /// گرفتن خدمت بر اساس id
  static Future<Map<String, dynamic>?> getServiceById(int id) async {
    final d = await db;
    return await services_dao.getServiceById(d, id);
  }

  /// حذف خدمت
  static Future<int> deleteService(int id) async {
    final d = await db;
    return await services_dao.deleteService(d, id);
  }

  /// گرفتن لیست مشترکِ قابل فروش (محصولات + خدمات)
  static Future<List<Map<String, dynamic>>> getSellableItems(
      {String? q}) async {
    final d = await db;
    final out = <Map<String, dynamic>>[];
    try {
      // محصولات
      final prods = await products_dao.getProducts(d, q: q);
      for (final p in prods) {
        final mapped = Map<String, dynamic>.from(p);
        mapped['is_service'] = false;
        mapped['price'] = (mapped['price'] is num)
            ? (mapped['price'] as num).toDouble()
            : double.tryParse(mapped['price']?.toString() ?? '') ?? 0.0;
        mapped['sku'] = mapped['sku'] ?? mapped['product_code'] ?? '';
        out.add(mapped);
      }
    } catch (_) {}
    try {
      final servs = await services_dao.getServices(d, q: q);
      for (final s in servs) {
        final mapped = Map<String, dynamic>.from(s);
        mapped['is_service'] = true;
        mapped['sku'] = mapped['code'] ?? '';
        mapped['price'] = (mapped['price'] is num)
            ? (mapped['price'] as num).toDouble()
            : double.tryParse(mapped['price']?.toString() ?? '') ?? 0.0;
        out.add(mapped);
      }
    } catch (_) {}
    out.sort((a, b) {
      final an = (a['name']?.toString() ?? '').toLowerCase();
      final bn = (b['name']?.toString() ?? '').toLowerCase();
      return an.compareTo(bn);
    });
    return out;
  }

  /// گرفتن یک آیتم قابل فروش توسط id — ابتدا در products نگاه میکند، سپس در services
  static Future<Map<String, dynamic>?> getSellableItemById(int id) async {
    final d = await db;
    try {
      final p = await products_dao.getProductById(d, id);
      if (p != null) {
        final mapped = Map<String, dynamic>.from(p);
        mapped['is_service'] = false;
        mapped['price'] = (mapped['price'] is num)
            ? (mapped['price'] as num).toDouble()
            : double.tryParse(mapped['price']?.toString() ?? '') ?? 0.0;
        mapped['sku'] = mapped['sku'] ?? mapped['product_code'] ?? '';
        return mapped;
      }
    } catch (_) {}
    try {
      final s = await services_dao.getServiceById(d, id);
      if (s != null) {
        final mapped = Map<String, dynamic>.from(s);
        mapped['is_service'] = true;
        mapped['sku'] = mapped['code'] ?? '';
        mapped['price'] = (mapped['price'] is num)
            ? (mapped['price'] as num).toDouble()
            : double.tryParse(mapped['price']?.toString() ?? '') ?? 0.0;
        return mapped;
      }
    } catch (_) {}
    return null;
  }

  // ================ helpers / compatibility ================
  // اگر خواستی متدهای بیشتر را همینجا اضافه میکنم؛ فعلاً همهٔ فراخوانیهای مورد نیاز صفحات اصلاحشده را پوشش دادیم.
}