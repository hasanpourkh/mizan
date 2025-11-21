// lib/src/pages/products/price_update/widgets/product_row.dart
// ویجتِ یک ردیف محصول در لیست بروزرسانی قیمت — شامل چک‌باکس و نمایش قیمت‌ها.
// کامنت فارسی مختصر: نمایش نام، SKU و قیمتها با فرمت مناسب.

import 'package:flutter/material.dart';
import 'package:mizan/src/core/utils/number_formatters.dart';

typedef OnToggle = void Function(bool selected);

class PriceProductRow extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool selected;
  final OnToggle onToggle;

  const PriceProductRow({
    super.key,
    required this.product,
    required this.selected,
    required this.onToggle,
  });

  String _fmt(dynamic v) {
    final val =
        (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
    final frac = (val == val.roundToDouble()) ? 0 : 2;
    return formatAmount(val, fractionDigits: frac);
  }

  @override
  Widget build(BuildContext context) {
    final id = product['id']?.toString() ?? '-';
    final name = product['name']?.toString() ?? '';
    final sale = _fmt(product['price']);
    final buy = _fmt(product['purchase_price']);
    final sku = product['sku']?.toString() ?? '';
    return ListTile(
      leading: Checkbox(
        value: selected,
        onChanged: (v) => onToggle(v ?? false),
      ),
      title: Text('$name ${sku.isNotEmpty ? "($sku)" : ""}'),
      subtitle: Text('قیمت فروش: $sale  —  قیمت خرید: $buy'),
      dense: true,
    );
  }
}
