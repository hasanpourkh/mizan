// lib/src/core/db/daos/sales_dao.dart
// DAO برای فروشها و خطوط فروش (sales & sale_lines).
// تغییرات:
// - ستون payment_info (TEXT) به جدول sales اضافه شد (مهاجرت محافظه‌کارانه).
// - دو متد جدید برای ذخیره و خواندن payment_info (JSON) اضافه شد:
//     setSalePaymentInfo(db, saleId, info)  -> ذخیره JSON در ستون payment_info
//     getSalePaymentInfo(db, saleId) -> بازگرداندن Map (یا null)
// - بقیهٔ منطق saveSale/getSaleById/getSales بدون تغییر است.
// - کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'inventory_dao.dart' as inventory_dao;

Future<void> createSalesTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS sales (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_no TEXT,
      customer_id INTEGER,
      total REAL,
      notes TEXT,
      actor TEXT,
      payment_info TEXT,
      created_at INTEGER
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS sale_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sale_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      quantity REAL NOT NULL,
      unit_price REAL NOT NULL,
      purchase_price REAL DEFAULT 0,
      discount REAL DEFAULT 0,
      line_total REAL NOT NULL,
      warehouse_id INTEGER DEFAULT 0
    )
  ''');
}

Future<void> migrateSalesTables(Database db) async {
  try {
    final info = await db.rawQuery("PRAGMA table_info(sales)");
    if (info.isEmpty) {
      await createSalesTables(db);
      return;
    }
    final columnNames = info.map((r) => r['name']?.toString() ?? '').toList();
    // اگر ستون actor وجود ندارد، آن را اضافه کن (مهاجرت امن)
    if (!columnNames.contains('actor')) {
      try {
        await db.execute("ALTER TABLE sales ADD COLUMN actor TEXT");
      } catch (_) {}
    }
    // اگر ستون payment_info وجود ندارد، اضافه کن (برای ذخیره ساختار پرداخت)
    if (!columnNames.contains('payment_info')) {
      try {
        await db.execute("ALTER TABLE sales ADD COLUMN payment_info TEXT");
      } catch (_) {}
    }

    final info2 = await db.rawQuery("PRAGMA table_info(sale_lines)");
    if (info2.isEmpty) {
      await createSalesTables(db);
      return;
    }
    final columnNames2 = info2.map((r) => r['name']?.toString() ?? '').toList();
    if (!columnNames2.contains('warehouse_id')) {
      try {
        await db.execute(
            "ALTER TABLE sale_lines ADD COLUMN warehouse_id INTEGER DEFAULT 0");
      } catch (_) {}
    }
  } catch (_) {}
}

// ذخیره یک فروش به همراه خطوط (transactional)
// sale: {invoice_no, customer_id, total, notes, actor, created_at}
// lines: List of {product_id, quantity, unit_price, purchase_price, discount, line_total, warehouse_id}
Future<int> saveSale(Database db, Map<String, dynamic> sale,
    List<Map<String, dynamic>> lines) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  return await db.transaction<int>((txn) async {
    final s = Map<String, dynamic>.from(sale);
    s['created_at'] ??= now;
    final saleId = await txn.insert('sales', s);

    for (final ln in lines) {
      final line = Map<String, dynamic>.from(ln);
      line['sale_id'] = saleId;
      await txn.insert('sale_lines', line);

      // همچنین برای هر خط یک حرکت stock_movements با نوع 'out' ثبت کنیم تا موجودی کاهش یابد
      try {
        await txn.insert('stock_movements', {
          'item_id': line['product_id'],
          'warehouse_id': line['warehouse_id'] ?? 0,
          'type': 'out',
          'qty': line['quantity'],
          'reference': s['invoice_no'],
          'notes': 'فروش (sale_id=$saleId)',
          'actor': s['actor'] ?? 'sale',
          'created_at': now,
        });

        // بازمحاسبه سطح آن زوج product/warehouse
        final wid = (line['warehouse_id'] is int)
            ? line['warehouse_id'] as int
            : int.tryParse(line['warehouse_id']?.toString() ?? '') ?? 0;
        final pid = (line['product_id'] is int)
            ? line['product_id'] as int
            : int.tryParse(line['product_id']?.toString() ?? '') ?? 0;
        if (wid > 0 && pid > 0) {
          await inventory_dao.recomputeStockLevelsForPair(txn, pid, wid);
        } else {
          // اگر warehouse_id=0 بود، بعد از تمام خطوط recompute کلی انجام میشود
        }
      } catch (_) {
        // اگر حرکت یا recompute ناموفق بود، ادامه بده و در آینده recompute کلی انجام شود
      }
    }

    // در پایان یکبار recompute کلی (محافظهکارانه) تا سطوح با موجودیت هماهنگ شوند
    try {
      await inventory_dao.recomputeStockLevels(txn);
    } catch (_) {}

    return saleId;
  });
}

// ذخیرهٔ payment_info برای یک sale: info یک Map است که تبدیل به JSON میشود
Future<int> setSalePaymentInfo(
    Database db, int saleId, Map<String, dynamic>? info) async {
  final payload = info == null ? null : jsonEncode(info);
  final m = <String, dynamic>{};
  m['payment_info'] = payload;
  return await db.update('sales', m, where: 'id = ?', whereArgs: [saleId]);
}

// خواندن payment_info برای sale (برمیگرداند Map یا null)
Future<Map<String, dynamic>?> getSalePaymentInfo(
    Database db, int saleId) async {
  final rows = await db.query('sales',
      columns: ['payment_info'],
      where: 'id = ?',
      whereArgs: [saleId],
      limit: 1);
  if (rows.isEmpty) return null;
  final raw = rows.first['payment_info'];
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw.toString());
    if (decoded is Map<String, dynamic>) return decoded;
    return Map<String, dynamic>.from(decoded);
  } catch (_) {
    return null;
  }
}

Future<List<Map<String, dynamic>>> getSales(Database db,
    {int limit = 100, int offset = 0}) async {
  const sql = '''
    SELECT s.*, c.display_name AS customer_name
    FROM sales s
    LEFT JOIN persons c ON c.id = s.customer_id
    ORDER BY s.created_at DESC
    LIMIT ? OFFSET ?
  ''';
  return await db.rawQuery(sql, [limit, offset]);
}

Future<Map<String, dynamic>?> getSaleById(Database db, int id) async {
  final rows =
      await db.query('sales', where: 'id = ?', whereArgs: [id], limit: 1);
  if (rows.isEmpty) return null;
  final sale = Map<String, dynamic>.from(rows.first);

  final lines =
      await db.query('sale_lines', where: 'sale_id = ?', whereArgs: [id]);
  sale['lines'] = lines;
  return sale;
}

Future<int> deleteSale(Database db, int id) async {
  return await db.transaction<int>((txn) async {
    // حذف خطوط
    await txn.delete('sale_lines', where: 'sale_id = ?', whereArgs: [id]);
    // حذف رکورد فروش
    final deleted = await txn.delete('sales', where: 'id = ?', whereArgs: [id]);
    // بازمحاسبه کلی سطوح
    await inventory_dao.recomputeStockLevels(txn);
    return deleted;
  });
}
