// lib/src/pages/sales/sale_cart.dart
// ویجت سبد خرید — ریسپانسیو و جلوگیری از overflow:
// - در پنجره‌های باریک هر خط به صورت ستونی نمایش داده میشود (خط نام/توضیحات بالا و کنترل‌ها زیر آن).
// - اندازه فیلدها منعطف شده و از Wrap/Flexible استفاده شده است.
// - کنترل ورودی‌ها همچنان مقادیر را به مدل اعمال می‌کنند و موجودی بررسی میشود.
// - کامنت فارسی مختصر برای درک سریع قرار دارد.

import 'package:flutter/material.dart';
import 'sale_models.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/utils/number_formatters.dart';

class SaleCart extends StatefulWidget {
  final List<SaleLine> lines;
  final void Function(List<SaleLine> newLines) onChanged;
  final void Function() onRequestRecalc;

  // compact: در لیست محصولات کوچک‌تر نمایش داده شود (برای استفاده در حالت موبایل)
  final bool compact;

  const SaleCart(
      {super.key,
      required this.lines,
      required this.onChanged,
      required this.onRequestRecalc,
      this.compact = false});

  @override
  State<SaleCart> createState() => _SaleCartState();
}

class _SaleCartState extends State<SaleCart> {
  static const double _fieldHeight = 40;
  static const double _fontSize = 13;

  @override
  void initState() {
    super.initState();
  }

  void _update() {
    for (final l in widget.lines) {
      l.recalc();
    }
    widget.onChanged(List<SaleLine>.from(widget.lines));
    widget.onRequestRecalc();
    setState(() {});
  }

  void _removeLine(int idx) {
    widget.lines.removeAt(idx);
    _update();
  }

