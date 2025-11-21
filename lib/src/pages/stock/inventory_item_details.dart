// lib/src/pages/stock/inventory_item_details.dart
// صفحهٔ جزئیات یک آیتم انبار
// - نمایش اطلاعات پایه کالا
// - نمایش همزمان موجودی کل (تمام انبارها) و موجودی در انبار انتخاب‌شده
// - بارگذاری و نمایش تاریخچهٔ حرکات (stock_movements) مرتبط با کالا
// - ترجمهٔ انواع حرکت‌ها به فارسی: in->ورود, out->خروج, sale->فروش, return->مرجوعی, adjust/adjustment->تنظیم
// - فرمت خواناتر مرجع (مثلاً sale_return:3 -> "مرجوعی: شماره 3")
// - حذف دکمهٔ حذف حرکت از UI (برای جلوگیری از حذف تصادفی)
// - کامنت‌های فارسی مختصر برای فهم هر بخش

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';

class InventoryItemDetails extends StatefulWidget {
  final Map<String, dynamic> item;
  const InventoryItemDetails({super.key, required this.item});

  @override
  State<InventoryItemDetails> createState() => _InventoryItemDetailsState();
}

class _InventoryItemDetailsState extends State<InventoryItemDetails> {
  // داده‌ها و حالت UI
  List<Map<String, dynamic>> _movements = [];
  List<Map<String, dynamic>> _warehouses = [];
  bool _loading = true;
  bool _loadingMore = false;
  final int _limit = 200;
  int _offset = 0;
  bool _hasMore = true;

  int?
      _selectedWarehouse; // فیلتر انتخاب‌شده برای نمایش حرکات (null => همه انبارها)

