// lib/src/core/db/inventory_repository.dart
// لایهٔ میانی (Repository) برای عملیات انبار/موجودی — پیاده‌سازی کامل و مستقل
// - تمام متدهایی که صفحات مختلف اپ انتظار دارند (از جمله updateStockMovement/deleteStockMovement/getWarehouses) اینجا پیاده‌سازی شده‌اند.
// - هیچ ارجاع به توابع ناموجود زده نمیشود؛ اگر DAO متدی نداشت، در این Repository پیاده‌سازی انجام میشود.
// - پس از تغییر/حذف حرکت‌ها، بازمحاسبه (recompute) سطوح مربوط انجام میشود.
// - همهٔ فراخوانی‌ها ایمن (try/catch) شده‌اند تا در صورت مشکلات دیتابیس اپ کرش نکند.
// - کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'package:sqflite/sqflite.dart';
import 'app_database.dart';
import 'daos/inventory_dao.dart' as inventory_dao;

class InventoryRepository {
  InventoryRepository._();

  /// اطمینان از مقداردهی/مهاجرت جداول انبار.
  static Future<void> ensureInitialized() async {
    try {
      await AppDatabase.init();
      final db = await AppDatabase.db;
      try {
        await inventory_dao.migrateInventoryTables(db);
      } catch (_) {
        try {
          await inventory_dao.createInventoryTables(db);
        } catch (_) {}
      }
    } catch (e) {
      // پرتاب به caller تا UI پیام مناسب نشان دهد
      rethrow;
    }
  }

  // ---------- Inventory items ----------
  static Future<List<Map<String, dynamic>>> getInventoryItems(
      {String? q}) async {
    try {
      final d = await AppDatabase.db;
      return await inventory_dao.getInventoryItems(d, q: q);
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getInventoryItemById(int id) async {
    try {
      final d = await AppDatabase.db;
      return await inventory_dao.getInventoryItemById(d, id);
    } catch (e) {
      return null;
    }
  }

  static Future<int> saveInventoryItem(Map<String, dynamic> item) async {
    try {
      final d = await AppDatabase.db;
      return await inventory_dao.saveInventoryItem(d, item);
    } catch (e) {
      rethrow;
    }
  }

  static Future<int> deleteInventoryItem(int id) async {
    try {
      final d = await AppDatabase.db;
      return await inventory_dao.deleteInventoryItem(d, id);
    } catch (e) {
      rethrow;
    }
  }

  // ---------- Stock movements ----------
  /// ثبت حرکت جدید (in/out)
  static Future<int> registerStockMovement({
    required int itemId,
    required int warehouseId,
    required String type,
    required double qty,
    String? reference,
    String? notes,
    String? actor,
  }) async {
    try {
      // استفاده از facade AppDatabase (که خودش DAO را فراخوانی میکند)
      return await AppDatabase.registerStockMovement(
        itemId: itemId,
        warehouseId: warehouseId,
        type: type,
        qty: qty,
        reference: reference,
        notes: notes,
        actor: actor,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// بروزرسانی حرکت موجودی — پس از آپدیت بازمحاسبه سطوح انجام میشود
  static Future<int> updateStockMovement(
      int id, Map<String, dynamic> changes) async {
    final d = await AppDatabase.db;
    return await d.transaction<int>((txn) async {
      // خواندن ردیف فعلی
      final existing = await txn.query('stock_movements',
          where: 'id = ?', whereArgs: [id], limit: 1);
      if (existing.isEmpty) {
        throw Exception('رکورد حرکت موجودی یافت نشد (id=$id)');
      }
      final prev = Map<String, dynamic>.from(existing.first);
      final prevItemId = (prev['item_id'] is int)
          ? prev['item_id'] as int
          : int.tryParse(prev['item_id']?.toString() ?? '') ?? 0;
      final prevWarehouseId = (prev['warehouse_id'] is int)
          ? prev['warehouse_id'] as int
          : int.tryParse(prev['warehouse_id']?.toString() ?? '') ?? 0;

      // اعمال آپدیت
      final affected = await txn
          .update('stock_movements', changes, where: 'id = ?', whereArgs: [id]);

      // تعیین جفت نهایی برای محاسبه مجدد (اگر item_id/warehouse_id تغییر کرده باشد)
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

      // بازمحاسبه برای زوج قبلی و زوج جدید (اگر تغییر کرده)
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

  /// حذف حرکت موجودی — پس از حذف بازمحاسبه سطوح انجام میشود.
  static Future<int> deleteStockMovement(int id) async {
    final d = await AppDatabase.db;
    return await d.transaction<int>((txn) async {
      final rows = await txn.query('stock_movements',
          where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return 0;
      final r = rows.first;
      final itemId = (r['item_id'] is int)
          ? r['item_id'] as int
          : int.tryParse(r['item_id']?.toString() ?? '') ?? 0;
      final warehouseId = (r['warehouse_id'] is int)
          ? r['warehouse_id'] as int
          : int.tryParse(r['warehouse_id']?.toString() ?? '') ?? 0;

      final deleted =
          await txn.delete('stock_movements', where: 'id = ?', whereArgs: [id]);

      // بازمحاسبه سطح آن زوج
      try {
        await inventory_dao.recomputeStockLevelsForPair(
            txn, itemId, warehouseId);
      } catch (_) {}

      return deleted;
    });
  }

  // ---------- Query / Helpers ----------
  static Future<List<Map<String, dynamic>>> getStockMovements(
      {int? warehouseId, int? itemId, int limit = 100, int offset = 0}) async {
    try {
      final d = await AppDatabase.db;
      return await inventory_dao.getStockMovements(d,
          warehouseId: warehouseId,
          itemId: itemId,
          limit: limit,
          offset: offset);
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getStockLevels(
      {int? warehouseId, int? itemId}) async {
    try {
      final d = await AppDatabase.db;
      return await inventory_dao.getStockLevels(d,
          warehouseId: warehouseId, itemId: itemId);
    } catch (_) {
      return [];
    }
  }

  /// بازگرداندن لیست انبارها — wrapper برای AppDatabase.getWarehouses (سازگاری با صفحات)
  static Future<List<Map<String, dynamic>>> getWarehouses() async {
    try {
      return await AppDatabase.getWarehouses();
    } catch (_) {
      return [];
    }
  }

  /// گرفتن مقدار موجودی برای یک کالا در یک انبار (warehouseId==0 => جمع همه انبارها)
  static Future<double> getQtyForItemInWarehouse(
      int itemId, int warehouseId) async {
    try {
      return await AppDatabase.getQtyForItemInWarehouse(itemId, warehouseId);
    } catch (_) {
      return 0.0;
    }
  }

  /// بازمحاسبه کلی سطوح (برای مواقعی که به recompute کلی نیاز است)
  static Future<void> recomputeStockLevels() async {
    try {
      final d = await AppDatabase.db;
      await inventory_dao.recomputeStockLevels(d);
    } catch (_) {}
  }
}
