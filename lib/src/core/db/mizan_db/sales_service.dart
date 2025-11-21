// lib/src/core/db/mizan_db/sales_service.dart
// منطق مرتبط با فروش: searchSales، createProfitSharesForSale، registerSaleReturn و wrapperهای مرتبط.
// - این فایل جایگزین بخشی از منطق بزرگ app_database.dart شده و جداگانه تست‌پذیر است.
// - توجه: برای رفع ارور type mismatch، فراخوانی registerStockMovement از طریق AppDatabase.registerStockMovement انجام میشود
//   (اگر بخواهی میتوانم inventory_dao را نیز به DatabaseExecutor ارتقا دهم تا تمام عملیات داخل تراکنش بماند).

import 'package:sqflite/sqflite.dart';
import 'dart:math' as math;
import '../../daos/persons_meta_dao.dart' as persons_meta_dao;
import '../app_database.dart'
    as AppDbFacade; // برای فراخوانی registerStockMovement wrapper
import '../daos/sales_dao.dart' as sales_dao;
import '../../db/database.dart' as db_export; // در صورت نیاز به export

// Helper کوچک
double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

bool _flagIsTrue(dynamic v) {
  if (v == null) return false;
  if (v is int) return v == 1;
  if (v is bool) return v;
  if (v is String) return v == '1' || v.toLowerCase() == 'true';
  return false;
}

// جستجوی سریع فاکتورها (برای فرم مرجوعی)
Future<List<Map<String, dynamic>>> searchSales(Database d, String q,
    {int limit = 200}) async {
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

// ایجاد تخصیص سهم سهامداران برای فاکتور (دریافت Database یا Transaction)
Future<void> createProfitSharesForSale(Database d, int saleId) async {
  try {
    final lines =
        await d.query('sale_lines', where: 'sale_id = ?', whereArgs: [saleId]);
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
    // لاگ یا نادیده گرفتن خطا — UI میتواند خطا را نشان دهد
  }
}

/// ثبت مرجوعی (registerSaleReturn)
/// توجه: این تابع از Database d استفاده میکند و عملیات DB را در یک تراکنش انجام میدهد.
/// برای ثبت حرکت انبار از AppDbFacade.AppDatabase.registerStockMovement استفاده میشود
/// تا مشکل تایپ Transaction vs Database برطرف شود (در صورت تمایل میتوانیم inventory_dao را
/// به‌صورت DatabaseExecutor سازگار کنیم تا تمام حرکت‌ها داخل txn باشند).
Future<int> registerSaleReturn(
    Database d, int saleId, List<Map<String, dynamic>> returnLines,
    {String? actor, String? notes}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  return await d.transaction<int>((txn) async {
    // ایجاد جدولها در صورت نبودن
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

    final returnId = await txn.insert('sale_returns', {
      'sale_id': saleId,
      'created_at': now,
      'actor': actor ?? '',
      'notes': notes ?? ''
    });

    // خواندن خطوط اصلی فاکتور
    final existingLines = await txn
        .query('sale_lines', where: 'sale_id = ?', whereArgs: [saleId]);
    final Map<int, Map<String, dynamic>> existingMap = {};
    for (final l in existingLines) {
      final lid = (l['id'] is int)
          ? (l['id'] as int)
          : int.tryParse(l['id']?.toString() ?? '') ?? 0;
      existingMap[lid] = Map<String, dynamic>.from(l);
    }

    // تجمع مرجوعی برای هر خط
    final Map<int, double> toReturnByLine = {};
    for (final rl in returnLines) {
      final slid = (rl['sale_line_id'] is int)
          ? rl['sale_line_id'] as int
          : int.tryParse(rl['sale_line_id']?.toString() ?? '') ?? 0;
      final qty = _toDouble(rl['quantity']);
      if (qty <= 0) continue;
      toReturnByLine[slid] = (toReturnByLine[slid] ?? 0.0) + qty;
    }

    // خواندن سهامداران
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
            final sp2 =
                await persons_meta_dao.getPersonSharePercentage(txn, pid);
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

    // محاسبات و درج sale_return_lines و تعدیلات سود و به‌روزرسانی sale_lines
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

      await txn.insert('sale_return_lines', {
        'return_id': returnId,
        'sale_line_id': saleLineId,
        'product_id': productId,
        'quantity': retQty,
        'unit_price': unitPrice,
        'purchase_price': purchasePrice,
        'line_total': lineTotal
      });

      // خواندن ردیف فعلی
      final existing = await txn.query('sale_lines',
          where: 'id = ?', whereArgs: [saleLineId], limit: 1);
      if (existing.isEmpty) continue;
      final ex = Map<String, dynamic>.from(existing.first);
      final origQty = _toDouble(ex['quantity']);
      final origDiscount = _toDouble(ex['discount'] ?? 0.0);

      final discountPerUnit = (origQty > 0) ? (origDiscount / origQty) : 0.0;
      final returnedDiscount = discountPerUnit * retQty;

      final newQty = (origQty - retQty).clamp(0.0, double.infinity);
      if (newQty <= 0.000001) {
        try {
          await txn
              .delete('sale_lines', where: 'id = ?', whereArgs: [saleLineId]);
        } catch (_) {}
      } else {
        final newLineTotal = double.parse(
            ((unitPrice * newQty) - (discountPerUnit * newQty))
                .toStringAsFixed(4));
        try {
          await txn.update(
              'sale_lines',
              {
                'quantity': newQty,
                'discount': double.parse(
                    (origDiscount - returnedDiscount).toStringAsFixed(4)),
                'line_total': newLineTotal
              },
              where: 'id = ?',
              whereArgs: [saleLineId]);
        } catch (_) {}
      }

      // ثبت حرکت انبار (CALL wrapper) — این فراخوانی از AppDatabase wrapper استفاده میکند
      try {
        await AppDbFacade.AppDatabase.registerStockMovement(
          itemId: productId,
          warehouseId: warehouseId,
          type: 'return',
          qty: retQty,
          reference: 'sale_return:$returnId',
          notes: 'Return from sale $saleId',
          actor: actor,
        );
      } catch (_) {}

      // محاسبه سود برگشتی و درج تعدیل سهم سهامداران
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
          final amount = -(profitReturned * (percent / 100.0));
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
    } // end for each return line

    // بازسازی جمع کل فاکتور از خطوط باقیمانده و به‌روزرسانی sales.total
    try {
      final remLines = await txn
          .query('sale_lines', where: 'sale_id = ?', whereArgs: [saleId]);
      double newTotal = 0.0;
      for (final rl in remLines) {
        newTotal += _toDouble(rl['line_total']);
      }
      await txn.update(
          'sales', {'total': double.parse(newTotal.toStringAsFixed(4))},
          where: 'id = ?', whereArgs: [saleId]);
    } catch (_) {}

    return returnId;
  });
}