  Future<double> _getAvailableQtyForLine(SaleLine line) async {
    if (line.productId == null) return 0.0;
    try {
      final avail = await AppDatabase.getQtyForItemInWarehouse(
          line.productId, line.warehouseId);
      return avail;
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> _onQtyChanged(
      String v, SaleLine line, TextEditingController ctrl) async {
    final parsed = parseLocalizedToDouble(v);
    if (parsed <= 0) {
      NotificationService.showToast(context, 'مقدار باید بزرگتر از صفر باشد',
          backgroundColor: Colors.orange);
      ctrl.text = _formatQty(line.qty);
      return;
    }
    final avail = await _getAvailableQtyForLine(line);
    if (parsed > avail) {
      NotificationService.showError(context, 'موجودی کافی نیست',
          'موجودی این کالا ${_formatQty(avail)} واحد است. بیش از این نمیتوانید اضافه کنید.');
      line.qty = avail;
      line.recalc();
      ctrl.text = _formatQty(avail);
      _update();
      return;
    }
    line.qty = parsed;
    line.recalc();
    _update();
  }

  void _onPriceChanged(String v, SaleLine line, TextEditingController ctrl) {
    final parsed = parseLocalizedToDouble(v);
    line.unitPrice = parsed;
    line.recalc();
    // بازنشانی نمایش به فرمت هزارگان
    ctrl.text = formatAmount(line.unitPrice,
        fractionDigits:
            line.unitPrice == line.unitPrice.roundToDouble() ? 0 : 2);
    _update();
  }

  void _onDiscountChanged(String v, SaleLine line, TextEditingController ctrl) {
    final parsed = parseLocalizedToDouble(v);
    line.discount = parsed;
    line.recalc();
    ctrl.text = formatAmount(line.discount, fractionDigits: 2);
    _update();
  }

  String _formatQty(double value) {
    // اگر عدد صحیح است بدون اعشار نمایش بده، در غیر اینصورت تا 3 رقم اعشار نمایش بده
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty) {
      return const Center(
          child: Text('سبد خالی است — از لیست محصولات محصول اضافه کنید'));
    }
    return LayoutBuilder(builder: (ctx, constraints) {
      final maxW = constraints.maxWidth;
      final narrow = maxW < 700 || widget.compact;

      return ListView.separated(
        itemCount: widget.lines.length,
        separatorBuilder: (_, __) => const Divider(height: 6),
        itemBuilder: (ctx, idx) {
          final l = widget.lines[idx];
          final qtyCtrl = TextEditingController(text: _formatQty(l.qty));
          final priceCtrl = TextEditingController(
              text: formatAmount(l.unitPrice,
                  fractionDigits:
                      l.unitPrice == l.unitPrice.roundToDouble() ? 0 : 2));
          final discountCtrl = TextEditingController(
              text: formatAmount(l.discount, fractionDigits: 2));

          // نمای خط در حالت باریک: ستون با نام محصول در بالا و کنترلها در زیر (در Wrap)
          if (narrow) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(l.productName,
                          style: const TextStyle(
                              fontSize: _fontSize,
                              fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.red, size: 20),
                        onPressed: () => _removeLine(idx),
                        tooltip: 'حذف خط'),
                  ]),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.start,
                    children: [
                      SizedBox(
                        width: 92,
                        height: _fieldHeight,
                        child: TextField(
                          controller: qtyCtrl,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: _fontSize),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 6),
                              border: OutlineInputBorder(),
                              labelText: 'تعداد'),
                          onChanged: (v) => _onQtyChanged(v, l, qtyCtrl),
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        height: _fieldHeight,
                        child: TextField(
                          controller: priceCtrl,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: _fontSize),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 6),
                              border: OutlineInputBorder(),
                              labelText: 'قیمت'),
                          onChanged: (v) => _onPriceChanged(v, l, priceCtrl),
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        height: _fieldHeight,
                        child: TextField(
                          controller: discountCtrl,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: _fontSize),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 6),
                              border: OutlineInputBorder(),
                              labelText: 'تخفیف'),
                          onChanged: (v) =>
                              _onDiscountChanged(v, l, discountCtrl),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: Text(
                            'جمع: ${formatAmount(((l.unitPrice * l.qty) - l.discount), fractionDigits: ((l.unitPrice * l.qty - l.discount) == (l.unitPrice * l.qty - l.discount).roundToDouble()) ? 0 : 2)}',
                            style: const TextStyle(
                                fontSize: _fontSize,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          // حالت پهن: نمایش سطری (دسکتاپ)
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.productName,
                            style: const TextStyle(
                                fontSize: _fontSize,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(
                            'قیمت خرید: ${formatAmount(l.purchasePrice, fractionDigits: l.purchasePrice == l.purchasePrice.roundToDouble() ? 0 : 2)}',
                            style: const TextStyle(
                                fontSize: _fontSize - 1, color: Colors.grey)),
                      ]),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  height: _fieldHeight,
                  child: TextField(
                    controller: qtyCtrl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: _fontSize),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        border: OutlineInputBorder(),
                        labelText: 'تعداد'),
                    onChanged: (v) => _onQtyChanged(v, l, qtyCtrl),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  height: _fieldHeight,
                  child: TextField(
                    controller: priceCtrl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: _fontSize),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        border: OutlineInputBorder(),
                        labelText: 'قیمت واحد'),
                    onChanged: (v) => _onPriceChanged(v, l, priceCtrl),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  height: _fieldHeight,
                  child: TextField(
                    controller: discountCtrl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: _fontSize),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        border: OutlineInputBorder(),
                        labelText: 'تخفیف'),
                    onChanged: (v) => _onDiscountChanged(v, l, discountCtrl),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                    width: 110,
                    child: Text(
                        'جمع: ${formatAmount(((l.unitPrice * l.qty) - l.discount), fractionDigits: (((l.unitPrice * l.qty) - l.discount) == ((l.unitPrice * l.qty) - l.discount).roundToDouble()) ? 0 : 2)}',
                        style: const TextStyle(
                            fontSize: _fontSize, fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _removeLine(idx),
                    tooltip: 'حذف خط'),
              ],
            ),
          );
        },
      );
    });
  }
}
