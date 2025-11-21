// lib/src/core/utils/number_formatters.dart
// توابع کمکی فرمت و پارس اعداد با پشتیبانی از جداکننده هزارگان ('.')
// - formatAmount: فرمت مبلغ با هزارگان (اگر عدد صحیح باشد بدون اعشار، در غیر اینصورت با تعداد اعشار مشخص).
// - formatQty: نمایش تعداد بدون اعشار در صورت عدد صحیح یا تا 3 رقم اعشار در غیر اینصورت.
// - parseLocalizedToDouble: پارس رشته‌های ورودی کاربر با تشخیص جداکنندهٔ هزارگان و ممیز.
// کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'dart:math';

String _thousandSep(String s) {
  // قرار دادن '.' به‌عنوان جداکننده هزارگان
  return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}

String formatAmount(double value, {int fractionDigits = 2}) {
  if (value.isNaN || value.isInfinite) return value.toString();
  final neg = value < 0;
  final absV = value.abs();
  final intPart = absV.truncate();
  final fracPart = absV - intPart;
  final intStr = _thousandSep(intPart.toString());
  if (fracPart == 0) {
    return (neg ? '-' : '') + intStr;
  } else {
    final pow10 = pow(10, fractionDigits).toInt();
    final fracInt = ((fracPart * pow10).round()).abs();
    final fracStr = fracInt.toString().padLeft(fractionDigits, '0');
    // حذف صفرهای سمت راست در صورتی که بخواهیم (اما اینجا ثابت به fractionDigits می‌ماند)
    return '${neg ? '-' : ''}$intStr.$fracStr';
  }
}

String formatQty(double value) {
  if (value.isNaN || value.isInfinite) return value.toString();
  // اگر عدد صحیح است بدون اعشار نمایش بده
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  // در غیر اینصورت تا 3 رقم اعشار (حذف صفرهای زائد انتهای اعشار)
  final s = value.toStringAsFixed(3);
  final trimmed = s.replaceAll(RegExp(r'0+$'), '');
  return trimmed.replaceAll(RegExp(r'\.$'), '');
}

double parseLocalizedToDouble(String? input) {
  if (input == null) return 0.0;
  var s = input.trim();
  if (s.isEmpty) return 0.0;

  // نگهداشتن علامت منفی در ابتدا اگر وجود دارد
  var negative = false;
  if (s.startsWith('-')) {
    negative = true;
    s = s.substring(1).trim();
  }

  // پاکسازی کاراکترهای غیر عدد و جداکننده (حفظ '.' و ',')
  s = s.replaceAll(RegExp(r'[^\d\.,]'), '');

  final lastDot = s.lastIndexOf('.');
  final lastComma = s.lastIndexOf(',');

  String normalized;
  if (lastDot >= 0 && lastComma >= 0) {
    // هر دو وجود دارد: نمادِ آخر را به عنوان ممیز در نظر بگیر
    if (lastDot > lastComma) {
      // '.' ممیز است، ',' جداکننده هزارگان
      normalized = s.replaceAll(',', '');
    } else {
      // ',' ممیز است، '.' جداکننده هزارگان
      normalized = s.replaceAll('.', '').replaceAll(',', '.');
    }
  } else if (lastComma >= 0) {
    // فقط کاما وجود دارد: اگر بیش از یک کاما باشد احتمالا جداکننده هزارگان است -> تبدیل همه کاماها به ''
    final countComma = RegExp(r',').allMatches(s).length;
    if (countComma > 1) {
      normalized = s.replaceAll(',', '');
    } else {
      // آخرین کاما به عنوان ممیز
      normalized = s.replaceAll(',', '.');
    }
  } else if (lastDot >= 0) {
    // فقط نقطه وجود دارد: اگر بیش از یک نقطه باشد آن‌ها را جداکننده هزارگان در نظر میگیریم
    final countDot = RegExp(r'\.').allMatches(s).length;
    if (countDot > 1) {
      normalized = s.replaceAll('.', '');
    } else {
      // یک نقطه => ممکن است ممیز باشد
      normalized = s;
    }
  } else {
    normalized = s;
  }

  if (normalized.isEmpty) return 0.0;
  final parsed = double.tryParse(normalized);
  if (parsed == null) return 0.0;
  return negative ? -parsed : parsed;
}
