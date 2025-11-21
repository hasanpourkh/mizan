// lib/src/pages/products/products_list_page.dart
// فهرست محصولات: نمایش قیمت خرید، قیمت فروش و نقطهٔ سفارش؛ اسکرول افقی کنترل‌شده تا دکمه‌ها همیشه قابل دسترسی باشند.
// توضیح خیلی خیلی کوتاه: ستون‌های purchase_price / price / reorder_point اضافه شدند و جدول افقی اسکرول می‌شود.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';
import 'new_product_page.dart';
import '../../core/utils/number_formatters.dart';

class ProductsListPage extends StatefulWidget {
  const ProductsListPage({super.key});

  @override
  State<ProductsListPage> createState() => _ProductsListPageState();
}

class _ProductsListPageState extends State<ProductsListPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String _q = '';
  final ScrollController _hController = ScrollController(); // اسکرول افقی

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
      final prods = await AppDatabase.getProducts();
      setState(() => _rows = prods);
    } catch (e) {
      setState(() => _rows = []);
      NotificationService.showToast(context, 'بارگذاری محصولات انجام نشد: $e',
          backgroundColor: Colors.orange);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف محصول'),
          content: const Text(
              'آیا از حذف این محصول اطمینان دارید؟ این عملیات موجودی و حرکات مرتبط را نیز ثبت خواهد کرد.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('لغو')),
            FilledButton.tonal(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('حذف')),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await AppDatabase.deleteProduct(id);
        NotificationService.showToast(context, 'محصول حذف شد');
        await _load();
      } catch (e) {
        NotificationService.showError(context, 'خطا', 'حذف انجام نشد: $e');
      }
    }
  }

  Future<double> _getTotalStock(int itemId) async {
    try {
      final qty = await AppDatabase.getQtyForItemInWarehouse(itemId, 0);
      return qty;
    } catch (_) {
      return 0.0;
    }
  }

  // حرکت افقی برنامهای
  Future<void> _scrollBy(double offset) async {
    try {
      final max = _hController.position.maxScrollExtent;
      final min = _hController.position.minScrollExtent;
      final target = (_hController.offset + offset).clamp(min, max);
      await _hController.animateTo(target,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } catch (_) {}
  }

  String _formatQty(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _q.trim().isEmpty
        ? _rows
        : _rows.where((r) {
            final name = r['name']?.toString().toLowerCase() ?? '';
            final sku = r['sku']?.toString().toLowerCase() ?? '';
            final code = r['product_code']?.toString().toLowerCase() ?? '';
            return name.contains(_q.toLowerCase()) ||
                sku.contains(_q.toLowerCase()) ||
                code.contains(_q.toLowerCase());
          }).toList();

    // ستونها: شامل قیمت خرید، قیمت فروش و نقطه سفارش
    const columns = [
      DataColumn(label: Text('کد')),
      DataColumn(label: Text('نام')),
      DataColumn(label: Text('SKU')),
      DataColumn(label: Text('قیمت خرید')),
      DataColumn(label: Text('قیمت فروش')),
      DataColumn(label: Text('نقطه سفارش')),
      DataColumn(label: Text('موجودی (جمع)')),
      DataColumn(label: Text('عملیات')),
    ];

    const estimatedColumnWidth = 160;
    final estimatedWidth = columns.length * estimatedColumnWidth;

    return Scaffold(
      appBar: AppBar(title: const Text('فهرست محصولات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(children: [
                    Expanded(
                        child: TextField(
                            decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: 'جستجو...'),
                            onChanged: (v) => setState(() => _q = v))),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                        onPressed: () => Navigator.of(context)
                            .pushNamed('/products/new')
                            .then((_) => _load()),
                        child: const Text('افزودن')),
                    const SizedBox(width: 8),
                    OutlinedButton(
                        onPressed: _load, child: const Text('بارگذاری مجدد')),
                  ]),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Card(
                      child: LayoutBuilder(builder: (ctx, constraints) {
                        final viewportWidth = constraints.maxWidth.isFinite
                            ? constraints.maxWidth
                            : MediaQuery.of(context).size.width;
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
                                      rows: filtered.map((r) {
                                        final id = (r['id'] is int)
                                            ? r['id'] as int
                                            : int.tryParse(
                                                    r['id']?.toString() ??
                                                        '') ??
                                                0;
                                        final code =
                                            r['product_code']?.toString() ?? '';
                                        final name =
                                            r['name']?.toString() ?? '';
                                        final sku = r['sku']?.toString() ?? '';
                                        final purchaseVal =
                                            (r['purchase_price'] is num)
                                                ? (r['purchase_price'] as num)
                                                    .toDouble()
                                                : double.tryParse(
                                                        r['purchase_price']
                                                                ?.toString() ??
                                                            '') ??
                                                    0.0;
                                        final saleVal = (r['price'] is num)
                                            ? (r['price'] as num).toDouble()
                                            : double.tryParse(
                                                    r['price']?.toString() ??
                                                        '') ??
                                                0.0;
                                        final reorder =
                                            r['reorder_point']?.toString() ??
                                                '0';
                                        return DataRow(cells: [
                                          DataCell(Text(code)),
                                          DataCell(Text(name)),
                                          DataCell(Text(sku)),
                                          DataCell(Text(formatAmount(
                                              purchaseVal,
                                              fractionDigits: purchaseVal ==
                                                      purchaseVal
                                                          .roundToDouble()
                                                  ? 0
                                                  : 2))),
                                          DataCell(Text(formatAmount(saleVal,
                                              fractionDigits: saleVal ==
                                                      saleVal.roundToDouble()
                                                  ? 0
                                                  : 2))),
                                          DataCell(Text(reorder)),
                                          DataCell(FutureBuilder<double>(
                                            future: _getTotalStock(id),
                                            builder: (c, s) {
                                              if (!s.hasData) {
                                                return const Text('...');
                                              }
                                              return Text(_formatQty(s.data!));
                                            },
                                          )),
                                          DataCell(Row(children: [
                                            IconButton(
                                                icon: const Icon(Icons.edit),
                                                tooltip: 'ویرایش',
                                                onPressed: () async {
                                                  final prod =
                                                      Map<String, dynamic>.from(
                                                          r);
                                                  await Navigator.of(context)
                                                      .push(MaterialPageRoute(
                                                          builder: (_) =>
                                                              NewProductPage(
                                                                  editing:
                                                                      prod)));
                                                  _load();
                                                }),
                                            IconButton(
                                                icon: const Icon(Icons.delete,
                                                    color: Colors.red),
                                                tooltip: 'حذف',
                                                onPressed: () => _delete(id)),
                                          ])),
                                        ]);
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
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
                                    'برای دسترسی به ستون‌ها از اسکرول افقی استفاده کنید',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[700])),
                              ],
                            ),
                          ),
                        ]);
                      }),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
