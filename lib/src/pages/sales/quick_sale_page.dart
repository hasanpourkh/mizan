//github.com/hasanpourkh/mizan/blob/main/lib/src/pages/sales/quick_sale_page.dart
// lib/src/pages/sales/quick_sale_page.dart
// صفحهٔ فروش سریع — انتخاب محصول/خدمت و ثبت فوری با پرداخت نقدی خودکار.
// - نمایش و مدیریت سبد ساده.
// - وقتی سبد تغییر کند فیلد پرداخت خودکار با جمع کل پر می‌شود مگر کاربر دستی آن را ویرایش کند.
// - برای محصولات اعتبار موجودی بررسی می‌شود؛ خدمات نامحدود هستند.
// - توضیح خیلی خیلی کوتاه: فایل کامل و سازگار.

import 'package:flutter/material.dart';
import 'sale_models.dart';
import 'sale_product_list.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';
import 'package:intl/intl.dart';

class QuickSalePage extends StatefulWidget {
  const QuickSalePage({super.key});

  @override
  State<QuickSalePage> createState() => _QuickSalePageState();
}

class _QuickSalePageState extends State<QuickSalePage> {
  final List<SaleLine> _cart = [];
  bool _loading = true;
  bool _saving = false;
  final NumberFormat _nf = NumberFormat.decimalPattern();

  final TextEditingController _paidAmountCtrl =
      TextEditingController(text: '0');
  bool _paidManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    // صفحهٔ سریع: سریع آماده می‌شود
    setState(() => _loading = false);
  }

  double get _subtotal {
    double s = 0.0;
    for (final l in _cart) s += (l.unitPrice * l.qty) - (l.discount ?? 0.0);
    return s;
  }

  // وقتی سبد تغییر کند، پرداخت خودکار پر میشود مگر ویرایش دستی شده باشد
  void _onCartChanged() {
    if (!_paidManuallyEdited) {
      _paidAmountCtrl.text = _subtotal.toStringAsFixed(0);
    }
    setState(() {});
  }

  Future<void> _addProduct(Map<String, dynamic> item) async {
    try {
      final isService = item['is_service'] == true;
      final productId = (item['id'] is int)
          ? item['id'] as int
          : int.tryParse(item['id']?.toString() ?? '') ?? 0;
      final salePrice = (item['price'] is num)
          ? (item['price'] as num).toDouble()
          : double.tryParse(item['price']?.toString() ?? '') ?? 0.0;
      final purchasePrice = isService
          ? 0.0
          : (item['purchase_price'] is num
              ? (item['purchase_price'] as num).toDouble()
              : double.tryParse(item['purchase_price']?.toString() ?? '') ??
                  0.0);
      final name = item['name']?.toString() ?? '';

      if (!isService) {
        final avail = await AppDatabase.getQtyForItemInWarehouse(productId, 0);
        if (avail <= 0) {
          NotificationService.showToast(
              context, 'این کالا فعلاً رفته سفر مولد انبار! موجودی صفره 😅',
              backgroundColor: Colors.orange);
          return;
        }
        final existing = _cart
            .where((c) => c.productId == productId && !c.isService)
            .toList();
        if (existing.isNotEmpty) {
          final ex = existing.first;
          final wouldBe = ex.qty + 1.0;
          if (wouldBe > avail) {
            NotificationService.showToast(context,
                'آقا/خانم، بیشتر از موجودی نمیشه! موجودی: ${_nf.format(avail)}',
                backgroundColor: Colors.orange);
            return;
          }
          ex.qty = wouldBe;
          ex.recalc();
          _onCartChanged();
          return;
        }
      } else {
        final existing = _cart
            .where((c) => c.productId == productId && c.isService)
            .toList();
        if (existing.isNotEmpty) {
          final ex = existing.first;
          ex.qty += 1.0;
          ex.recalc();
          _onCartChanged();
          return;
        }
      }

      final line = SaleLine(
          productId: productId,
          productName: name,
          warehouseId: 0,
          qty: 1.0,
          unitPrice: salePrice,
          purchasePrice: purchasePrice,
          isService: isService);
      setState(() => _cart.add(line));
      _onCartChanged();
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'افزودن به سبد انجام نشد: $e');
    }
  }

  Future<void> _quickCheckout() async {
    if (_cart.isEmpty) {
      NotificationService.showError(context, 'خطا', 'سبد خالی است');
      return;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final saleMap = <String, dynamic>{
        'invoice_no': 'QS$now',
        'title': 'فروش سریع',
        'customer_id': null,
        'actor': null,
        'total': double.parse(_subtotal.toStringAsFixed(4)),
        'subtotal': double.parse(_subtotal.toStringAsFixed(4)),
        'discount': 0.0,
        'tax': 0.0,
        'extra_charges': 0.0,
        'notes': 'فروش سریع',
        'created_at': now,
      };

      final lines = _cart.map((l) => l.toMapForDb()).toList();
      final saleId = await AppDatabase.saveSale(saleMap, lines);

      double paid =
          double.tryParse(_paidAmountCtrl.text.replaceAll(',', '.')) ?? 0.0;
      if (paid <= 0) paid = _subtotal;

      final paymentInfo = <String, dynamic>{
        'method': 'cash',
        'amount': double.parse(paid.toStringAsFixed(4)),
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'note': 'پرداخت نقدی (فروش سریع)'
      };

      try {
        await AppDatabase.setSalePaymentInfo(saleId, paymentInfo);
      } catch (_) {}

      NotificationService.showSuccess(
          context, 'ثبت شد', 'فروش سریع ثبت و پرداخت نقدی انجام شد', onOk: () {
        setState(() => _cart.clear());
        _onCartChanged();
      });
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'ثبت فروش سریع انجام نشد: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildCart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('سبد فروش سریع',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_cart.isEmpty) const Center(child: Text('سبد خالی است')),
          ..._cart.map((l) {
            return ListTile(
              title: Text(l.productName),
              subtitle:
                  Text('تعداد: ${l.qty}  —  قیمت: ${_nf.format(l.unitPrice)}'),
              trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _cart.remove(l);
                      _onCartChanged();
                    });
                  }),
            );
          }).toList(),
          const Divider(),
          Row(children: [
            Expanded(
                child: Text('جمع: ${_nf.format(_subtotal)}',
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            SizedBox(
              width: 220,
              child: TextField(
                controller: _paidAmountCtrl,
                decoration: InputDecoration(
                    labelText: 'مبلغ پرداختی (پیشفرض ${_nf.format(_subtotal)})',
                    isDense: true),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  setState(() => _paidManuallyEdited = true);
                },
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
                onPressed: _saving ? null : _quickCheckout,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('ثبت و دریافت نقدی')),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('فروش سریع')),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final left = SizedBox(
          width: wide ? 520 : double.infinity,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SaleProductList(
                  onAddProduct: (item) async => _addProduct(item),
                  onFocusProduct: (_) {}),
            ),
          ),
        );

        final right = Expanded(
            child: Padding(
                padding: const EdgeInsets.all(8.0), child: _buildCart()));

        if (wide) {
          return Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(children: [left, const SizedBox(width: 12), right]));
        } else {
          return Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                  children: [left, const SizedBox(height: 8), _buildCart()]));
        }
      }),
    );
  }
}
