// lib/src/pages/purchases/receive_page.dart
// صفحهٔ "ثبت دریافت خرید" — ثبت ورود کالا به انبار برای یک فاکتور خرید یا مرجع
// - هدف: رفع خطاهای مربوط به فیلدهای غیرnullable و اصلاح فراخوانی NotificationService.showError
// - رفتار: کاربر می‌تواند محصول، انبار، تعداد و مرجع را وارد کند و رکورد ورود (type='in') برای هر سطر ثبت می‌شود.
// - کامنت فارسی مختصر در هر بخش برای راهنمایی گذاشته شده است.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';

class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key});

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  // لیست محصولات و انبارها برای انتخاب
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _warehouses = [];

  // فرم اصلی: انتخاب محصول/انبار برای اضافه کردن به فهرست دریافت‌ها
  int? _selectedProductId;
  int? _selectedWarehouseId;
  final TextEditingController _refCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  // خطوط دریافت: هر خط یک Map شامل productId, productName, warehouseId, qty, notes
  // مقداردهی اولیه برای جلوگیری از خطاهای non-nullable
  List<Map<String, dynamic>> _lines = [];

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    setState(() => _loading = true);
    try {
      final prods = await AppDatabase.getProducts();
      final wh = await AppDatabase.getWarehouses();
      setState(() {
        _products = prods;
        _warehouses = wh;
        // پیشفرض‌ها: اولین انبار و اولین محصول (اگر موجود باشد)
        if (_warehouses.isNotEmpty) {
          final id = _warehouses.first['id'];
          _selectedWarehouseId =
              (id is int) ? id : int.tryParse(id?.toString() ?? '');
        }
        if (_products.isNotEmpty) {
          final pid = _products.first['id'];
          _selectedProductId =
              (pid is int) ? pid : int.tryParse(pid?.toString() ?? '');
        }
      });
    } catch (e) {
      NotificationService.showToast(context, 'بارگذاری اطلاعات انجام نشد: $e',
          backgroundColor: Colors.orange);
      setState(() {
        _products = [];
        _warehouses = [];
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // اضافه کردن یک خط جدید به لیست (مقدار qty پیشفرض = 1.0 و notes پیشفرض = '')
  Future<void> _addLine() async {
    if (_selectedProductId == null) {
      NotificationService.showError(
          context, 'خطا', 'ابتدا محصول را انتخاب کنید');
      return;
    }
    if (_selectedWarehouseId == null) {
      NotificationService.showError(
          context, 'خطا', 'ابتدا انبار را انتخاب کنید');
      return;
    }
    // استخراج نام محصول برای نمایش
    final prod = _products.firstWhere((p) {
      final id = (p['id'] is int)
          ? p['id'] as int
          : int.tryParse(p['id']?.toString() ?? '') ?? 0;
      return id == _selectedProductId;
    }, orElse: () => {});
    final prodName = prod.isNotEmpty ? (prod['name']?.toString() ?? '') : '';

    // qty و notes مقداردهی اولیه (رفع خطای نوع non-nullable)
    final line = <String, dynamic>{
      'product_id': _selectedProductId!,
      'product_name': prodName,
      'warehouse_id': _selectedWarehouseId!,
      'qty': 1.0, // مقدار پیشفرض امن
      'notes': '', // متن پیشفرض
    };

    setState(() {
      _lines.add(line);
    });
  }

  // ویرایش مقدار عددی یک خط
  void _updateLineQty(int idx, String text) {
    final parsed = double.tryParse(text.replaceAll(',', '.')) ?? 0.0;
    setState(() {
      _lines[idx]['qty'] = parsed;
    });
  }

  // ویرایش یادداشت خط
  void _updateLineNotes(int idx, String text) {
    setState(() {
      _lines[idx]['notes'] = text;
    });
  }

  // حذف یک خط
  void _removeLine(int idx) {
    setState(() {
      _lines.removeAt(idx);
    });
  }

  // ذخیرهٔ نهایی: برای هر خط یک حرکت stock_movements با type='in' ثبت می‌کنیم
  Future<void> _saveAll() async {
    if (_lines.isEmpty) {
      // اصلاح: showError انتظار سه آرگومان دارد -> (context, title, message)
      NotificationService.showError(
          context, 'خطا', 'هیچ خطی برای ثبت وجود ندارد');
      return;
    }
    setState(() => _saving = true);
    try {
      for (final l in List<Map<String, dynamic>>.from(_lines)) {
        final pid = (l['product_id'] is int)
            ? l['product_id'] as int
            : int.tryParse(l['product_id']?.toString() ?? '') ?? 0;
        final wid = (l['warehouse_id'] is int)
            ? l['warehouse_id'] as int
            : int.tryParse(l['warehouse_id']?.toString() ?? '') ?? 0;
        final qty = (l['qty'] is num)
            ? (l['qty'] as num).toDouble()
            : double.tryParse(l['qty']?.toString() ?? '') ?? 0.0;
        final notes = (l['notes']?.toString() ?? '') +
            (_notesCtrl.text.trim().isNotEmpty
                ? ' — ${_notesCtrl.text.trim()}'
                : '');

        if (pid <= 0 || wid <= 0 || qty <= 0.0) {
          // نادیده‌گیری خطوط نامعتبر اما به کاربر اطلاع بده
          NotificationService.showToast(
              context, 'یک یا چند خط دارای مقدار نامعتبر هستند و ثبت نشدند',
              backgroundColor: Colors.orange);
          continue;
        }

        await AppDatabase.registerStockMovement(
          itemId: pid,
          warehouseId: wid,
          type: 'in',
          qty: qty,
          reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
          notes: notes,
          actor: 'purchase_receive',
        );
      }

      NotificationService.showSuccess(context, 'ثبت شد', 'همهٔ خطوط ثبت شدند',
          onOk: () {
        setState(() {
          _lines.clear();
          _refCtrl.clear();
          _notesCtrl.clear();
        });
      });
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'ثبت دریافت‌ها انجام نشد: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Widget _buildAddForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                value: _selectedProductId,
                decoration:
                    const InputDecoration(labelText: 'محصول', isDense: true),
                items: _products.isEmpty
                    ? [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('هیچ محصولی موجود نیست'))
                      ]
                    : _products.map((p) {
                        final id = (p['id'] is int)
                            ? p['id'] as int
                            : int.tryParse(p['id']?.toString() ?? '') ?? 0;
                        return DropdownMenuItem<int?>(
                            value: id,
                            child: Text(p['name']?.toString() ?? ''));
                      }).toList(),
                onChanged: (v) => setState(() => _selectedProductId = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int?>(
                value: _selectedWarehouseId,
                decoration:
                    const InputDecoration(labelText: 'انبار', isDense: true),
                items: _warehouses.isEmpty
                    ? [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('انباری تعریف نشده'))
                      ]
                    : _warehouses.map((w) {
                        final id = (w['id'] is int)
                            ? w['id'] as int
                            : int.tryParse(w['id']?.toString() ?? '') ?? 0;
                        return DropdownMenuItem<int?>(
                            value: id,
                            child: Text(w['name']?.toString() ?? ''));
                      }).toList(),
                onChanged: (v) => setState(() => _selectedWarehouseId = v),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: FilledButton.tonal(
                  onPressed: _addLine, child: const Text('اضافه')),
            ),
          ]),
          const SizedBox(height: 8),
          TextField(
              controller: _refCtrl,
              decoration: const InputDecoration(
                  labelText: 'مرجع (شماره فاکتور/سری)', isDense: true)),
          const SizedBox(height: 8),
          TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                  labelText: 'یادداشت مشترک (اختیاری)', isDense: true)),
        ]),
      ),
    );
  }

  Widget _buildLinesList() {
    if (_lines.isEmpty) {
      return const Center(child: Text('هیچ خطی اضافه نشده'));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(children: [
          Row(children: const [
            Expanded(
                flex: 3,
                child: Text('محصول',
                    style: TextStyle(fontWeight: FontWeight.w600))),
            Expanded(
                flex: 2,
                child: Text('انبار',
                    style: TextStyle(fontWeight: FontWeight.w600))),
            Expanded(
                flex: 2,
                child: Text('تعداد',
                    style: TextStyle(fontWeight: FontWeight.w600))),
            Expanded(
                flex: 4,
                child: Text('یادداشت',
                    style: TextStyle(fontWeight: FontWeight.w600))),
            SizedBox(width: 48),
          ]),
          const Divider(),
          ..._lines.asMap().entries.map((entry) {
            final idx = entry.key;
            final l = entry.value;
            final prodName = l['product_name']?.toString() ??
                (l['product_id']?.toString() ?? '');
            final whName = _warehouses.firstWhere((w) {
                  final id = (w['id'] is int)
                      ? w['id'] as int
                      : int.tryParse(w['id']?.toString() ?? '') ?? 0;
                  return id == (l['warehouse_id'] ?? 0);
                }, orElse: () => {})['name']?.toString() ??
                (l['warehouse_id']?.toString() ?? '');

            final qtyText = (l['qty'] is num)
                ? (l['qty'] as num).toString()
                : (l['qty']?.toString() ?? '0');

            return Column(children: [
              Row(children: [
                Expanded(flex: 3, child: Text(prodName)),
                Expanded(flex: 2, child: Text(whName)),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    width: double.infinity,
                    child: TextField(
                      controller: TextEditingController(text: qtyText),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]'))
                      ],
                      onChanged: (v) => _updateLineQty(idx, v),
                      decoration: const InputDecoration(
                          isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: TextEditingController(
                        text: l['notes']?.toString() ?? ''),
                    onChanged: (v) => _updateLineNotes(idx, v),
                    decoration: const InputDecoration(
                        isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeLine(idx)),
              ]),
              const Divider(height: 8),
            ]);
          }).toList(),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ثبت دریافت خرید'),
        actions: [
          IconButton(
              tooltip: 'بارگذاری مجدد',
              icon: const Icon(Icons.refresh),
              onPressed: _loadLookups),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(children: [
                _buildAddForm(),
                const SizedBox(height: 12),
                Expanded(child: _buildLinesList()),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: FilledButton.tonal(
                          onPressed: _saving ? null : _saveAll,
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Text('ثبت دریافت‌ها'))),
                  const SizedBox(width: 8),
                  OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _lines.clear();
                          _refCtrl.clear();
                          _notesCtrl.clear();
                        });
                      },
                      child: const Text('پاکسازی')),
                ]),
              ]),
            ),
    );
  }
}
