// lib/src/core/db/app_database.dart
// Façade یکپارچهٔ دیتابیس sqlite برای پروژه — نسخهٔ کامل و سازگار با ساختار فعلی ریپو
// توضیح خیلی خیلی کوتاه: این فایل wrapper کامل دیتابیس را فراهم می‌کند:
// - init / setDbPath / get db
// - ایجاد و مهاجرت جداول به‌صورت محافظه‌کارانه
// - wrapper برای DAOها (persons, products, inventory, sales, services و ...)
// - ثبت حرکت انبار با بازسازی سطح موجودی (recompute) و تراکنش امن
// - ساختار طوری نوشته شده که با daoهای موجود در lib/src/core/db/daos/* کار کند.
// کامنت‌های فارسی مختصر در هر بخش قرار داده شده‌اند.

import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../config/config_manager.dart';
import 'package:path_provider/path_provider.dart';

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
import 'daos/services_dao.dart' as services_dao;

export 'database.dart';

class AppDatabase {
  AppDatabase._();

  static Database? _db;
  static String? _dbFilePath;
  static const int _version = 8;
  static const String _defaultDbFileName = 'mizan.db';

  // -------------------- Init --------------------
  static Future<void> init() async {
    if (_db != null) return;

    try {
      final cfgPath = await ConfigManager.getDbFilePath();
      if (cfgPath != null && cfgPath.trim().isNotEmpty) {
        _dbFilePath = cfgPath;
        await _openDatabaseAtPath(_dbFilePath!);
        await _postOpenMigrations();
        return;
      }
    } catch (_) {}

    // try install folder
    String? candidate;
    try {
      candidate = await _computeInstallFolderPath();
    } catch (_) {
      candidate = null;
    }

    if (candidate != null) {
      try {
        await setDbPath(candidate);
        await _postOpenMigrations();
        return;
      } catch (_) {}
    }

    // fallback to app support path
    try {
      final fallback = await _computeAppSupportPath();
      await setDbPath(fallback);
      await _postOpenMigrations();
      return;
    } catch (e) {
      throw Exception('عدم امکان تعیین مسیر دیتابیس: $e');
    }
  }

  // compute install folder for desktop
  static Future<String?> _computeInstallFolderPath() async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final exe = Platform.resolvedExecutable;
        final exeDir = File(exe).parent.path;
        final candidateDir = join(exeDir, 'mizan_data');
        final candidatePath = join(candidateDir, _defaultDbFileName);
        final dir = Directory(candidateDir);
        if (!await dir.exists()) await dir.create(recursive: true);
        return candidatePath;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _computeAppSupportPath() async {
    final dir = await getApplicationSupportDirectory();
    final dataDir = join(dir.path, 'mizan_data');
    final d = Directory(dataDir);
    if (!await d.exists()) await d.create(recursive: true);
    return join(dataDir, _defaultDbFileName);
  }

  // open database (create + onOpen migrations)
  static Future<void> _openDatabaseAtPath(String fullPath) async {
    try {
      final dir = Directory(dirname(fullPath));
      if (!await dir.exists()) await dir.create(recursive: true);
    } catch (e) {
      throw Exception('عدم امکان ایجاد دایرکتوری دیتابیس: $e');
    }

    try {
      _db = await openDatabase(
        fullPath,
        version: _version,
        onCreate: (db, version) async {
          // ایجاد جداول پایه توسط DAOها (هر DAO مسئول جداول خودش است)
          await requests_dao.createRequestsTable(db);
          await license_dao.createLicenseTable(db);
          await business_dao.createBusinessTable(db);
          await persons_dao.createPersonsTable(db);
          await categories_dao.createCategoriesTable(db);
          await products_dao.createProductsTables(db);
          await inventory_dao.createInventoryTables(db);
          await warehouses_dao.createWarehousesTable(db);
          await sales_dao.createSalesTables(db);
          try {
            await services_dao.createServicesTable(db);
          } catch (_) {}

          // جداول کمکی جدید و محافظه‌کارانه
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

          // مهاجرت محافظه‌کارانه جداول meta
          try {
            await persons_meta_dao.migratePersonsMetaTable(db);
          } catch (_) {}
        },
        onOpen: (db) async {
          // onOpen: اجرا/مهاجرت محافظه‌کارانه برای هر DAO
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
      throw Exception('ناتوانی در باز کردن/ایجاد فایل دیتابیس در مسیر "$fullPath": $e');
    }
  }

  // پس از open: اجرای migrations اضافی محافظه‌کارانه
  static Future<void> _postOpenMigrations() async {
    try {
      final d = await db;
      await _ensureReturnsAndProfitTables();
      await _migrateSalesSchema(d);
      // سایر مهاجرتهای محافظه‌کارانه DAOها
      try {
        await services_dao.migrateServicesTable(d);
      } catch (_) {}
    } catch (_) {}
  }

  // ایجاد جداول کمکی اگر وجود ندارند
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
    } catch (_) {}
  }

