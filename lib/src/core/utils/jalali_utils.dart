// lib/src/core/utils/jalali_utils.dart
// توابع کمکی برای کار با تاریخ شمسی (Jalali) بدون وابستگی به persian_datetime_picker.
// - از پکیج shamsi_date برای تبدیل بین Jalali <-> Gregorian استفاده می‌شود.
// - تابع pickJalaliDate از showDatePicker (گرگوریان) استفاده می‌کند و نتیجه را به رشتهٔ
//   فرمت 'yyyy/MM/dd' (شمسی) باز می‌گرداند.
// - توابع parse/format نیز برای کار با رشته‌های ذخیره‌شده فراهم است.
//
// کامنت‌های فارسی مختصر جهت فهم عملکرد هر تابع قرار دارد.

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

String _two(int v) => v.toString().padLeft(2, '0');

/// تبدیل یک Jalali به رشته 'yyyy/MM/dd'
String jalaliToString(Jalali j) {
  return '${j.year}/${_two(j.month)}/${_two(j.day)}';
}

/// تلاش برای تبدیل رشته‌ای مانند '1402/08/01' یا '1402-08-01' به شیء Jalali
/// در صورت ناموفقیت null برمی‌گرداند.
Jalali? parseJalaliString(String s) {
  try {
    final normalized = s.replaceAll('-', '/').trim();
    final parts = normalized.split('/');
    if (parts.length < 3) return null;
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    return Jalali(y, m, d);
  } catch (_) {
    return null;
  }
}

/// تبدیل رشتهٔ Jalali به DateTime (Gregorian) — null در صورت خطا
DateTime? jalaliStringToDateTime(String s) {
  final j = parseJalaliString(s);
  if (j == null) return null;
  return j.toDateTime();
}

/// تبدیل DateTime (گرگوریان) به رشتهٔ Jalali 'yyyy/MM/dd'
String dateTimeToJalaliString(DateTime dt) {
  final j = Jalali.fromDateTime(dt);
  return jalaliToString(j);
}

/// نمایش DatePicker (گرگوریان) و بازگرداندن تاریخ انتخاب‌شده به صورت رشتهٔ Jalali.
/// - initialJalali: اگر رشته Jalali اولیه داری آنرا به DateTime تبدیل و بعنوان initialDate استفاده می‌کنیم.
/// - در صورت cancel یا خطا null برمی‌گردد.
Future<String?> pickJalaliDate(BuildContext context,
    {String? initialJalali}) async {
  DateTime initial = DateTime.now();
  try {
    if (initialJalali != null && initialJalali.trim().isNotEmpty) {
      final dt = jalaliStringToDateTime(initialJalali);
      if (dt != null) initial = dt;
    }
  } catch (_) {}

  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1900),
    lastDate: DateTime(2100),
  );

  if (picked == null) return null;
  return dateTimeToJalaliString(picked);
}
