// lib/src/core/db/mizan_db/db_core.dart
// مدیریت باز و بسته کردن دیتابیس و تعیین مسیر فایل DB.
// - مسئولیت: init، setDbPath، get db و مسیر فعلی.
// - کامنت فارسی مختصر برای هر تابع.

import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/config_manager.dart';
import '../daos/requests_dao.dart' as requests_dao;
import '../daos/license_dao.dart' as license_dao;
import '../daos/business_dao.dart' as business_dao;
import '../daos/persons_dao.dart' as persons_dao;
import '../daos/categories_dao.dart' as categories_dao;
import '../daos/products_dao.dart' as products_dao;
import '../daos/inventory_dao.dart' as inventory_dao;
import '../daos/warehouses_dao.dart' as warehouses_dao;
import '../daos/sales_dao.dart' as sales_dao;
import '../daos/categories_persons_dao.dart' as persons_cat_dao;
import '../daos/categories_products_dao.dart' as products_cat_dao;
import '../daos/persons_meta_dao.dart' as persons_meta_dao;

class DbCore {
  DbCore._();
  static Database? _db;
  static String? _dbFilePath;
  static const int _version = 8;
  static const String _defaultDbFileName = 'mizan.db';

  // باز کردن/مقداردهی اولیه دیتابیس
  static Future<void> init() async {
    if (_db != null) return;

    try {
      final cfgPath = await ConfigManager.getDbFilePath();
      if (cfgPath != null && cfgPath.trim().isNotEmpty) {
        _dbFilePath = cfgPath;
        await _openDatabaseAtPath(_dbFilePath!);
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
        return;
      } catch (_) {}
    }

    try {
      final fallback = await _computeAppSupportPath();
      await setDbPath(fallback);
      return;
    } catch (e) {
      throw Exception(
          'عدم امکان تعیین مسیر دیتابیس به‌صورت خودکار: $e. مجوزها/مسیرها را بررسی کن.');
    }
  }

  static Future<String?> _computeInstallFolderPath() async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final exe = Platform.resolvedExecutable;
        final exeDir = File(exe).parent.path;
        final candidateDir = join(exeDir, 'mizan_data');
        final candidatePath = join(candidateDir, _defaultDbFileName);

        final dir = Directory(candidateDir);
        if (!await dir.exists()) await dir.create(recursive: true);
        // ایجاد تست فایل
        final f = File(candidatePath);
        if (!await f.exists()) {
          await f.create();
          await f.delete();
        } else {
          final raf = await f.open(mode: FileMode.append);
          await raf.close();
        }
        return candidatePath;
      }
    } catch (_) {}
    return null;
  }

  static Future<String> _computeAppSupportPath() async {
    final dir = await getApplicationSupportDirectory();
    final dataDir = join(dir.path, 'mizan_data');
    final d = Directory(dataDir);
    if (!await d.exists()) await d.create(recursive: true);
    return join(dataDir, _defaultDbFileName);
  }

  static Future<void> _openDatabaseAtPath(String fullPath) async {
    try {
      final dir = Directory(dirname(fullPath));
      if (!await dir.exists()) await dir.create(recursive: true);
    } catch (e) {
      throw Exception('خطا در آماده‌سازی مسیر دیتابیس: $e');
    }

    try {
      _db = await openDatabase(
        fullPath,
        version: _version,
        onCreate: (db, version) async {
          // ایجاد جداول پایه با DAOها
          await requests_dao.createRequestsTable(db);
          await license_dao.createLicenseTable(db);
          await business_dao.createBusinessTable(db);
          await persons_dao.createPersonsTable(db);
          await categories_dao.createCategoriesTable(db);
          await products_dao.createProductsTables(db);
          await inventory_dao.createInventoryTables(db);
          await warehouses_dao.createWarehousesTable(db);
          await sales_dao.createSalesTables(db);

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

          // جداول مربوط به returns / profit_shares
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
          // مهاجرت محافظه‌کارانه DAOها
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

          // اطمینان از وجود جداول جدید
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

          try {
            await persons_cat_dao.migratePersonsCategoriesTable(db);
          } catch (_) {}
          try {
            await products_cat_dao.migrateProductsCategoriesTable(db);
          } catch (_) {}
          try {
            await persons_meta_dao.migratePersonsMetaTable(db);
          } catch (_) {}
        },
      );
      _dbFilePath = fullPath;
    } catch (e) {
      _db = null;
      throw Exception('ناتوانی در باز کردن/ایجاد فایل دیتابیس: $e');
    }
  }

  // تغییر مسیر دیتابیس (public)
  static Future<void> setDbPath(String fullPath) async {
    Database? newDb;
    try {
      final dir = Directory(dirname(fullPath));
      if (!await dir.exists()) await dir.create(recursive: true);

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

          // ensure
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
          } catch (_) {}
        },
      );
    } catch (e) {
      try {
        if (newDb != null && newDb.isOpen) await newDb.close();
      } catch (_) {}
      throw Exception('تنظیم مسیر دیتابیس ناموفق بود: $e');
    }

    try {
      if (_db != null && _db!.isOpen) await _db!.close();
    } catch (_) {}
    _db = newDb;
    _dbFilePath = fullPath;
    try {
      await ConfigManager.setDbFilePath(fullPath);
    } catch (_) {}
  }

  static Future<String?> getCurrentDbFilePath() async {
    if (_dbFilePath != null) return _dbFilePath;
    return await ConfigManager.getDbFilePath();
  }

  static Future<Database> get db async {
    if (_db == null) {
      throw Exception(
          'دیتابیس مقداردهی نشده است. ابتدا DbCore.init() را اجرا کن.');
    }
    return _db!;
  }
}
