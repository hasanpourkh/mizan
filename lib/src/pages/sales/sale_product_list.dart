//github.com/nimshakiba/mizan/blob/main/lib/src/pages/sales/sale_product_list.dart
// lib/src/pages/sales/sale_product_list.dart
// لیست محصولات/خدمات داخل صفحهٔ فروش (قابل استفاده هم در پنل بزرگ و هم حالت compact)
// - تغییر مهم: اکنون هم محصولات و هم خدمات را نشان میدهد (با is_service flag).
// - onAddProduct و onFocusProduct اکنون Map<String,dynamic> میگیرند (آیتم کامل).
// - خدمات بدون موجودی هستند؛ بنابراین روی اضافه‌سازی کنترل موجودی اعمال نمیشود.
// - کامنت فارسی مختصر برای هر بخش وجود دارد.

import 'package:flutter/material.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/utils/number_formatters.dart';

typedef OnAddProduct = void Function(Map<String, dynamic> item);
typedef OnFocusProduct = void Function(Map<String, dynamic> item);

class SaleProductList extends StatefulWidget {
  // compact: وقتی true است آیتمها و فیلد جستجو جمعوجورتر نمایش داده میشوند (موبایل/پنجره کوچک)
  final bool compact;
  final OnAddProduct onAddProduct;
  final OnFocusProduct onFocusProduct;

  const SaleProductList({
    super.key,
    required this.onAddProduct,
    required this.onFocusProduct,
    this.compact = false,
  });

  @override
  State<SaleProductList> createState() => _SaleProductListState();
}

class _SaleProductListState extends State<SaleProductList> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _q = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_onSearchChanged);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _items = [];
      _filtered = [];
    });
    try {
      final items = await AppDatabase.getSellableItems();
      _items = items;
      _applyFilter();
    } catch (e) {
      NotificationService.showToast(
          context, 'بارگذاری محصولات/خدمات انجام نشد: $e',
          backgroundColor: Colors.orange);
      _items = [];
      _filtered = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged() {
    setState(() {
      _q = _searchCtrl.text.trim();
      _applyFilter();
    });
  }

  void _applyFilter() {
    final q = _q.toLowerCase();
    if (q.isEmpty) {
      _filtered = List<Map<String, dynamic>>.from(_items);
    } else {
      _filtered = _items.where((r) {
        final name = r['name']?.toString().toLowerCase() ?? '';
        final sku = r['sku']?.toString().toLowerCase() ?? '';
        final code = r['code']?.toString().toLowerCase() ?? '';
        return name.contains(q) || sku.contains(q) || code.contains(q);
      }).toList();
    }
  }

  String _formatPrice(dynamic p) {
    final price =
        (p is num) ? p.toDouble() : double.tryParse(p?.toString() ?? '') ?? 0.0;
    // اگر عدد صحیح است بدون اعشار نشان بده، وگرنه دو رقم اعشار
    final frac = (price == price.roundToDouble()) ? 0 : 2;
    return formatAmount(price, fractionDigits: frac);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final small = widget.compact;
    final searchHeight = small ? 40.0 : 48.0;
    final titleStyle =
        TextStyle(fontSize: small ? 14.0 : 16.0, fontWeight: FontWeight.w600);
    final subtitleStyle =
        TextStyle(fontSize: small ? 12.0 : 13.0, color: Colors.grey[700]);

    return SizedBox(
      // در حالت compact ارتفاع کمتر، در غیر اینصورت انعطافپذیر
      height: small ? 380 : null,
      child: Column(
        children: [
          // فیلد جستجو کوچک یا بزرگ بسته به compact
          SizedBox(
            height: searchHeight,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'جستجو محصولات/خدمات (نام / SKU / کد)',
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0)),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 10.0, horizontal: 12.0),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Card(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? const Center(
                          child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text('موردی یافت نشد')))
                      : ListView.separated(
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final p = _filtered[idx];
                            final id = (p['id'] is int)
                                ? p['id'] as int
                                : int.tryParse(p['id']?.toString() ?? '') ?? 0;
                            final name = p['name']?.toString() ?? '';
                            final sku = p['sku']?.toString() ?? '';
                            final priceText = _formatPrice(p['price']);
                            final isService = (p['is_service'] == true);
                            final leadingIcon = isService
                                ? Icons.miscellaneous_services
                                : Icons.inventory_2;
                            final priceSmall = Text(priceText,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: small ? 13.0 : 14.0));
                            return ListTile(
                              dense: small,
                              minVerticalPadding: small ? 4.0 : 8.0,
                              leading: Icon(leadingIcon, size: small ? 18 : 22),
                              title: Text(name, style: titleStyle),
                              subtitle: Text(
                                  isService
                                      ? 'خدمت' +
                                          (sku.isNotEmpty ? ' · $sku' : '')
                                      : (sku.isNotEmpty ? 'SKU: $sku' : ''),
                                  style: subtitleStyle),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // نمایش قیمت کنار دکمهٔ افزودن
                                  Padding(
                                    padding: EdgeInsets.only(
                                        left: small ? 8.0 : 12.0),
                                    child: priceSmall,
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(Icons.add_shopping_cart,
                                        size: small ? 18 : 22),
                                    tooltip: 'افزودن به فاکتور',
                                    onPressed: () {
                                      try {
                                        widget.onAddProduct(p);
                                        NotificationService.showToast(
                                            context, 'آیتم اضافه شد',
                                            backgroundColor: Colors.green);
                                      } catch (_) {
                                        widget.onAddProduct(p);
                                      }
                                    },
                                  ),
                                ],
                              ),
                              onTap: () {
                                widget.onAddProduct(p);
                                NotificationService.showToast(
                                    context, 'آیتم اضافه شد',
                                    backgroundColor: Colors.green);
                                widget.onFocusProduct(p);
                              },
                            );
                          },
                        ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              FilledButton.tonal(
                  onPressed: _load, child: const Text('بارگذاری مجدد')),
              const SizedBox(width: 8),
              OutlinedButton(
                  onPressed: () {
                    // پاکسازی فیلد جستجو
                    _searchCtrl.clear();
                    FocusScope.of(context).unfocus();
                  },
                  child: const Text('پاکسازی')),
            ],
          )
        ],
      ),
    );
  }
}
