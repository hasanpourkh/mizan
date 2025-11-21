// lib/src/pages/sales/sale_detail/sale_detail_page.dart
// صفحهٔ جزئیات فاکتور — افزودن دکمهٔ پرینت با پیش‌نمایش (A4/A5)
// - دکمهٔ پرینت در AppBar اضافه شده؛ ابتدا سایز را می‌پرسد، سپس صفحهٔ پیش‌نمایش را باز میکند.

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:pdf/pdf.dart'; // برای PdfPageFormat

import '../../../core/db/app_database.dart';
import '../../../core/db/daos/sales_dao.dart' as sales_dao;
import '../../../core/notifications/notification_service.dart';

import 'widgets/sale_lines_widget.dart';
import 'widgets/sale_summary_widget.dart';
import 'widgets/sale_payments_widget.dart';

import '../print_preview_page.dart'; // نمایش پیش‌نمایش

class SaleDetailPage extends StatefulWidget {
  final int saleId;
  const SaleDetailPage({super.key, required this.saleId});

  @override
  State<SaleDetailPage> createState() => _SaleDetailPageState();
}

class _SaleDetailPageState extends State<SaleDetailPage> {
  Map<String, dynamic>? _sale;
  Map<String, dynamic>? _paymentInfo;
  Map<String, dynamic>? _businessProfile;
  bool _loading = true;
  bool _savingPayments = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final db = await AppDatabase.db;
      final s = await sales_dao.getSaleById(db, widget.saleId);
      final pi = await sales_dao.getSalePaymentInfo(db, widget.saleId);
      final bp = await AppDatabase.getBusinessProfile().catchError((_) => null);
      setState(() {
        _sale = s;
        _paymentInfo = pi;
        _businessProfile = bp;
      });
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'بارگذاری فاکتور انجام نشد: $e');
      setState(() {
        _sale = null;
        _paymentInfo = null;
      });
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
    if (actor == null) return '-';
    try {
      if (actor.startsWith('person:')) {
        final id = int.tryParse(actor.split(':').last) ?? 0;
        final p = await AppDatabase.getPersonById(id);
        if (p != null) return p['display_name']?.toString() ?? '-';
      } else if (actor.startsWith('shift:')) {
        final id = int.tryParse(actor.split(':').last) ?? 0;
        final s = await AppDatabase.getShiftById(id);
        if (s != null) {
          return s['person_name']?.toString() ?? 'شیفت#$id';
        }
      }
      return actor;
    } catch (_) {
      return actor ?? '-';
    }
  }

  Future<void> _savePaymentInfo(Map<String, dynamic> info) async {
    setState(() => _savingPayments = true);
    try {
      final db = await AppDatabase.db;
      await sales_dao.setSalePaymentInfo(db, widget.saleId, info);
      NotificationService.showSuccess(
          context, 'ذخیره شد', 'اطلاعات پرداخت ذخیره شد');
      await _loadAll();
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'ذخیره پرداخت انجام نشد: $e');
    } finally {
      setState(() => _savingPayments = false);
    }
  }

  // نمایش دیالوگ انتخاب سایز و باز کردن صفحهٔ پیش‌نمایش
  Future<void> _onPrint() async {
    if (_sale == null) {
      NotificationService.showToast(context, 'فاکتور بارگذاری نشده');
      return;
    }

    final selected = await showDialog<String?>(
      context: context,
      builder: (c) {
        String group = 'A4';
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(builder: (ctx, setSt) {
            return AlertDialog(
              title: const Text('انتخاب سایز برگه برای چاپ'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                RadioListTile<String>(
                  value: 'A4',
                  groupValue: group,
                  title: const Text('A4'),
                  onChanged: (v) => setSt(() => group = v ?? 'A4'),
                ),
                RadioListTile<String>(
                  value: 'A5',
                  groupValue: group,
                  title: const Text('A5'),
                  onChanged: (v) => setSt(() => group = v ?? 'A5'),
                ),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(c).pop(null),
                    child: const Text('انصراف')),
                FilledButton.tonal(
                    onPressed: () => Navigator.of(c).pop(group),
                    child: const Text('پیش‌نمایش')),
              ],
            );
          }),
        );
      },
    );

    if (selected == null) return;
    final format = (selected == 'A5') ? PdfPageFormat.a5 : PdfPageFormat.a4;

    // باز کردن صفحهٔ پیش‌نمایش
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PrintPreviewPage(
          sale: _sale!, business: _businessProfile, pageFormat: format),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جزئیات فاکتور'),
        actions: [
          if (_sale != null)
            FutureBuilder<String>(
              future: _resolveActorLabel(_sale!['actor']?.toString()),
              builder: (ctx, ss) {
                final actorLabel =
                    ss.data ?? (_sale!['actor']?.toString() ?? '-');
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Center(
                      child: Text(actorLabel,
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                );
              },
            ),
          IconButton(
            tooltip: 'پرینت / پیش‌نمایش فاکتور',
            icon: const Icon(Icons.print),
            onPressed: _onPrint,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sale == null
              ? const Center(child: Text('فاکتوری یافت نشد'))
              : LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  return Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: wide ? _buildWide() : _buildNarrow(),
                  );
                }),
    );
  }

  Widget _buildWide() {
    return Row(children: [
      Expanded(
        flex: 2,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SaleLinesWidget(
                lines: List<Map<String, dynamic>>.from(_sale!['lines'] ?? [])),
          ),
        ),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: 520,
        child: Column(children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SaleSummaryWidget(
                sale: _sale!,
                businessProfile: _businessProfile,
                formattedDate:
                    _formatMillisToJalali(_sale!['created_at'] as int?),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SalePaymentsWidget(
                  initialPaymentInfo: _paymentInfo,
                  grandTotal: (_sale!['total'] is num)
                      ? (_sale!['total'] as num).toDouble()
                      : double.tryParse(_sale!['total']?.toString() ?? '') ??
                          0.0,
                  onSave: (info) async => _savePaymentInfo(info),
                ),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildNarrow() {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SaleSummaryWidget(
              sale: _sale!,
              businessProfile: _businessProfile,
              formattedDate:
                  _formatMillisToJalali(_sale!['created_at'] as int?),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SaleLinesWidget(
                lines: List<Map<String, dynamic>>.from(_sale!['lines'] ?? [])),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SalePaymentsWidget(
              initialPaymentInfo: _paymentInfo,
              grandTotal: (_sale!['total'] is num)
                  ? (_sale!['total'] as num).toDouble()
                  : double.tryParse(_sale!['total']?.toString() ?? '') ?? 0.0,
              onSave: (info) async => _savePaymentInfo(info),
            ),
          ),
        ),
      ],
    );
  }
}
