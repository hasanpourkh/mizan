// lib/src/core/db/database_schema.dart
// تعریف توابع createAllTables و migrateAllTables.
// - این فایل تنها مسئول ساخت جداول اولیه و اجرای مهاجرتهای محافظه‌کارانه است.
// - هدف: جدا کردن منطق schema از منطق init و facade تا خواناتر باشد.
// کامنت فارسی مختصر برای هر بخش.

import 'package:sqflite/sqflite.dart';

// DAOها (تابعهای create/migrate در این فایلها قرار دارند)
import 'daos/business_dao.dart' as business_dao;
import 'daos/requests_dao.dart' as requests_dao;
import 'daos/license_dao.dart' as license_dao;
import 'daos/persons_dao.dart' as persons_dao;
import 'daos/categories_dao.dart' as categories_dao;
import 'daos/products_dao.dart' as products_dao;
import 'daos/inventory_dao.dart' as inventory_dao;
import 'daos/warehouses_dao.dart' as warehouses_dao;
import 'daos/sales_dao.dart' as sales_dao;
import 'daos/categories_persons_dao.dart' as persons_cat_dao;
import 'daos/categories_products_dao.dart' as products_cat_dao;
import 'daos/persons_meta_dao.dart' as persons_meta_dao;

/// ایجاد تمامی جداول پایه‌ای (فقط در onCreate اجرا میشود)
Future<void> createAllTables(Database db) async {
  // جداول پایه
  await business_dao.createBusinessTable(db);
  await requests_dao.createRequestsTable(db);
  await license_dao.createLicenseTable(db);
  await persons_dao.createPersonsTable(db);
  await categories_dao.createCategoriesTable(db);

  // محصولات/انبار/انبارها/فروش
  await products_dao.createProductsTables(db);
  await inventory_dao.createInventoryTables(db);
  await warehouses_dao.createWarehousesTable(db);
  await sales_dao.createSalesTables(db);

  // دسته‌بندی‌های مرتبط
  await persons_cat_dao.createPersonsCategoriesTable(db);
  await products_cat_dao.createProductsCategoriesTable(db);

  // مهاجرت meta اشخاص (اختیاری)
  try {
    await persons_meta_dao.migratePersonsMetaTable(db);
  } catch (_) {}
}

/// اجرای مهاجرت‌های محافظه‌کارانه هنگام باز شدن دیتابیس
Future<void> migrateAllTables(Database db) async {
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
    await persons_cat_dao.migratePersonsCategoriesTable(db);
  } catch (_) {}
  try {
    await products_cat_dao.migrateProductsCategoriesTable(db);
  } catch (_) {}
  try {
    await persons_meta_dao.migratePersonsMetaTable(db);
  } catch (_) {}
}
