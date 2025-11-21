// lib/src/core/db/database_facade.dart
// Façade دیتابیس: همهٔ متدهایی که صفحات از AppDatabase انتظار دارند اینجا قرار دارند.
// - از database_init.dart برای init/open/close استفاده میکند.
// - getter عمومی `db` برای سازگاری با کدهای فعلی ارائه شده است.
// - تمام wrapperها thin wrappers هستند و منطق DB در DAOها قرار دارد.
// کامنت‌های فارسی مختصر برای هر بخش اضافه شده است.

import 'dart:async';
import 'package:sqflite/sqflite.dart';

// init module: مدیریت مسیر و باز/بستن دیتابیس
import 'database_init.dart' as db_init;

// DAOها
import 'daos/requests_dao.dart' as requests_dao;
import 'daos/license_dao.dart' as license_dao;
import 'daos/business_dao.dart' as business_dao;
import 'daos/persons_dao.dart' as persons_dao;
import 'daos/persons_meta_dao.dart' as persons_meta_dao;
import 'daos/categories_dao.dart' as categories_dao;
import 'daos/categories_persons_dao.dart' as persons_cat_dao;
import 'daos/categories_products_dao.dart' as products_cat_dao;
import 'daos/products_dao.dart' as products_dao;
import 'daos/inventory_dao.dart' as inventory_dao;
import 'daos/warehouses_dao.dart' as warehouses_dao;
import 'daos/sales_dao.dart' as sales_dao;

/// AppDatabase facade: کلاس استاتیک شامل init و wrapperها
class AppDatabase {
  AppDatabase._(); // جلوگیری از نمونه‌سازی

  // ---------- Init / Path management ----------
  /// مقداردهی دیتابیس؛ فراخوانی در main باید قبل از اجرای UI انجام شود.
  static Future<void> init() async => await db_init.init();

  /// تغییر مسیر دیتابیس در زمان اجرا (validate قبل از ذخیره)
  static Future<void> setDbPath(String path) async =>
      await db_init.setDbPath(path);

  /// مسیر فعلی فایل دیتابیس (اگر وجود داشته باشد)
  static Future<String?> getCurrentDbFilePath() async =>
      await db_init.getCurrentDbFilePath();

  /// بستن دیتابیس
  static Future<void> close() async => await db_init.close();

  // ---------- Public db getter ----------
  /// getter عمومی که صفحات از آن استفاده می‌کنند: await AppDatabase.db
  static Future<Database> get db async => await db_init.db;

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

  // ================= Persons meta (shareholders/types) =================
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

  // ================= Categories =================
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

  // ================= Person/Product categories =================
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

  // ================= Products / Units =================
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

  // ================= Inventory / Stock =================
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

  static Future<int> registerStockMovement(
      {required int itemId,
      required int warehouseId,
      required String type,
      required double qty,
      String? reference,
      String? notes,
      String? actor}) async {
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
    final levels =
        await getStockLevels(warehouseId: warehouseId, itemId: itemId);
    if (levels.isEmpty) return 0.0;
    final q = levels.first['quantity'];
    if (q == null) return 0.0;
    if (q is num) return q.toDouble();
    return double.tryParse(q.toString()) ?? 0.0;
  }

  // ================= Warehouses =================
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

  // ================= Sales =================
  static Future<int> saveSale(
      Map<String, dynamic> sale, List<Map<String, dynamic>> lines) async {
    final d = await db;
    return await sales_dao.saveSale(d, sale, lines);
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
}
