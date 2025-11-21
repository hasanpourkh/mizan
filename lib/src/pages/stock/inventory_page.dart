// lib/src/pages/stock/inventory_page.dart
// صفحهٔ اصلی انبارداری — فهرست آیتم‌های انبار، موجودی کلی، و عملیات سریع (ورود / خروج / جزئیات).
// - طراحی responsive و compact: فیلدها و دکمه‌ها کوچک شده‌اند تا در صفحه جا شوند.
// - از AppDatabase برای خواندن محصولات و متدهای inventory استفاده میکند.
// - کامنت فارسی مختصر برای هر بخش وجود دارد.
// نکته: هیچ استفادهٔ صریحی از Directionality درون showDialogها وجود ندارد
// (Directionality در سطح اپ در MyApp تعریف شده است).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';
import 'inventory_item_details.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filtered = [];
  String _q = '';
  bool _loading = true;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
    _load();
  }

  // بارگذاری لیست آیتم‌ها از facade
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await AppDatabase.getInventoryItems();
      _items = items.map((e) => Map<String, dynamic>.from(e)).toList();
      _applyFilter();
    } catch (e) {
      _items = [];
      _filtered = [];
      NotificationService.showToast(context, 'بارگذاری انجام نشد: $e',
          backgroundColor: Colors.orange);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = List.from(_items);
    } else {
      _filtered = _items.where((r) {
        final name = r['name']?.toString().toLowerCase() ?? '';
        final sku = r['sku']?.toString().toLowerCase() ?? '';
        final code = r['product_code']?.toString().toLowerCase() ?? '';
        final barcode = r['barcode']?.toString().toLowerCase() ?? '';
        return name.contains(q) ||
            sku.contains(q) ||
            code.contains(q) ||
            barcode.contains(q);
      }).toList();
    }
  }

  void _onSearch() {
    setState(() {
      _q = _searchCtrl.text;
      _applyFilter();
    });
  }

  Future<double> _getTotalStock(int itemId) async {
    try {
      final levels = await AppDatabase.getStockLevels(itemId: itemId);
      double sum = 0.0;
      for (final l in levels) {
        final q = l['quantity'];
        if (q is num) {
          sum += q.toDouble();
        } else {
          sum += double.tryParse(q?.toString() ?? '') ?? 0.0;
        }
      }
      return sum;
    } catch (_) {
      return 0.0;
    }
  }

  // باز کردن صفحه جزئیات آیتم
  Future<void> _openDetails(Map<String, dynamic> item) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            InventoryItemDetails(item: Map<String, dynamic>.from(item))));
    await _load();
  }

  // دیالوگ سریع برای ورود/خروج/تنظیم مقادیر
  Future<void> _quickAdjust(Map<String, dynamic> item, String type) async {
    final qtyCtrl = TextEditingController(text: '1');
    final refCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    int? selectedWarehouseId;

    List<Map<String, dynamic>> wh = [];
    try {
      wh = await AppDatabase.getWarehouses();
      if (wh.isNotEmpty) {
        selectedWarehouseId = (wh.first['id'] is int)
            ? wh.first['id'] as int
            : int.tryParse(wh.first['id']?.toString() ?? '');
      }
    } catch (_) {}

    final res = await showDialog<bool>(
      context: context,
      builder: (c) {
        // توجه: Dialog از Directionality ریشه استفاده میکند (MyApp)
        return AlertDialog(
          title: Text(type == 'in'
              ? 'ثبت ورود سریع'
              : (type == 'out' ? 'ثبت خروج سریع' : 'ثبت تنظیمی سریع')),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'تعداد', isDense: true))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: selectedWarehouseId,
                      decoration: const InputDecoration(
                          labelText: 'انبار', isDense: true),
                      items: wh.isEmpty
                          ? [
                              const DropdownMenuItem<int?>(
                                  value: null, child: Text('فاقد انبار'))
                            ]
                          : wh.map((w) {
                              final id = (w['id'] is int)
                                  ? w['id'] as int
                                  : int.tryParse(w['id']?.toString() ?? '') ??
                                      0;
                              return DropdownMenuItem<int?>(
                                  value: id,
                                  child: Text(w['name']?.toString() ?? ''));
                            }).toList(),
                      onChanged: (v) {
                        selectedWarehouseId = v;
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                TextField(
                    controller: refCtrl,
                    decoration: const InputDecoration(
                        labelText: 'مرجع (شماره فاکتور/خرید)', isDense: true)),
                const SizedBox(height: 8),
                TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                        labelText: 'یادداشت (اختیاری)', isDense: true)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('لغو')),
            FilledButton.tonal(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('ثبت')),
          ],
        );
      },
    );

    if (res == true) {
      final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0.0;
      if (qty <= 0) {
        NotificationService.showError(context, 'خطا', 'مقدار صحیح وارد کنید');
        return;
      }
      if (selectedWarehouseId == null || selectedWarehouseId == 0) {
        NotificationService.showError(
            context, 'خطا', 'ابتدا یک انبار انتخاب کنید');
        return;
      }
      try {
        await AppDatabase.registerStockMovement(
          itemId: (item['id'] is int)
              ? item['id'] as int
              : int.tryParse(item['id']?.toString() ?? '') ?? 0,
          warehouseId: selectedWarehouseId!,
          type: type,
          qty: qty,
          reference: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
          notes: noteCtrl.text.trim(),
          actor: 'user_quick',
        );
        NotificationService.showSuccess(
            context, 'ثبت شد', 'عملیات با موفقیت ثبت شد');
        await _load();
      } catch (e) {
        NotificationService.showError(context, 'خطا', 'ثبت انجام نشد: $e');
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _buildRow(Map<String, dynamic> r) {
    final id = (r['id'] is int)
        ? r['id'] as int
        : int.tryParse(r['id']?.toString() ?? '') ?? 0;
    final name = r['name']?.toString() ?? '';
    final code = r['product_code']?.toString() ?? r['sku']?.toString() ?? '';
    final price = r['price']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(code,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
            ),
            Expanded(
              flex: 2,
              child: FutureBuilder<double>(
                future: _getTotalStock(id),
                builder: (c, s) {
                  final val = s.hasData ? s.data!.toStringAsFixed(2) : '...';
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('موجودی',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[700])),
                        const SizedBox(height: 4),
                        Text(val,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('قیمت: $price',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ]);
                },
              ),
            ),
            Expanded(
              flex: 3,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                SizedBox(
                  height: 34,
                  child: FilledButton.tonal(
                    onPressed: () => _quickAdjust(r, 'in'),
                    child: const Text('ورود', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 34,
                  child: FilledButton.tonal(
                    onPressed: () => _quickAdjust(r, 'out'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade200,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('خروج', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 34,
                  child: OutlinedButton(
                    onPressed: () => _openDetails(r),
                    child: const Text('جزئیات', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('مدیریت انبار')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'جستجو بر اساس نام / کد / بارکد',
                          isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                      height: 36,
                      child: FilledButton.tonal(
                          onPressed: _load, child: const Text('بارگذاری'))),
                ]),
                const SizedBox(height: 12),
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(child: Text('آیتمی یافت نشد'))
                      : ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, idx) {
                            final r = _filtered[idx];
                            return _buildRow(r);
                          },
                        ),
                ),
              ]),
            ),
    );
  }
}