  // فرم ثبت حرکت (آیتم‌های ساده، در صورت نیاز کاربر میتواند از آنها استفاده کند)
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  final TextEditingController _refCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _actorCtrl = TextEditingController(text: 'user');
  String _type = 'out';
  DateTime _selectedDateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  // بارگذاری اولیه: انبارها و حرکات
  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _offset = 0;
      _hasMore = true;
    });
    try {
      _warehouses = await AppDatabase.getWarehouses();
      // پیشفرض: هیچ فیلتر انباری انتخاب نشده (نمایش همه)
      _selectedWarehouse = null;
      await _loadMovements(reset: true);
    } catch (e) {
      NotificationService.showToast(context, 'بارگذاری انجام نشد: $e',
          backgroundColor: Colors.orange);
      setState(() {
        _movements = [];
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // بارگذاری حرکات: اگر reset=true لیست پاک و از اول خوانده میشود، وگرنه صفحهٔ بعدی بارگذاری میشود
  Future<void> _loadMovements({bool reset = false}) async {
    if (reset) {
      _offset = 0;
      _hasMore = true;
    }
    if (!_hasMore) return;
    if (reset) {
      setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final itemId = _itemId();
      final rows = await AppDatabase.getStockMovements(
          itemId: itemId,
          warehouseId: _selectedWarehouse,
          limit: _limit,
          offset: _offset);
      if (reset) {
        _movements = rows;
      } else {
        _movements.addAll(rows);
      }
      _offset += rows.length;
      if (rows.length < _limit) _hasMore = false;
      setState(() {});
    } catch (e) {
      NotificationService.showToast(context, 'خطا در بارگذاری حرکات: $e',
          backgroundColor: Colors.orange);
    } finally {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  int _itemId() {
    final item = widget.item;
    final id = (item['id'] is int)
        ? item['id'] as int
        : int.tryParse(item['id']?.toString() ?? '') ?? 0;
    return id;
  }

  // فرمت نمایش مقدار عددی (برای نمایش زیبا)
  String _formatQty(dynamic q) {
    if (q == null) return '0';
    if (q is num) {
      final d = q.toDouble();
      if (d == d.roundToDouble()) return d.toInt().toString();
      return d
          .toStringAsFixed(3)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }
    return q.toString();
  }

  // تبدیل نوع حرکت به برچسب فارسی
  String _typeLabel(String? t) {
    final v = (t ?? '').toString().toLowerCase();
    switch (v) {
      case 'in':
      case 'add':
        return 'ورود';
      case 'out':
      case 'remove':
        return 'خروج';
      case 'sale':
        return 'فروش';
      case 'return':
        return 'مرجوعی';
      case 'adjust':
      case 'adjustment':
        return 'تنظیم';
      default:
        return v.isEmpty ? '-' : v;
    }
  }

  // فرمت خواناتر reference
  String _formatReference(String? ref) {
    if (ref == null || ref.trim().isEmpty) return '';
    final r = ref.trim();
    try {
      if (r.startsWith('sale_return:')) {
        final id = r.split(':').last;
        return 'مرجوعی: شماره $id';
      }
      if (r.startsWith('sale:')) {
        final id = r.split(':').last;
        return 'فاکتور فروش: شماره $id';
      }
      return r;
    } catch (_) {
      return r;
    }
  }

  // قالب تاریخ
  String _formatCreatedAt(dynamic createdAt) {
    try {
      int millis = 0;
      if (createdAt is int) {
        millis = createdAt;
      } else {
        millis = int.tryParse(createdAt?.toString() ?? '') ?? 0;
      }
      if (millis <= 0) return '';
      final dt = DateTime.fromMillisecondsSinceEpoch(millis);
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return createdAt?.toString() ?? '';
    }
  }

  // ثبت حرکت جدید (رابط با AppDatabase)
  Future<void> _submitMovement() async {
    final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (qty <= 0.0) {
      NotificationService.showError(context, 'خطا', 'مقدار صحیح وارد کنید');
      return;
    }
    if (_selectedWarehouse == null) {
      NotificationService.showError(
          context, 'خطا', 'ابتدا انبار را انتخاب کنید');
      return;
    }
    try {
      final itemId = _itemId();
      await AppDatabase.registerStockMovement(
        itemId: itemId,
        warehouseId: _selectedWarehouse!,
        type: _type,
        qty: qty,
        reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        notes: _noteCtrl.text.trim(),
        actor: _actorCtrl.text.trim().isEmpty ? 'user' : _actorCtrl.text.trim(),
      );
      NotificationService.showSuccess(
          context, 'ثبت شد', 'حرکت با موفقیت ثبت شد');
      _refCtrl.clear();
      _noteCtrl.clear();
      _qtyCtrl.text = '1';
      await _loadMovements(reset: true); // بازخوانی جدید
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'ثبت حرکت انجام نشد: $e');
    }
  }

  // بازخوانی موجودی‌ها: موجودی کل و موجودی انبار انتخاب‌شده
  Future<double?> _fetchTotalQty() async {
    try {
      final id = _itemId();
      final total = await AppDatabase.getQtyForItemInWarehouse(id, 0);
      return total;
    } catch (_) {
      return null;
    }
  }

  Future<double?> _fetchWarehouseQty(int? warehouseId) async {
    if (warehouseId == null) return null;
    try {
      final id = _itemId();
      final q = await AppDatabase.getQtyForItemInWarehouse(id, warehouseId);
      return q;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _refCtrl.dispose();
    _noteCtrl.dispose();
    _actorCtrl.dispose();
    super.dispose();
  }

  Widget _buildHeader(BuildContext context) {
    final item = widget.item;
    final name = item['name']?.toString() ?? '';
    final code =
        item['product_code']?.toString() ?? item['sku']?.toString() ?? '';
    final desc = item['description']?.toString() ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(children: [
          Expanded(
            flex: 3,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 6),
              Text(code, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 6),
              Text(desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FutureBuilder<double?>(
                future: _fetchTotalQty(),
                builder: (c, s) {
                  final totalText = s.hasData ? _formatQty(s.data) : '...';
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('موجودی کل (تمام انبارها)',
                            style:
                                TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 6),
                        Text(totalText,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                      ]);
                },
              ),
              const SizedBox(height: 8),
              Text('کد: ${item['id'] ?? ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildMovementsList() {
    if (_movements.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(child: Text('هنوز حرکتی برای این کالا ثبت نشده')),
      );
    }

    return Column(children: [
      const Row(children: [
        Expanded(
            flex: 2,
            child: Text('تاریخ/ساعت',
                style: TextStyle(fontWeight: FontWeight.w600))),
        Expanded(
            flex: 1,
            child: Text('نوع', style: TextStyle(fontWeight: FontWeight.w600))),
        Expanded(
            flex: 1,
            child:
                Text('انبار', style: TextStyle(fontWeight: FontWeight.w600))),
        Expanded(
            flex: 1,
            child:
                Text('مقدار', style: TextStyle(fontWeight: FontWeight.w600))),
        Expanded(
            flex: 3,
            child: Text('مرجع / یادداشت / عامل',
                style: TextStyle(fontWeight: FontWeight.w600))),
        SizedBox(width: 8),
      ]),
      const Divider(),
      ..._movements.map((m) {
        final dt = _formatCreatedAt(m['created_at']);
        final type = _typeLabel(m['type']?.toString());
        final qty = _formatQty(m['qty']);
        final whId = (m['warehouse_id'] is int)
            ? m['warehouse_id'] as int
            : int.tryParse(m['warehouse_id']?.toString() ?? '') ?? 0;
        final whName = _warehouses.firstWhere((w) {
          final id = (w['id'] is int)
              ? w['id'] as int
              : int.tryParse(w['id']?.toString() ?? '') ?? 0;
          return id == whId;
        }, orElse: () => {}).isNotEmpty
            ? _warehouses.firstWhere((w) {
                  final id = (w['id'] is int)
                      ? w['id'] as int
                      : int.tryParse(w['id']?.toString() ?? '') ?? 0;
                  return id == whId;
                })['name']?.toString() ??
                whId.toString()
            : (m['warehouse_name']?.toString() ?? whId.toString());
        final ref = _formatReference(m['reference']?.toString());
        final notes = m['notes']?.toString() ?? '';
        final actor = m['actor']?.toString() ?? '';

        return Column(children: [
          Row(children: [
            Expanded(
                flex: 2, child: Text(dt, style: const TextStyle(fontSize: 13))),
            Expanded(
                flex: 1,
                child: Text(type, style: const TextStyle(fontSize: 13))),
            Expanded(
                flex: 1,
                child: Text(whName, style: const TextStyle(fontSize: 13))),
            Expanded(
                flex: 1,
                child: Text(qty,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600))),
            Expanded(
                flex: 3,
                child: Text(
                    ((ref.isNotEmpty ? '[$ref] ' : '') +
                        notes +
                        (actor.isNotEmpty ? ' — عامل: $actor' : '')),
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            // حذف ویرایش حرکت از UI برداشته شده (داده‌ها حساس و محاسبات موجودی وابسته‌اند)
          ]),
          const Divider(height: 8),
        ]);
      }).toList(),
      if (_hasMore)
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: FilledButton.tonal(
            onPressed: _loadingMore ? null : () => _loadMovements(reset: false),
            child: _loadingMore
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('بارگذاری بیشتر'),
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final name = item['name']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('جزئیات کالا: $name'),
        actions: [
          IconButton(
            tooltip: 'بازخوانی',
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitial,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(children: [
                _buildHeader(context),
                const SizedBox(height: 10),

                // فرم ثبت حرکت (اختیاری)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(children: [
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _type,
                            decoration: const InputDecoration(
                                labelText: 'نوع حرکت', isDense: true),
                            items: const [
                              DropdownMenuItem(
                                  value: 'in', child: Text('ورود')),
                              DropdownMenuItem(
                                  value: 'out', child: Text('خروج')),
                              DropdownMenuItem(
                                  value: 'sale', child: Text('فروش')),
                              DropdownMenuItem(
                                  value: 'return', child: Text('مرجوعی')),
                              DropdownMenuItem(
                                  value: 'adjust',
                                  child: Text('تنظیم / اصلاح')),
                            ],
                            onChanged: (v) =>
                                setState(() => _type = v ?? 'out'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: _selectedWarehouse,
                            decoration: const InputDecoration(
                                labelText: 'انبار (اختیاری)', isDense: true),
                            items: <DropdownMenuItem<int?>>[
                              const DropdownMenuItem<int?>(
                                  value: null, child: Text('همه انبارها')),
                              ..._warehouses.map((w) {
                                final id = (w['id'] is int)
                                    ? w['id'] as int
                                    : int.tryParse(w['id']?.toString() ?? '') ??
                                        0;
                                return DropdownMenuItem<int?>(
                                    value: id,
                                    child: Text(w['name']?.toString() ?? ''));
                              }).toList()
                            ],
                            onChanged: (v) async {
                              setState(() => _selectedWarehouse = v);
                              await _loadMovements(reset: true);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                            width: 110,
                            child: TextField(
                                controller: _qtyCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'تعداد', isDense: true))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: _refCtrl,
                                decoration: const InputDecoration(
                                    labelText:
                                        'مرجع (مثلاً sale:123 یا sale_return:3)',
                                    isDense: true))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: TextField(
                                controller: _actorCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'عامل (اختیاری)',
                                    isDense: true))),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 140,
                          child: FilledButton.tonal(
                            onPressed: () async {
                              final d = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDateTime,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100));
                              if (d == null) return;
                              final t = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(
                                      _selectedDateTime));
                              if (t == null) return;
                              setState(() => _selectedDateTime = DateTime(
                                  d.year, d.month, d.day, t.hour, t.minute));
                            },
                            child: Text(
                                DateFormat('yyyy-MM-dd HH:mm')
                                    .format(_selectedDateTime),
                                style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      TextField(
                          controller: _noteCtrl,
                          decoration: const InputDecoration(
                              labelText: 'یادداشت (اختیاری)', isDense: true)),
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        OutlinedButton(
                            onPressed: () {
                              _qtyCtrl.text = '1';
                              _refCtrl.clear();
                              _noteCtrl.clear();
                            },
                            child: const Text('پاکسازی')),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                            onPressed: _submitMovement,
                            child: const Text('ثبت حرکت')),
                      ]),
                    ]),
                  ),
                ),

                const SizedBox(height: 12),

                // لیست حرکات
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SingleChildScrollView(
                        child: Column(children: [
                          // فهرست حرکات
                          _buildMovementsList(),
                          const SizedBox(height: 8),
                          const Text(
                              'تذکر: حذف/ویرایش حرکات از این صفحه غیرفعال است تا سازگاری موجودی حفظ شود.',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
    );
  }
}
