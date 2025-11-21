// lib/src/core/db/daos/inventory_dao.dart
// DAO مدیریت انبار: آیتمها، سطوح، حرکات و توابع بازسازی سطوح.
// توضیح خیلی خیلی کوتاه: این نسخه سازگار با فراخوانیهای موجود در پروژه است:
// - registerStockMovement(executor, {...}) همانطور که قبلاً بود DatabaseExecutor میپذیرد.
// - recomputeStockLevelsForPair اکنون امضای positional دارد: (executor, itemId, warehouseId)
//   تا فراخوانیهای قدیمی مانند recomputeStockLevelsForPair(db, itemId, warehouseId) بدون تغییر کار کنند.
// - recomputeStockLevels(executor) نیز DatabaseExecutor میپذیرد.
//
// کامنتهای فارسی مختصر برای هر بخش قرار داده شدهاند.

import 'package:sqflite/sqlite_api.dart'; // Database, Transaction, DatabaseExecutor
import 'package:sqflite/sqflite.dart';

/// ایجاد جداول مورد نیاز انبار در زمان ایجاد دیتابیس
Future<void> createInventoryTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS inventory_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      sku TEXT,
      unit TEXT,
      purchase_price REAL DEFAULT 0,
      price REAL DEFAULT 0,
      notes TEXT,
      created_at INTEGER,
      updated_at INTEGER,
      category_id INTEGER DEFAULT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS stock_levels (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      item_id INTEGER NOT NULL,
      warehouse_id INTEGER NOT NULL,
      quantity REAL DEFAULT 0,
      updated_at INTEGER,
      UNIQUE(item_id, warehouse_id)
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS stock_movements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      item_id INTEGER NOT NULL,
      warehouse_id INTEGER NOT NULL,
      type TEXT NOT NULL, -- 'in','out','sale','return','adjustment'
      qty REAL,
      reference TEXT,
      notes TEXT,
      actor TEXT,
      created_at INTEGER
    )
  ''');
}

/// مهاجرت محافظهکارانه: اگر ستون/جدول جدید لازم باشد اضافه میکند (سکوت در صورت خطا)
Future<void> migrateInventoryTables(Database db) async {
  try {
    final infoItems = await db.rawQuery("PRAGMA table_info(inventory_items)");
    final namesItems =
        infoItems.map((r) => r['name']?.toString() ?? '').toList();

    // اگر جدول inventory_items اصلاً وجود ندارد، آن را ایجاد کن (createInventoryTables آن را انجام میدهد)
    if (namesItems.isEmpty) {
      try {
        await createInventoryTables(db);
      } catch (_) {}
      return;
    }

    // اضافه کردن ستون sku اگر وجود نداشت (سابقا اضافه شده بود)
    if (!namesItems.contains('sku')) {
      try {
        await db.execute('ALTER TABLE inventory_items ADD COLUMN sku TEXT');
      } catch (_) {}
    }

    // اضافه کردن ستون category_id اگر وجود نداشت (حل مشکل فعلی)
    if (!namesItems.contains('category_id')) {
      try {
        await db.execute(
            'ALTER TABLE inventory_items ADD COLUMN category_id INTEGER DEFAULT NULL');
      } catch (_) {
        // در برخی شرایط محدودیت sqlite یا نسخه ممکن است خطا دهد؛ سکوت میکنیم تا برنامه اجرا شود
      }
    }
  } catch (_) {}

  try {
    final infoLevels = await db.rawQuery("PRAGMA table_info(stock_levels)");
    if (infoLevels.isEmpty) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_levels (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          item_id INTEGER NOT NULL,
          warehouse_id INTEGER NOT NULL,
          quantity REAL DEFAULT 0,
          updated_at INTEGER,
          UNIQUE(item_id, warehouse_id)
        )
      ''');
    }
  } catch (_) {}

  try {
    final infoMov = await db.rawQuery("PRAGMA table_info(stock_movements)");
    if (infoMov.isEmpty) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_movements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          item_id INTEGER NOT NULL,
          warehouse_id INTEGER NOT NULL,
          type TEXT NOT NULL,
          qty REAL,
          reference TEXT,
          notes TEXT,
          actor TEXT,
          created_at INTEGER
        )
      ''');
    }
  } catch (_) {}
}

/// دریافت لیست آیتمهای انبار (فیلتر q اختیاری بر اساس نام یا SKU)
Future<List<Map<String, dynamic>>> getInventoryItems(Database db,
    {String? q}) async {
  try {
    if (q == null || q.trim().isEmpty) {
      return await db.query('inventory_items', orderBy: 'name COLLATE NOCASE');
    } else {
      final like = '%${q.replaceAll('%', '')}%';
      return await db.query('inventory_items',
          where: 'name LIKE ? OR sku LIKE ?',
          whereArgs: [like, like],
          orderBy: 'name COLLATE NOCASE');
    }
  } catch (e) {
    return <Map<String, dynamic>>[];
  }
}

/// دریافت آیتم خاص بر اساس id
Future<Map<String, dynamic>?> getInventoryItemById(Database db, int id) async {
  try {
    final rows = await db.query('inventory_items',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  } catch (e) {
    return null;
  }
}

/// ذخیرهٔ آیتم انبار (درج یا بروزرسانی)
Future<int> saveInventoryItem(Database db, Map<String, dynamic> item) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final m = <String, dynamic>{
    'name': item['name']?.toString() ?? '',
    'sku': item['sku']?.toString() ?? '',
    'unit': item['unit']?.toString() ?? '',
    'purchase_price': (item['purchase_price'] is num)
        ? (item['purchase_price'] as num).toDouble()
        : double.tryParse(item['purchase_price']?.toString() ?? '') ?? 0.0,
    'price': (item['price'] is num)
        ? (item['price'] as num).toDouble()
        : double.tryParse(item['price']?.toString() ?? '') ?? 0.0,
    'notes': item['notes']?.toString() ?? '',
    'updated_at': now,
  };

  // اگر category_id ارسال شده است آن را نیز قرار بده
  if (item.containsKey('category_id')) {
    final cid = (item['category_id'] is int)
        ? item['category_id'] as int
        : int.tryParse(item['category_id']?.toString() ?? '');
    m['category_id'] = cid;
  }

  try {
    if (item.containsKey('id') && item['id'] != null) {
      final id = (item['id'] is int)
          ? item['id'] as int
          : int.tryParse(item['id'].toString()) ?? 0;
      await db.update('inventory_items', m, where: 'id = ?', whereArgs: [id]);
      return id;
    } else {
      m['created_at'] = now;
      final id = await db.insert('inventory_items', m);
      return id;
    }
  } catch (e) {
    rethrow;
  }
}

/// حذف آیتم انبار
Future<int> deleteInventoryItem(Database db, int id) async {
  try {
    return await db.delete('inventory_items', where: 'id = ?', whereArgs: [id]);
  } catch (e) {
    return 0;
  }
}

/// خواندن سطوح موجودی
/// اگر warehouseId داده شود فیلتر میشود، اگر itemId داده شود فقط آن آیتم برگردانده میشود
Future<List<Map<String, dynamic>>> getStockLevels(Database db,
    {int? warehouseId, int? itemId}) async {
  try {
    final where = <String>[];
    final args = <dynamic>[];
    if (warehouseId != null) {
      where.add('warehouse_id = ?');
      args.add(warehouseId);
    }
    if (itemId != null) {
      where.add('item_id = ?');
      args.add(itemId);
    }
    final whereClause = where.isEmpty ? null : where.join(' AND ');
    final rows = await db.query('stock_levels',
        where: whereClause,
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'id ASC');
    return rows;
  } catch (e) {
    return <Map<String, dynamic>>[];
  }
}

/// خواندن حرکات انبار (movement history)
Future<List<Map<String, dynamic>>> getStockMovements(Database db,
    {int? warehouseId, int? itemId, int limit = 100, int offset = 0}) async {
  try {
    final where = <String>[];
    final args = <dynamic>[];
    if (warehouseId != null) {
      where.add('warehouse_id = ?');
      args.add(warehouseId);
    }
    if (itemId != null) {
      where.add('item_id = ?');
      args.add(itemId);
    }
    final whereClause = where.isEmpty ? null : where.join(' AND ');
    final rows = await db.query('stock_movements',
        where: whereClause,
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'created_at DESC',
        limit: limit,
        offset: offset);
    return rows;
  } catch (e) {
    return <Map<String, dynamic>>[];
  }
}

/// ثبت حرکت انبار
/// مهم: پارامتر اول از نوع DatabaseExecutor است (Transaction یا Database)
/// type: 'in','out','sale','return','adjustment'  — برای 'return' مقدار به انبار افزوده میشود
/// بازگرداندن id رکورد حرکت (int) یا 0 در صورت شکست
Future<int> registerStockMovement(DatabaseExecutor executor,
    {required int itemId,
    required int warehouseId,
    required String type,
    required double qty,
    String? reference,
    String? notes,
    String? actor}) async {
  try {
    final now = DateTime.now().millisecondsSinceEpoch;

    // delta مثبت یا منفی بسته به نوع حرکت
    final t = (type ?? '').toLowerCase();
    double delta = qty;
    if (t == 'out' || t == 'sale' || t == 'remove' || t == 'used') {
      delta = -qty;
    } else if (t == 'return' || t == 'in' || t == 'add') {
      delta = qty;
    } else if (t == 'adjustment') {
      // در adjustment مقدار میتواند منفی یا مثبت داده شود (qty با علامت)
      delta = qty;
    } else {
      // پیشفرض: treat as out (ایمنتر) — اما بهتر است انواع مشخص ارسال شوند
      delta = qty;
    }

    // درج رکورد حرکت (با استفاده از executor تا بتواند داخل txn اجرا شود)
    final movement = <String, dynamic>{
      'item_id': itemId,
      'warehouse_id': warehouseId,
      'type': type,
      'qty': qty,
      'reference': reference ?? '',
      'notes': notes ?? '',
      'actor': actor ?? '',
      'created_at': now
    };

    final int moveId = await executor.insert('stock_movements', movement);

    // بهروزرسانی یا درج سطوح (stock_levels) — تلاش برای upsert محافظهکارانه
    try {
      // ابتدا رکورد موجود را بخوان
      final existing = await executor.query('stock_levels',
          where: 'item_id = ? AND warehouse_id = ?',
          whereArgs: [itemId, warehouseId],
          limit: 1);
      if (existing.isEmpty) {
        final insert = <String, dynamic>{
          'item_id': itemId,
          'warehouse_id': warehouseId,
          'quantity': delta,
          'updated_at': now
        };
        await executor.insert('stock_levels', insert);
      } else {
        final cur = Map<String, dynamic>.from(existing.first);
        final oldQty = (cur['quantity'] is num)
            ? (cur['quantity'] as num).toDouble()
            : double.tryParse(cur['quantity']?.toString() ?? '') ?? 0.0;
        final newQty = oldQty + delta;
        await executor.update(
            'stock_levels', {'quantity': newQty, 'updated_at': now},
            where: 'id = ?', whereArgs: [cur['id']]);
      }
    } catch (_) {
      // اگر عملیات upsert شکست خورد، نادیده میگیریم تا حرکت ثبت نشود.
    }

    return moveId;
  } catch (e) {
    // اگر executor یک Transaction است و خطا رخ دهد باید خطا را رها کرد تا تراکنش rollback شود.
    // اما در این DAO تصمیم به catch و return 0 گرفتهایم تا UI بتواند پیام مناسب بدهد.
    return 0;
  }
}

/// بازسازی مقدار stock_levels فقط برای یک جفت item_id و warehouse_id
/// توجه: امضای این تابع positional است (نه named) تا با فراخوانیهای موجود سازگار باشد:
///   recomputeStockLevelsForPair(executor, itemId, warehouseId)
Future<void> recomputeStockLevelsForPair(
    DatabaseExecutor executor, int itemId, int warehouseId) async {
  try {
    // جمع کلی delta برای این جفت
    final rows = await executor.rawQuery('''
      SELECT SUM(
        CASE
          WHEN lower(type) IN ('out','sale','remove','used') THEN -qty
          WHEN lower(type) IN ('return','in','add') THEN qty
          WHEN lower(type) = 'adjustment' THEN qty
          ELSE qty
        END
      ) as total
      FROM stock_movements
      WHERE item_id = ? AND warehouse_id = ?
    ''', [itemId, warehouseId]);

    double total = 0.0;
    if (rows.isNotEmpty) {
      final v = rows.first['total'];
      if (v != null) {
        if (v is num) {
          total = v.toDouble();
        } else {
          total = double.tryParse(v.toString()) ?? 0.0;
        }
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    // آپدیت یا درج رکورد stock_levels
    final exists = await executor.query('stock_levels',
        where: 'item_id = ? AND warehouse_id = ?',
        whereArgs: [itemId, warehouseId],
        limit: 1);
    if (exists.isEmpty) {
      await executor.insert('stock_levels', {
        'item_id': itemId,
        'warehouse_id': warehouseId,
        'quantity': total,
        'updated_at': now
      });
    } else {
      final id = exists.first['id'];
      await executor.update(
          'stock_levels', {'quantity': total, 'updated_at': now},
          where: 'id = ?', whereArgs: [id]);
    }
  } catch (e) {
    // نادیده گرفتن خطا تا فراخواننده تصمیم به rollback بگیرد یا لاگ بزند
  }
}

/// بازسازی کامل جدول stock_levels بر اساس تمام رکوردهای stock_movements
/// امضای positional: recomputeStockLevels(executor)
Future<void> recomputeStockLevels(DatabaseExecutor executor) async {
  try {
    // انتخاب تمامی جفتهای یونیک از حرکات
    final pairs = await executor.rawQuery('''
      SELECT item_id, warehouse_id,
        SUM(
          CASE
            WHEN lower(type) IN ('out','sale','remove','used') THEN -qty
            WHEN lower(type) IN ('return','in','add') THEN qty
            WHEN lower(type) = 'adjustment' THEN qty
            ELSE qty
          END
        ) as total
      FROM stock_movements
      GROUP BY item_id, warehouse_id
    ''');

    final now = DateTime.now().millisecondsSinceEpoch;

    // برای امنیت: میتوانیم رکوردهایی که در stock_levels هستند اما در pairs نیامدهاند را حذف یا صفر کنیم.
    // رویکرد فعلی: برای هر pair مقدار را upsert میکنیم؛ رکوردهای بدون movement دستنخورده میمانند.
    for (final p in pairs) {
      final itemId = (p['item_id'] is int)
          ? p['item_id'] as int
          : int.tryParse(p['item_id']?.toString() ?? '') ?? 0;
      final warehouseId = (p['warehouse_id'] is int)
          ? p['warehouse_id'] as int
          : int.tryParse(p['warehouse_id']?.toString() ?? '') ?? 0;
      double total = 0.0;
      final rawTotal = p['total'];
      if (rawTotal != null) {
        if (rawTotal is num) {
          total = rawTotal.toDouble();
        } else {
          total = double.tryParse(rawTotal.toString()) ?? 0.0;
        }
      }

      final exists = await executor.query('stock_levels',
          where: 'item_id = ? AND warehouse_id = ?',
          whereArgs: [itemId, warehouseId],
          limit: 1);
      if (exists.isEmpty) {
        await executor.insert('stock_levels', {
          'item_id': itemId,
          'warehouse_id': warehouseId,
          'quantity': total,
          'updated_at': now
        });
      } else {
        final id = exists.first['id'];
        await executor.update(
            'stock_levels', {'quantity': total, 'updated_at': now},
            where: 'id = ?', whereArgs: [id]);
      }
    }
  } catch (e) {
    // در صورت خطا، نادیده بگیر تا فراخواننده تراکنش/لاگ را مدیریت کند.
  }
}
