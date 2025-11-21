// lib/src/core/reports/report_repository.dart
// لایهٔ گزارش‌گیری: اجرای queryهای تجمیعی لازم برای داشبورد و گزارش‌ها.
// - همهٔ متدها از AppDatabase.db استفاده میکنند و خروجی JSON-مانند بازمیگردانند.
// - کامنت فارسی مختصر برای فهم منطق هر متد.

import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';

class ReportRepository {
  ReportRepository._();

  /// بازگشت فروش روزانه برای N روز گذشته (شامل امروز)
  /// خروجی: [{'day': 'YYYY-MM-DD', 'total': 123.45}, ...] به ترتیب صعودی
  static Future<List<Map<String, dynamic>>> getDailySales(
      {int days = 14}) async {
    final d = await AppDatabase.db;
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1))
        .millisecondsSinceEpoch;
    final rows = await d.rawQuery('''
      SELECT date(datetime(created_at/1000, 'unixepoch')) as day,
             SUM(COALESCE(total,0)) as total
      FROM sales
      WHERE created_at >= ?
      GROUP BY day
      ORDER BY day ASC
    ''', [from]);
    return rows;
  }

  /// بازگشت فروش هفتگی برای N هفته گذشته
  /// خروجی: [{'week': 'YYYY-WW', 'total': 123.45}, ...] به ترتیب صعودی
  static Future<List<Map<String, dynamic>>> getWeeklySales(
      {int weeks = 8}) async {
    final d = await AppDatabase.db;
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: weeks * 7 - 1))
        .millisecondsSinceEpoch;
    final rows = await d.rawQuery('''
      SELECT strftime('%Y-%W', datetime(created_at/1000,'unixepoch')) as week,
             SUM(COALESCE(total,0)) as total
      FROM sales
      WHERE created_at >= ?
      GROUP BY week
      ORDER BY week ASC
    ''', [from]);
    return rows;
  }

  /// ارزش ریالی موجودی کالاها: جمع(quantity * purchase_price) از stock_levels JOIN inventory_items
  /// خروجی: {'inventory_value': 12345.67}
  static Future<Map<String, dynamic>> getInventoryValue() async {
    final d = await AppDatabase.db;
    try {
      final rows = await d.rawQuery('''
        SELECT SUM(COALESCE(sl.quantity,0) * COALESCE(ii.purchase_price,0)) as value
        FROM stock_levels sl
        LEFT JOIN inventory_items ii ON ii.id = sl.item_id
      ''');
      final val = rows.isNotEmpty ? (rows.first['value'] ?? 0) : 0;
      final vnum = (val is num)
          ? val.toDouble()
          : double.tryParse(val.toString() ?? '0') ?? 0.0;
      return {'inventory_value': vnum};
    } catch (_) {
      return {'inventory_value': 0.0};
    }
  }

  /// خلاصهٔ سود سهامداران در بازهٔ زمانی (از/to میلی‌ثانیه)
  /// خروجی: [{'person_id': 1, 'display_name': 'علی', 'amount': -12.34}, ...]
  static Future<List<Map<String, dynamic>>> getProfitSharesSummary(
      {int? fromMillis, int? toMillis}) async {
    final d = await AppDatabase.db;
    final args = <dynamic>[];
    String where = '';
    if (fromMillis != null) {
      where = 'WHERE ps.created_at >= ?';
      args.add(fromMillis);
    }
    if (toMillis != null) {
      where = where.isEmpty
          ? 'WHERE ps.created_at <= ?'
          : '$where AND ps.created_at <= ?';
      args.add(toMillis);
    }
    final sql = '''
      SELECT ps.person_id as person_id, p.display_name as display_name, SUM(COALESCE(ps.amount,0)) as amount
      FROM profit_shares ps
      LEFT JOIN persons p ON p.id = ps.person_id
      $where
      GROUP BY ps.person_id
      ORDER BY amount DESC
    ''';
    final rows = await d.rawQuery(sql, args);
    // تبدیل به نوع عددی دقیق‌تر
    return rows.map((r) {
      final amt = r['amount'];
      final dnum = (amt is num)
          ? amt.toDouble()
          : double.tryParse(amt?.toString() ?? '0') ?? 0.0;
      return {
        'person_id': (r['person_id'] is int)
            ? r['person_id'] as int
            : int.tryParse(r['person_id']?.toString() ?? '') ?? 0,
        'display_name': r['display_name']?.toString() ?? '—',
        'amount': dnum
      };
    }).toList();
  }

  /// گزارش P&L خلاصه برای بازهٔ زمانی: محاسبهٔ فروش کل، بهای تمام‌شده (COGS) و سود ناخالص
  /// روش ساده: فروش = SUM(sales.total), COGS = SUM(sale_lines.purchase_price * quantity)
  static Future<Map<String, dynamic>> getPnLSummary(
      {int? fromMillis, int? toMillis}) async {
    final d = await AppDatabase.db;
    final args = <dynamic>[];
    String whereSales = '';
    String whereLines = '';
    if (fromMillis != null) {
      whereSales = 'WHERE s.created_at >= ?';
      whereLines = 'WHERE s.created_at >= ?';
      args.add(fromMillis);
    }
    if (toMillis != null) {
      whereSales = whereSales.isEmpty
          ? 'WHERE s.created_at <= ?'
          : '$whereSales AND s.created_at <= ?';
      whereLines = whereLines.isEmpty
          ? 'WHERE s.created_at <= ?'
          : '$whereLines AND s.created_at <= ?';
      args.add(toMillis);
    }

    // فروش کل
    final salesRows = await d.rawQuery('''
      SELECT SUM(COALESCE(s.total,0)) as total_sales
      FROM sales s
      $whereSales
    ''', args);
    final totalSales =
        (salesRows.isNotEmpty ? (salesRows.first['total_sales'] ?? 0) : 0);
    final totalSalesNum = (totalSales is num)
        ? totalSales.toDouble()
        : double.tryParse(totalSales.toString() ?? '0') ?? 0.0;

    // COGS براساس sale_lines JOIN sales (طبق بازه)
    final linesRows = await d.rawQuery('''
      SELECT SUM(COALESCE(sl.purchase_price,0) * COALESCE(sl.quantity,0)) as cogs
      FROM sale_lines sl
      JOIN sales s ON s.id = sl.sale_id
      $whereLines
    ''', args);
    final cogsVal = (linesRows.isNotEmpty ? (linesRows.first['cogs'] ?? 0) : 0);
    final cogs = (cogsVal is num)
        ? cogsVal.toDouble()
        : double.tryParse(cogsVal.toString() ?? '0') ?? 0.0;

    final grossProfit = totalSalesNum - cogs;

    return {
      'total_sales': double.parse(totalSalesNum.toStringAsFixed(4)),
      'cogs': double.parse(cogs.toStringAsFixed(4)),
      'gross_profit': double.parse(grossProfit.toStringAsFixed(4)),
    };
  }
}
