// lib/src/pages/sales/returns/new_return_page.dart
// صفحهٔ ثبت مرجوعی جدید — نسخهٔ بهبود یافته:
// - به‌جای Dropdown بزرگ از یک جستجوی فاکتور (searchSales) استفاده میکند.
// - وقتی فاکتوری انتخاب شد، خطوط آن نشان داده میشوند و میتوان هر خط را برای مرجوعی انتخاب و مقدار ورود کرد.
// - سمت چپ یک کارت کوچک خلاصهٔ ردیفهای انتخاب‌شده جهت مرجوعی نمایش داده میشود.
// - هنگام ثبت، AppDatabase.registerSaleReturn فراخوانی میشود و رفتار تقسیم فاکتور (split) اعمال میشود.
// - کامنت‌های فارسی مختصر برای هر بخش وجود دارد.

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/db/app_database.dart';
import '../../../core/notifications/notification_service.dart';

class NewReturnPage extends StatefulWidget {
  const NewReturnPage({super.key});

  @override
  State<NewReturnPage> createState() => _NewReturnPageState();
}

class _NewReturnPageState extends State<NewReturnPage> {
  bool _loading = true;
  int? _selectedSaleId;
  Map<String, dynamic>? _sale; // sale با lines
  final Map<int, TextEditingController> _qtyCtrls = {};
  final Map<int, bool> _selected = {}; // آیا خط برای مرجوعی انتخاب شده
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _actorCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // شروع بدون لیست؛ کاربر باید جستجو کند و فاکتور را انتخاب کند.
    _loading = false;
  }

  @override
  void dispose() {
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    _notesCtrl.dispose();
    _actorCtrl.dispose();
    super.dispose();
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

  double _parseDouble(String s) {
    return double.tryParse(s.replaceAll(',', '.')) ?? 0.0;
  }

  // باز کردن دیالوگ جستجوی فاکتور (با آپدیت بهینه)
  Future<void> _openSearchInvoiceDialog() async {
    final TextEditingController searchCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];

    await showDialog<void>(
      context: context,
      builder: (c) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(builder: (ctx, setSt) {
            Future<void> doSearch(String q) async {
              setSt(() {});
              try {
                final r = await AppDatabase.searchSales(q, limit: 200);
                results = r;
                setSt(() {});
              } catch (e) {
                NotificationService.showError(
                    context, 'خطا', 'جستجو انجام نشد: $e');
              }
            }

            return AlertDialog(
              title: const Text('جستجوی فاکتور'),
              content: SizedBox(
                width: 720,
                height: 480,
                child: Column(
                  children: [
                    TextField(
                      controller: searchCtrl,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'شماره فاکتور، نام مشتری یا متن فاکتور'),
                      onSubmitted: (v) => doSearch(v.trim()),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: results.isEmpty
                          ? const Center(
                              child: Text(
                                  'نتیجه‌ای یافت نشد — کلمه‌ای وارد کنید و Enter بزنید'))
                          : ListView.separated(
                              itemCount: results.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 6),
                              itemBuilder: (ctx2, idx) {
                                final r = results[idx];
                                final id = (r['id'] is int)
                                    ? r['id'] as int
                                    : int.tryParse(r['id']?.toString() ?? '') ??
                                        0;
                                final inv = r['invoice_no']?.toString() ?? '';
                                final cname = r['customer_name']?.toString() ??
                                    (r['customer_id']?.toString() ?? '-');
                                final total = r['total']?.toString() ?? '0';
                                final created = (r['created_at'] is int)
                                    ? r['created_at'] as int
                                    : int.tryParse(
                                            r['created_at']?.toString() ??
                                                '') ??
                                        0;
                                return ListTile(
                                  title: Text('#$id — $inv — $cname'),
                                  subtitle: Text(
                                      'جمع: $total — ${_fmtMillis(created)}'),
                                  onTap: () async {
                                    Navigator.of(c).pop();
                                    await _onSaleSelected(id);
                                  },
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
                FilledButton.tonal(
                    onPressed: () => doSearch(searchCtrl.text.trim()),
                    child: const Text('جستجو')),
              ],
            );
          }),
        );
      },
    );

    searchCtrl.dispose();
  }

  // وقتی فاکتوری انتخاب شد، آنرا بارگذاری کن
  Future<void> _onSaleSelected(int id) async {
    setState(() {
      _selectedSaleId = id;
      _sale = null;
      _qtyCtrls.clear();
      _selected.clear();
      _loading = true;
    });
    try {
      final s = await AppDatabase.getSaleById(id);
      setState(() {
        _sale = s;
      });
      final lines = List<Map<String, dynamic>>.from(s?['lines'] ?? []);
      for (final ln in lines) {
        final lid = (ln['id'] is int)
            ? ln['id'] as int
            : int.tryParse(ln['id']?.toString() ?? '0') ?? 0;
        _qtyCtrls[lid] = TextEditingController(text: '0');
        _selected[lid] = false;
      }
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'بارگذاری فاکتور انجام نشد: $e');
      setState(() => _sale = null);
    } finally {
      setState(() => _loading = false);
    }
  }

  // لیست خلاصهٔ ردیف‌های انتخاب‌شده برای مرجوعی (سمت چپ)
  List<Widget> _buildSelectedSummary() {
    final out = <Widget>[];
    if (_sale == null) return out;
    final lines = List<Map<String, dynamic>>.from(_sale!['lines'] ?? []);
    for (final ln in lines) {
      final lid = (ln['id'] is int)
          ? ln['id'] as int
          : int.tryParse(ln['id']?.toString() ?? '') ?? 0;
      if (!(_selected[lid] ?? false)) continue;
      final qty = _qtyCtrls[lid]?.text ?? '0';
      final pname =
          ln['product_name']?.toString() ?? ln['product_id']?.toString() ?? '-';
      out.add(ListTile(title: Text(pname), subtitle: Text('مرجوعی: $qty')));
    }
    if (out.isEmpty) {
      out.add(const Padding(
          padding: EdgeInsets.all(8.0), child: Text('هیچ ردیفی انتخاب نشده')));
    }
    return out;
  }

  Future<void> _submitReturn() async {
    if (_selectedSaleId == null || _sale == null) {
      NotificationService.showError(
          context, 'خطا', 'ابتدا یک فاکتور انتخاب کن');
      return;
    }

    final lines = List<Map<String, dynamic>>.from(_sale!['lines'] ?? []);
    final returnLines = <Map<String, dynamic>>[];

    for (final ln in lines) {
      final lid = (ln['id'] is int)
          ? ln['id'] as int
          : int.tryParse(ln['id']?.toString() ?? '0') ?? 0;
      if (!(_selected[lid] ?? false)) continue;
      final ctrl = _qtyCtrls[lid];
      if (ctrl == null) continue;
      final retQty = _parseDouble(ctrl.text);
      final origQty = (ln['quantity'] is num)
          ? (ln['quantity'] as num).toDouble()
          : double.tryParse(ln['quantity']?.toString() ?? '') ?? 0.0;
      if (retQty <= 0) continue;
      if (retQty > origQty) {
        NotificationService.showError(context, 'خطا',
            'مقدار مرجوعی برای یک یا چند ردیف بیشتر از مقدار اصلی است.');
        return;
      }
      final productId = (ln['product_id'] is int)
          ? ln['product_id'] as int
          : int.tryParse(ln['product_id']?.toString() ?? '0') ?? 0;
      final unitPrice = (ln['unit_price'] is num)
          ? (ln['unit_price'] as num).toDouble()
          : double.tryParse(ln['unit_price']?.toString() ?? '') ?? 0.0;
      final purchasePrice = (ln['purchase_price'] is num)
          ? (ln['purchase_price'] as num).toDouble()
          : double.tryParse(ln['purchase_price']?.toString() ?? '') ?? 0.0;
      final warehouseId = (ln['warehouse_id'] is int)
          ? ln['warehouse_id'] as int
          : int.tryParse(ln['warehouse_id']?.toString() ?? '') ?? 0;

      returnLines.add({
        'sale_line_id': lid,
        'product_id': productId,
        'quantity': retQty,
        'unit_price': unitPrice,
        'purchase_price': purchasePrice,
        'warehouse_id': warehouseId,
      });
    }

    if (returnLines.isEmpty) {
      NotificationService.showError(context, 'خطا',
          'هیچ ردیفی برای مرجوعی انتخاب نشده یا مقادیر معتبر وارد نشده‌اند.');
      return;
    }

    setState(() => _saving = true);
    try {
      final actorText = _actorCtrl.text.trim();
      final notes = _notesCtrl.text.trim();
      final retId = await AppDatabase.registerSaleReturn(
          _selectedSaleId!, returnLines,
          actor: actorText.isNotEmpty ? actorText : null,
          notes: notes.isNotEmpty ? notes : null);
      NotificationService.showSuccess(
          context, 'ثبت شد', 'مرجوعی ثبت شد (id=$retId)', onOk: () {
        Navigator.of(context).pop();
      });
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'ثبت مرجوعی انجام نشد: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ثبت مرجوعی جدید'),
        actions: [
          IconButton(
              tooltip: 'جستجوی فاکتور',
              icon: const Icon(Icons.search),
              onPressed: _openSearchInvoiceDialog),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: _sale == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('ابتدا یک فاکتور انتخاب کنید'),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                              onPressed: _openSearchInvoiceDialog,
                              child: const Text('جستجوی فاکتور...')),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        // ستون چپ: خلاصهٔ انتخاب‌شده‌ها (compact)
                        SizedBox(
                          width: 320,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  Text('خلاصهٔ مرجوعی',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: ListView(
                                      children: _buildSelectedSummary(),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                      'فاکتور: ${_sale!['invoice_no'] ?? '-'}'),
                                  Text(
                                      'مشتری: ${_sale!['customer_name'] ?? _sale!['customer_id'] ?? '-'}'),
                                  Text(
                                      'ایجاد شده: ${_fmtMillis(_sale!['created_at'] as int?)}'),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // ستون راست: خطوط فاکتور و فرم مرجوعی
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text('انتخاب ردیف‌ها برای مرجوعی',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount:
                                          (_sale!['lines'] as List).length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 6),
                                      itemBuilder: (ctx, idx) {
                                        final ln =
                                            List<Map<String, dynamic>>.from(
                                                _sale!['lines'])[idx];
                                        final lid = (ln['id'] is int)
                                            ? ln['id'] as int
                                            : int.tryParse(
                                                    ln['id']?.toString() ??
                                                        '0') ??
                                                0;
                                        final prodId =
                                            ln['product_id']?.toString() ?? '-';
                                        final pname =
                                            ln['product_name']?.toString() ??
                                                prodId;
                                        final origQty = (ln['quantity'] is num)
                                            ? (ln['quantity'] as num).toDouble()
                                            : double.tryParse(ln['quantity']
                                                        ?.toString() ??
                                                    '') ??
                                                0.0;
                                        final unitPrice =
                                            ln['unit_price']?.toString() ?? '0';
                                        final controller = _qtyCtrls[lid]!;
                                        return ListTile(
                                          title: Row(
                                            children: [
                                              Expanded(
                                                  child: Text(pname,
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight
                                                              .w700))),
                                              Checkbox(
                                                  value:
                                                      _selected[lid] ?? false,
                                                  onChanged: (v) => setState(
                                                      () => _selected[lid] =
                                                          v ?? false)),
                                            ],
                                          ),
                                          subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    'تعداد اصلی: ${origQty.toString()} — قیمت واحد: $unitPrice'),
                                                const SizedBox(height: 6),
                                                Row(children: [
                                                  SizedBox(
                                                    width: 140,
                                                    child: TextField(
                                                      controller: controller,
                                                      keyboardType:
                                                          const TextInputType
                                                              .numberWithOptions(
                                                              decimal: true),
                                                      decoration:
                                                          InputDecoration(
                                                        labelText:
                                                            'مقدار مرجوعی (≤ $origQty)',
                                                        border:
                                                            const OutlineInputBorder(),
                                                        isDense: true,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  FilledButton.tonal(
                                                      onPressed: () {
                                                        controller.text =
                                                            origQty.toString();
                                                        setState(() =>
                                                            _selected[lid] =
                                                                true);
                                                      },
                                                      child: const Text(
                                                          'برگشت کامل')),
                                                ]),
                                              ]),
                                        );
                                      },
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // فیلد عامل و یادداشت
                                  Row(children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _actorCtrl,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'عامل (مثلاً person:1 یا توضیح)',
                                            border: OutlineInputBorder()),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 160,
                                      child: FilledButton.tonal(
                                        onPressed: () {
                                          AppDatabase.getActiveShift()
                                              .then((sh) {
                                            if (sh != null) {
                                              final sid =
                                                  sh['id']?.toString() ?? '';
                                              final name = sh['person_name']
                                                      ?.toString() ??
                                                  '';
                                              _actorCtrl.text = 'shift:$sid';
                                              NotificationService.showToast(
                                                  context, 'شیفت فعال: $name');
                                            } else {
                                              NotificationService.showToast(
                                                  context,
                                                  'شیفت فعالی وجود ندارد',
                                                  backgroundColor:
                                                      Colors.orange);
                                            }
                                          });
                                        },
                                        child: const Text('استفاده از شیفت'),
                                      ),
                                    )
                                  ]),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _notesCtrl,
                                    decoration: const InputDecoration(
                                        labelText: 'یادداشت مرجوعی (اختیاری)',
                                        border: OutlineInputBorder()),
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(children: [
                                    Expanded(
                                      child: FilledButton.tonal(
                                        onPressed:
                                            _saving ? null : _submitReturn,
                                        child: _saving
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2))
                                            : const Text('ثبت مرجوعی'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('انصراف')),
                                  ]),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }
}
