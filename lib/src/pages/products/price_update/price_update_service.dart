// lib/src/pages/products/price_update/price_update_service.dart
// سرویس محاسبات و اعمال تغییر قیمت به DB (کاملاً مستقل و تست‌پذیر).
// کامنت فارسی مختصر: محاسبهٔ قیمت جدید، گرد کردن، و ذخیره در DB از طریق AppDatabase.

import 'dart:math';
import 'package:mizan/src/core/db/app_database.dart';

class PriceUpdateParams {
  final String targetField; // 'price' یا 'purchase_price'
  final bool isPercent; // true => درصد، false => مبلغ
  final double value; // درصد (مثلاً 10 برای 10%) یا مبلغ (ریال)
  final bool increase; // true: افزایش، false: کاهش
  final int roundingZeros; // 0..5 (0 => خیر)

  PriceUpdateParams({
    required this.targetField,
    required this.isPercent,
    required this.value,
    required this.increase,
    required this.roundingZeros,
  });
}

/// گرد کردن به نزدیک‌ترین 10^n (مثلاً zeros=2 => گرد به نزدیک‌ترین 100)
double _applyRounding(double v, int zeros) {
  if (zeros <= 0) return v;
  final factor = pow(10, zeros).toDouble();
  return (v / factor).roundToDouble() * factor;
}

/// محاسبهٔ مقدار جدید بر اساس پارامترها و مقدار فعلی
double computeNewPrice(double current, PriceUpdateParams p) {
  double newVal = current;
  if (p.isPercent) {
    final delta = current * (p.value / 100.0);
    newVal = p.increase ? (current + delta) : (current - delta);
  } else {
    final delta = p.value;
    newVal = p.increase ? (current + delta) : (current - delta);
  }
  if (newVal < 0) newVal = 0.0;
  newVal = _applyRounding(newVal, p.roundingZeros);
  return double.parse(newVal.toStringAsFixed(4));
}

/// اعمال تغییر روی یک محصول (با id) — مقدار جدید را در DB ذخیره میکند
Future<void> applyPriceUpdateToProduct(
    int productId, PriceUpdateParams p) async {
  final prod = await AppDatabase.getProductById(productId);
  if (prod == null) return;

  // مقدار فعلی هدف را دقیق خوانده و به double تبدیل کن
  final cur = (p.targetField == 'price')
      ? (prod['price'] is num
          ? (prod['price'] as num).toDouble()
          : double.tryParse(prod['price']?.toString() ?? '') ?? 0.0)
      : (prod['purchase_price'] is num
          ? (prod['purchase_price'] as num).toDouble()
          : double.tryParse(prod['purchase_price']?.toString() ?? '') ?? 0.0);

  final newVal = computeNewPrice(cur, p);

  // نسخهٔ بروزشده را آماده و ذخیره کن (saveProduct برای update نیاز به id دارد)
  final updated = Map<String, dynamic>.from(prod);
  updated[p.targetField] = newVal;
  updated['id'] = prod['id']; // اطمینان از وجود id برای update

  await AppDatabase.saveProduct(updated);
}
