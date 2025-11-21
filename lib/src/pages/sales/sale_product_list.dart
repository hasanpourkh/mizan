//github.com/hasanpourkh/mizan/blob/main/lib/src/pages/sales/sale_product_list.dart
// lib/src/pages/sales/sale_product_list.dart
// ویجت فهرست محصولات/خدمات برای صفحات فروش.
// - نمایش نام، قیمت و برای محصولات «موجودی فعلی»
// - برای خدمات متن «خدمت — تعداد نامحدود» نمایش داده میشود.
// - دکمهٔ افزودن: قبل از افزودن برای محصول بررسی موجودی انجام میشود.
// - پیام خطا/موفقیت با NotificationService به صورت خودمانی/خنده‌دار نمایش داده میشود.
// - کامنت فارسی مختصر در سراسر فایل قرار دارد.

import 'package:flutter/material.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';
import 'package:intl/intl.dart';

typedef OnAddProduct = Future<void> Function(Map<String, dynamic> item);
typedef OnFocusProduct = void Function(Map<String, dynamic> item);

class SaleProductList extends StatefulWidget {
  final OnAddProduct onAddProduct;
  final OnFocusProduct? onFocusProduct;

  const SaleProductList(
      {super.key, required this.onAddProduct, this.onFocusProduct});

  @override
  State<SaleProductList> createState() => _SaleProductListState();
}

class _SaleProductListState extends State<SaleProductList> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _q = '';
  final NumberFormat _nf = NumberFormat.decimalPattern();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    try {
      final items = await AppDatabase.getSellableItems();
      _items = items;
      _applyFilter();
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'بارگذاری آیتم‌ها انجام‌نشد: $e');
      _items = [];
      _filtered = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = List<Map<String, dynamic>>.from(_items);
    } else {
      _filtered = _items.where((it) {
        final name = (it['name']?.toString() ?? '').toLowerCase();
        final sku = (it['sku']?.toString() ?? '').toLowerCase();
        final code =
            (it['code']?.toString() ?? it['product_code']?.toString() ?? '')
                .toLowerCase();
        return name.contains(q) || sku.contains(q) || code.contains(q);
      }).toList();
    }
  }

  // متدی که برای هر آیتم، قبل از اضافه کردن بررسی میکند (مخصوصا برای محصولات)
  Future<void> _handleAddTap(Map<String, dynamic> item) async {
    try {
      final isService = item['is_service'] == true;
      final idRaw = item['id'];
      final id =
          (idRaw is int) ? idRaw : int.tryParse(idRaw?.toString() ?? '') ?? 0;
      if (!isService) {
        final avail = await AppDatabase.getQtyForItemInWarehouse(id, 0);
        if (avail <= 0) {
          // پیام طنزآمیز و خودمانی
          NotificationService.showToast(context,
              'اوپس! موجودی این کالا صفره — انگار همه‌ش رو گورخرها بردن 😅\nفعلاً نمیشه اضافه‌ش کنی.',
              backgroundColor: Colors.orange);
          return;
        }
        // اگر موجودی هست، اضافه کن
        await widget.onAddProduct(item);
        NotificationService.showToast(
            context, 'به سبد اضافه شد (موجودی: ${_nf.format(avail)})');
      } else {
        // خدمت — نامحدود
        await widget.onAddProduct(item);
        NotificationService.showToast(context,
            'خدمت اضافه شد — همین حالا می‌تونی هر چند تا خواستی ثبت کنی 🎉');
      }
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'افزودن انجام نشد: $e');
    }
  }

  Widget _buildItemTile(Map<String, dynamic> it) {
    final name = it['name']?.toString() ?? '—';
    final priceVal = (it['price'] is num)
        ? (it['price'] as num).toDouble()
        : double.tryParse(it['price']?.toString() ?? '') ?? 0.0;
    final isService = it['is_service'] == true;

    return FutureBuilder<double>(
      future: isService
          ? Future.value(double.infinity)
          : AppDatabase.getQtyForItemInWarehouse(
              (it['id'] is int)
                  ? it['id'] as int
                  : int.tryParse(it['id']?.toString() ?? '') ?? 0,
              0),
      builder: (context, snap) {
        String subtitle;
        if (isService) {
          subtitle = 'خدمت — تعداد نامحدود';
        } else {
          if (snap.connectionState == ConnectionState.waiting) {
            subtitle = 'بارگیری موجودی...';
          } else if (snap.hasError) {
            subtitle = 'موجودی: نا‌مشخص';
          } else {
            final avail = snap.data ?? 0.0;
            subtitle = 'موجودی: ${_nf.format(avail)}';
          }
        }

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: CircleAvatar(
            child: Text((it['sku']?.toString() ?? '').isNotEmpty
                ? it['sku']!.toString().substring(0, 1).toUpperCase()
                : name.isNotEmpty
                    ? name[0]
                    : '?'),
          ),
          title: Row(children: [
            Expanded(
                child: Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
            Text('${_nf.format(priceVal)}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          subtitle: Text(subtitle),
          trailing: SizedBox(
            width: 110,
            child: Row(children: [
              IconButton(
                tooltip: 'جزئیات',
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  if (widget.onFocusProduct != null) widget.onFocusProduct!(it);
                },
              ),
              FilledButton.tonal(
                onPressed: () => _handleAddTap(it),
                child: const Text('افزودن'),
              ),
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 520,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'جستجو محصول/خدمت (نام/کد/SKU)'),
                  onChanged: (v) {
                    setState(() {
                      _q = v;
                      _applyFilter();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                  onPressed: _loadItems, child: const Text('بارگذاری مجدد')),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(
                        child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Text('هیچ آیتمی یافت نشد')))
                    : Scrollbar(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) =>
                              _buildItemTile(_filtered[idx]),
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}
