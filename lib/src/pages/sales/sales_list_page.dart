// lib/src/pages/sales/sales_list_page.dart
// فهرست فاکتورها — اصلاح برای پشتیبانی از اسکرول افقی قابل کنترل
// تغییرات اصلی:
// - افزودن ScrollController برای اسکرول افقی
// - محاسبهٔ عرض مورد نیاز جدول براساس تعداد ستونها و تعیین tableWidth = max(viewportWidth, estimatedWidth)
// - قرار دادن DataTable داخل SingleChildScrollView با controller و اضافه کردن دکمه‌های چپ/راست برای حرکت برنامه‌ای
//
// توضیح خیلی خیلی کوتاه: حالا جدول فاکتورها همیشه اگر بزرگتر از عرض پنجره باشد قابل اسکرول افقی است و میتوان با دکمه‌ها هم جابه‌جا کرد.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';
import 'package:shamsi_date/shamsi_date.dart';

// صفحهٔ جزئیات و لایهٔ اصلی
import 'sale_detail/sale_detail_page.dart';
import '../../layouts/main_layout.dart';

class SalesListPage extends StatefulWidget {
  const SalesListPage({super.key});

  @override
  State<SalesListPage> createState() => _SalesListPageState();
}

class _SalesListPageState extends State<SalesListPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  final int _limit = 100;

  // اسکرول افقی کنترلشده — اضافه شده برای حل مشکل دسترسی به ستونهای سمت راست
  final ScrollController _hController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await AppDatabase.getSales(limit: _limit, offset: 0);
      setState(() => _rows = list);
    } catch (e) {
      setState(() => _rows = []);
      NotificationService.showToast(context, 'بارگذاری فاکتورها انجام نشد: $e',
          backgroundColor: Colors.orange);
    } finally {
      setState(() => _loading = false);
    }
  }

  String _formatMillisToJalali(int? millis) {
    if (millis == null) return '';
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(millis);
      final j = Jalali.fromDateTime(dt);
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')} $hh:$mm';
    } catch (_) {
      return '';
    }
  }

  Future<String> _resolveActorLabel(String? actor) async {
    if (actor == null) return '';
    try {
      if (actor.startsWith('person:')) {
        final id = int.tryParse(actor.split(':').last) ?? 0;
        final p = await AppDatabase.getPersonById(id);
        if (p != null) return p['display_name']?.toString() ?? '';
      } else if (actor.startsWith('shift:')) {
        final id = int.tryParse(actor.split(':').last) ?? 0;
        final s = await AppDatabase.getShiftById(id);
        if (s != null) return s['person_name']?.toString() ?? 'شیفت#$id';
      }
      return actor;
    } catch (_) {
      return actor ?? '';
    }
  }

  // ناوبری به صفحهٔ جزئیات فاکتور (MainLayout حفظ میشود)
  void _openSaleDetail(int id) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MainLayout(
        currentRoute: '/sales/view',
        child: SaleDetailPage(saleId: id),
      ),
    ));
  }

  // اسکرول افقی برنامه‌ای با انیمیشن
  Future<void> _scrollBy(double offset) async {
    try {
      final max = _hController.position.maxScrollExtent;
      final min = _hController.position.minScrollExtent;
      final target = (_hController.offset + offset).clamp(min, max);
      await _hController.animateTo(target,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // ساختار ستونهای جدول (برای محاسبهٔ عرض)
    const columns = [
      DataColumn(label: Text('id')),
      DataColumn(label: Text('شماره فاکتور')),
      DataColumn(label: Text('تاریخ (شمسی)')),
      DataColumn(label: Text('مشتری')),
      DataColumn(label: Text('عامل فروش')),
      DataColumn(label: Text('جمع')),
      DataColumn(label: Text('عملیات')),
    ];

    // عرض تقریبی هر ستون (اگر بخواهی دقیقتر شود مقدار را تغییر بده)
    const estimatedColumnWidth = 140;
    final estimatedWidth = columns.length * estimatedColumnWidth;

    return Scaffold(
      appBar: AppBar(
        title: const Text('فهرست فاکتورها'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(
                child: _rows.isEmpty
                    ? const Center(
                        child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text('فاکتوری یافت نشد')))
                    : LayoutBuilder(builder: (ctx, constraints) {
                        // viewport عرض قابل نمایش در کارت
                        final viewportWidth = constraints.maxWidth.isFinite
                            ? constraints.maxWidth
                            : MediaQuery.of(context).size.width;
                        // جدول باید به اندازهٔ بیشینه از viewport یا estimated بزرگ باشد
                        final tableWidth =
                            math.max(viewportWidth, estimatedWidth.toDouble());
                        final tableHeight = constraints.maxHeight;

                        return Column(children: [
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _hController,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: tableWidth,
                                child: SizedBox(
                                  height: tableHeight,
                                  child: SingleChildScrollView(
                                    child: DataTable(
                                      columns: columns,
                                      rows: _rows.map((r) {
                                        final id = (r['id'] is int)
                                            ? r['id'] as int
                                            : int.tryParse(
                                                    r['id']?.toString() ??
                                                        '') ??
                                                0;
                                        final inv =
                                            r['invoice_no']?.toString() ?? '';
                                        final created = r['created_at'] is int
                                            ? r['created_at'] as int
                                            : int.tryParse(r['created_at']
                                                        ?.toString() ??
                                                    '') ??
                                                0;
                                        final total =
                                            r['total']?.toString() ?? '0';
                                        final customer =
                                            r['customer_name']?.toString() ??
                                                '';
                                        final actor =
                                            r['actor']?.toString() ?? '';

                                        return DataRow(
                                          onSelectChanged: (_) {
                                            _openSaleDetail(id);
                                          },
                                          cells: [
                                            DataCell(Text(id.toString())),
                                            DataCell(Text(inv)),
                                            DataCell(Text(_formatMillisToJalali(
                                                created))),
                                            DataCell(Text(customer)),
                                            DataCell(FutureBuilder<String>(
                                                future:
                                                    _resolveActorLabel(actor),
                                                builder: (c, s) => Text(
                                                    s.hasData
                                                        ? s.data!
                                                        : (actor.isNotEmpty
                                                            ? actor
                                                            : '-')))),
                                            DataCell(Text(total)),
                                            DataCell(Row(children: [
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.visibility),
                                                tooltip: 'مشاهده کامل فاکتور',
                                                onPressed: () =>
                                                    _openSaleDetail(id),
                                              ),
                                              IconButton(
                                                  icon: const Icon(Icons.delete,
                                                      color: Colors.red),
                                                  tooltip: 'حذف',
                                                  onPressed: () async {
                                                    final ok =
                                                        await showDialog<bool>(
                                                            context: context,
                                                            builder: (c) =>
                                                                Directionality(
                                                                  textDirection:
                                                                      TextDirection
                                                                          .rtl,
                                                                  child:
                                                                      AlertDialog(
                                                                    title: const Text(
                                                                        'حذف فاکتور'),
                                                                    content:
                                                                        const Text(
                                                                            'آیا از حذف این فاکتور مطمئن هستید؟'),
                                                                    actions: [
                                                                      TextButton(
                                                                          onPressed: () => Navigator.of(c).pop(
                                                                              false),
                                                                          child:
                                                                              const Text('لغو')),
                                                                      FilledButton.tonal(
                                                                          onPressed: () => Navigator.of(c).pop(
                                                                              true),
                                                                          child:
                                                                              const Text('حذف')),
                                                                    ],
                                                                  ),
                                                                ));
                                                    if (ok == true) {
                                                      try {
                                                        await AppDatabase
                                                            .deleteSale(id);
                                                        NotificationService
                                                            .showToast(context,
                                                                'فاکتور حذف شد');
                                                        await _load();
                                                      } catch (e) {
                                                        NotificationService
                                                            .showError(
                                                                context,
                                                                'خطا',
                                                                'حذف انجام نشد: $e');
                                                      }
                                                    }
                                                  }),
                                            ])),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // کنترل های اسکرول افقی (دکمه ها)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                    icon: const Icon(Icons.chevron_left),
                                    onPressed: () => _scrollBy(-300)),
                                const SizedBox(width: 8),
                                IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: () => _scrollBy(300)),
                                const SizedBox(width: 16),
                                Text(
                                    'اگر جدول کامل نمایش داده نمیشود از دکمه‌ها استفاده کنید',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[700])),
                              ],
                            ),
                          ),
                        ]);
                      }),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.refresh),
        label: const Text('بارگذاری مجدد'),
        onPressed: _load,
      ),
    );
  }
}
