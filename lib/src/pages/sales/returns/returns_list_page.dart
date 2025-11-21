// lib/src/pages/sales/returns/returns_list_page.dart
// صفحهٔ لیست مرجوعی‌ها — نمایش خلاصهٔ مرجوعی‌ها و مشاهدهٔ جزئیات هر مرجوعی.
// اصلاح: این صفحه فقط Scaffold برمیگرداند (MainLayout در routes قبلاً اضافه شده)
// تا از نمایش دو سایدبار جلوگیری شود.
// کامنت فارسی مختصر برای هر بخش موجود است.

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/db/app_database.dart';
import '../../../core/notifications/notification_service.dart';

import 'new_return_page.dart';

class ReturnsListPage extends StatefulWidget {
  const ReturnsListPage({super.key});

  @override
  State<ReturnsListPage> createState() => _ReturnsListPageState();
}

class _ReturnsListPageState extends State<ReturnsListPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _returns = [];

  @override
  void initState() {
    super.initState();
    _loadReturns();
  }

  Future<void> _loadReturns() async {
    setState(() => _loading = true);
    try {
      final d = await AppDatabase.db;
      final rows = await d
          .rawQuery('SELECT * FROM sale_returns ORDER BY created_at DESC');
      setState(() => _returns = rows);
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'بارگذاری مرجوعی‌ها انجام نشد: $e');
      setState(() => _returns = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  String _fmtMillis(int? millis) {
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

  Future<List<Map<String, dynamic>>> _loadReturnLines(int returnId) async {
    final d = await AppDatabase.db;
    final lines = await d.query('sale_return_lines',
        where: 'return_id = ?', whereArgs: [returnId]);
    return lines;
  }

  Future<void> _showReturnDetails(Map<String, dynamic> ret) async {
    final rid = (ret['id'] is int)
        ? ret['id'] as int
        : int.tryParse(ret['id']?.toString() ?? '0') ?? 0;
    final saleId = (ret['sale_id'] is int)
        ? ret['sale_id'] as int
        : int.tryParse(ret['sale_id']?.toString() ?? '0') ?? 0;
    final created = ret['created_at'] as int?;
    final actor = ret['actor']?.toString() ?? '';
    final notes = ret['notes']?.toString() ?? '';

    final lines = await _loadReturnLines(rid);

    await showDialog<void>(
      context: context,
      builder: (c) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('جزئیات مرجوعی #$rid — فاکتور: $saleId'),
            content: SizedBox(
              width: 720,
              height: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('ایجاد شده: ${_fmtMillis(created)}'),
                  if (actor.isNotEmpty) Text('عامل: $actor'),
                  if (notes.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text('یادداشت: $notes')),
                  const SizedBox(height: 12),
                  Expanded(
                    child: lines.isEmpty
                        ? const Center(child: Text('هیچ ردیفی ثبت نشده'))
                        : ListView.separated(
                            itemCount: lines.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 6),
                            itemBuilder: (ctx, idx) {
                              final l = lines[idx];
                              final pid = l['product_id']?.toString() ?? '-';
                              final qty = l['quantity']?.toString() ?? '0';
                              final up = l['unit_price']?.toString() ?? '0';
                              final pp = l['purchase_price']?.toString() ?? '0';
                              final lt = l['line_total']?.toString() ?? '0';
                              return ListTile(
                                title: Text('محصول: $pid — تعداد: $qty'),
                                subtitle: Text(
                                    'قیمت واحد: $up — قیمت خرید: $pp — جمع: $lt'),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(c).pop(),
                  child: const Text('بستن')),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مرجوعی‌ها / Returns'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.keyboard_return),
        label: const Text('ثبت مرجوعی جدید'),
        onPressed: () async {
          await Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const NewReturnPage()));
          await _loadReturns();
        },
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: _returns.isEmpty
                  ? const Center(child: Text('مرجوعی‌ای ثبت نشده'))
                  : ListView.separated(
                      itemCount: _returns.length,
                      separatorBuilder: (_, __) => const Divider(height: 8),
                      itemBuilder: (ctx, idx) {
                        final r = _returns[idx];
                        final id = r['id']?.toString() ?? '';
                        final saleId = r['sale_id']?.toString() ?? '';
                        final created = r['created_at'] as int?;
                        final actor = r['actor']?.toString() ?? '';
                        final notes = r['notes']?.toString() ?? '';
                        return Card(
                          child: ListTile(
                            title: Text('مرجوعی #$id — فاکتور: $saleId'),
                            subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ایجاد شده: ${_fmtMillis(created)}'),
                                  if (actor.isNotEmpty) Text('عامل: $actor'),
                                  if (notes.isNotEmpty) Text('یادداشت: $notes'),
                                ]),
                            trailing: IconButton(
                              icon: const Icon(Icons.visibility),
                              tooltip: 'نمایش جزئیات',
                              onPressed: () => _showReturnDetails(r),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