  // -------------------- setDbPath (تغییر دستی مسیر دیتابیس) --------------------
  static Future<void> setDbPath(String fullPath) async {
    Database? newDb;
    try {
      final dir = Directory(dirname(fullPath));
      if (!await dir.exists()) await dir.create(recursive: true);
      newDb = await openDatabase(
        fullPath,
        version: _version,
        onCreate: (db, version) async {
          // create as in _openDatabaseAtPath
          await requests_dao.createRequestsTable(db);
          await license_dao.createLicenseTable(db);
          await business_dao.createBusinessTable(db);
          await persons_dao.createPersonsTable(db);
          await categories_dao.createCategoriesTable(db);
          await products_dao.createProductsTables(db);
          await inventory_dao.createInventoryTables(db);
          await warehouses_dao.createWarehousesTable(db);
          await sales_dao.createSalesTables(db);
          try {
            await services_dao.createServicesTable(db);
          } catch (_) {}
          await persons_cat_dao.createPersonsCategoriesTable(db);
          await products_cat_dao.createProductsCategoriesTable(db);
        },
        onOpen: (db) async {
          // migrate
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

  // -------------------- getCurrentDbFilePath --------------------
  static Future<String?> getCurrentDbFilePath() async {
    if (_dbFilePath != null) return _dbFilePath;
    return await ConfigManager.getDbFilePath();
  }

  // -------------------- db getter --------------------
  static Future<Database> get db async {
    if (_db == null) {
      throw Exception('دیتابیس مقداردهی نشده است. قبل از استفاده AppDatabase.init() را اجرا کنید.');
    }
    return _db!;
  }

  // -------------------- Utility helpers --------------------
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

  // -------------------- Requests / License / Business wrappers --------------------
  static Future<int> insertPendingRequest(Map<String, dynamic> item) async {
    final d = await db;
    return await requests_dao.insertPendingRequest(d, item);
  }

  static Future<List<Map<String, dynamic>>> getRequests({String? status}) async {
    final d = await db;
    return await requests_dao.getRequests(d, status: status);
  }

  static Future<int> saveLocalLicense(Map<String, dynamic> item) async {
    final d = await db;
    return await license_dao.saveLocalLicense(d, item);
  }

  static Future<Map<String, dynamic>?> getLocalLicense() async {
    final d = await db;
    return await license_dao.getLocalLicense(d);
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

  // -------------------- Persons wrappers --------------------
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

  static Future<int> updatePersonTypes(int personId, Map<String, dynamic> types) async {
    final d = await db;
    return await persons_meta_dao.updatePersonTypes(d, personId, types);
  }

  static Future<double> getPersonSharePercentage(int personId) async {
    final d = await db;
    return await persons_meta_dao.getPersonSharePercentage(d, personId);
  }

  // -------------------- Shifts --------------------
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

  static Future<Map<String, dynamic>?> getActiveShift({String? terminalId}) async {
    final d = await db;
    try {
      if (terminalId != null && terminalId.isNotEmpty) {
        final rows = await d.query('shifts',
            where: 'terminal_id = ? AND active = 1',
            whereArgs: [terminalId],
            limit: 1);
        if (rows.isNotEmpty) return Map<String, dynamic>.from(rows.first);
      }
      final rows = await d.query('shifts', where: 'active = 1', limit: 1);
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first);
    } catch (_) {
      return null;
    }
  }

  // -------------------- Categories / Products wrappers --------------------
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
    final d = await db;
    try {
      await d.delete('stock_levels', where: 'item_id = ?', whereArgs: [id]);
      await d.delete('stock_movements', where: 'item_id = ?', whereArgs: [id]);
    } catch (_) {}
    return await products_dao.deleteProduct(d, id);
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

  // -------------------- Inventory / Stock wrappers --------------------
  static Future<int> saveInventoryItem(Map<String, dynamic> item) async {
    final d = await db;
    return await inventory_dao.saveInventoryItem(d, item);
  }

  static Future<List<Map<String, dynamic>>> getInventoryItems({String? q}) async {
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
    required String type, // 'in' | 'out' | 'adjustment'
    required double qty, // always positive value
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

  static Future<int> updateStockMovement(int id, Map<String, dynamic> changes) async {
    final d = await db;
    return await d.transaction<int>((txn) async {
      final existing = await txn.query('stock_movements',
          where: 'id = ?', whereArgs: [id], limit: 1);
      if (existing.isEmpty) return 0;
      final prev = Map<String, dynamic>.from(existing.first);
      final prevItemId = (prev['item_id'] is int) ? prev['item_id'] as int : int.tryParse(prev['item_id']?.toString() ?? '') ?? 0;
      final prevWarehouseId = (prev['warehouse_id'] is int) ? prev['warehouse_id'] as int : int.tryParse(prev['warehouse_id']?.toString() ?? '') ?? 0;

      final affected = await txn.update('stock_movements', changes, where: 'id = ?', whereArgs: [id]);

      try {
        await inventory_dao.recomputeStockLevelsForPair(txn, prevItemId, prevWarehouseId);
      } catch (_) {}
      int finalItemId = prevItemId;
      int finalWarehouseId = prevWarehouseId;
      if (changes.containsKey('item_id')) {
        finalItemId = (changes['item_id'] is int) ? changes['item_id'] as int : int.tryParse(changes['item_id']?.toString() ?? '') ?? finalItemId;
      }
      if (changes.containsKey('warehouse_id')) {
        finalWarehouseId = (changes['warehouse_id'] is int) ? changes['warehouse_id'] as int : int.tryParse(changes['warehouse_id']?.toString() ?? '') ?? finalWarehouseId;
      }
      if (finalItemId != prevItemId || finalWarehouseId != prevWarehouseId) {
        try {
          await inventory_dao.recomputeStockLevelsForPair(txn, finalItemId, finalWarehouseId);
        } catch (_) {}
      }
      return affected;
    });
  }

  static Future<List<Map<String, dynamic>>> getStockLevels({int? warehouseId, int? itemId}) async {
    final d = await db;
    return await inventory_dao.getStockLevels(d, warehouseId: warehouseId, itemId: itemId);
  }

  static Future<List<Map<String, dynamic>>> getStockMovements({int? warehouseId, int? itemId, int limit = 100, int offset = 0}) async {
    final d = await db;
    return await inventory_dao.getStockMovements(d, warehouseId: warehouseId, itemId: itemId, limit: limit, offset: offset);
  }

  static Future<double> getQtyForItemInWarehouse(int itemId, int warehouseId) async {
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
      final levels = await getStockLevels(warehouseId: warehouseId, itemId: itemId);
      if (levels.isEmpty) return 0.0;
      final q = levels.first['quantity'];
      if (q == null) return 0.0;
      if (q is num) return q.toDouble();
      return double.tryParse(q.toString()) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  // -------------------- Warehouses --------------------
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

  // -------------------- Sales wrappers --------------------
  static Future<int> saveSale(Map<String, dynamic> sale, List<Map<String, dynamic>> lines) async {
    final d = await db;
    final id = await sales_dao.saveSale(d, sale, lines);
    try {
      await createProfitSharesForSale(d, id);
    } catch (_) {}
    return id;
  }

  static Future<List<Map<String, dynamic>>> getSales({int limit = 100, int offset = 0}) async {
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

  static Future<int> setSalePaymentInfo(int saleId, Map<String, dynamic>? info) async {
    final d = await db;
    return await sales_dao.setSalePaymentInfo(d, saleId, info);
  }

  static Future<Map<String, dynamic>?> getSalePaymentInfo(int saleId) async {
    final d = await db;
    return await sales_dao.getSalePaymentInfo(d, saleId);
  }

  static Future<List<Map<String, dynamic>>> searchSales(String q, {int limit = 200}) async {
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

  // محاسبه و ایجاد ردیفهای profit_shares برای یک فاکتور جدید
  static Future<void> createProfitSharesForSale(Database d, int saleId) async {
    try {
      final lines = await d.query('sale_lines', where: 'sale_id = ?', whereArgs: [saleId]);
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
              final pid = (p['id'] is int) ? p['id'] as int : int.tryParse(p['id']?.toString() ?? '') ?? 0;
              final sp2 = await persons_meta_dao.getPersonSharePercentage(d, pid);
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
        final saleLineId = (ln['id'] is int) ? ln['id'] as int : int.tryParse(ln['id']?.toString() ?? '') ?? 0;
        final qty = _toDouble(ln['quantity']);
        final unitPrice = _toDouble(ln['unit_price']);
        final purchasePrice = _toDouble(ln['purchase_price']);
        final discount = _toDouble(ln['discount'] ?? 0.0);

        final discountPerUnit = (qty > 0) ? (discount / qty) : 0.0;
        final profitPerUnit = (unitPrice - purchasePrice);
        final profitLine = (profitPerUnit * qty) - (discountPerUnit * qty);

        if (profitLine.abs() < 0.000001) continue;

        for (final sh in shareholders) {
          final pid = (sh['id'] is int) ? sh['id'] as int : int.tryParse(sh['id']?.toString() ?? '') ?? 0;
          final percent = _toDouble(sh['share_percent'] ?? sh['shareholder_percentage'] ?? 0.0);
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
    } catch (_) {}
  }

  // -------------------- Services wrappers --------------------
  static Future<int> saveService(Map<String, dynamic> item) async {
    final d = await db;
    return await services_dao.saveService(d, item);
  }

  static Future<List<Map<String, dynamic>>> getServices({String? q}) async {
    final d = await db;
    return await services_dao.getServices(d, q: q);
  }

  static Future<Map<String, dynamic>?> getServiceById(int id) async {
    final d = await db;
    return await services_dao.getServiceById(d, id);
  }

  static Future<int> deleteService(int id) async {
    final d = await db;
    return await services_dao.deleteService(d, id);
  }

  // -------------------- Sellable items (products + services) --------------------
  static Future<List<Map<String, dynamic>>> getSellableItems({String? q}) async {
    final d = await db;
    final out = <Map<String, dynamic>>[];
    try {
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

  // -------------------- Sales schema migration --------------------
  // اضافه کردن ستون‌های مورد نیاز به جدول sales در صورت نبودن
  static Future<void> _migrateSalesSchema(Database db) async {
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
        'created_at': 'INTEGER',
        'notes': 'TEXT',
      };

      for (final entry in needed.entries) {
        final col = entry.key;
        final def = entry.value;
        if (!existingCols.contains(col.toLowerCase())) {
          try {
            await db.execute("ALTER TABLE sales ADD COLUMN $col $def");
          } catch (_) {
            // ignore
          }
        }
      }
    } catch (_) {}
  }
}