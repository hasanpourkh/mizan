// lib/src/pages/persons/persons_styles.dart
// فایل استایلِ مخصوص صفحهٔ "شخص جدید".
// شامل تنظیمات مرکزی مربوط به اندازه‌ها، paddingها، رنگ پس‌زمینه فیلدها و wrapper دکمه‌ها.
// برای تغییر اندازه/ظاهر کل صفحه کافیست این فایل را ویرایش کنی.
// کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'package:flutter/material.dart';

class PersonFormStyle {
  // تنظیمات عمومی فاصله‌ها و اندازه‌ها
  static const double maxFormWidth = 1100; // حداکثر پهنای فرم
  static const double horizontalPadding = 12.0;
  static const double verticalPadding = 12.0;

  // فاصله بین ستون‌ها در ردیف چند ستونه
  static const double columnGap = 12.0;

  // ارتفاع فیلد ورودی (اگر null باشد ارتفاع طبیعی استفاده میشود)
  static const double fieldHeight = 42.0;

  // padding داخلی فیلدها
  static const EdgeInsets fieldContentPadding =
      EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0);

  // شعاع آواتار
  static const double avatarRadius = 28.0;

  // اندازه دکمه‌ها (ارتفاع)
  static const double buttonHeight = 36.0;

  // اندازه متن داخل دکمه/فیلد (فونت)
  static const double fontSize = 13.0;

  // فاصله عمودی بین بخش‌ها
  static const double sectionSpacing = 10.0;

  // رنگ پس‌زمینه فیلدها (filled)
  static Color filledColor(BuildContext ctx) {
    final theme = Theme.of(ctx);
    // در تم روشن سفید/در تم تاریک خاکستری تیره
    return theme.brightness == Brightness.dark
        ? const Color(0xFF0D1117)
        : Colors.white;
  }

  // InputDecoration پیش‌فرض برای فیلدهای صفحه (filled=true)
  static InputDecoration inputDecoration(BuildContext ctx,
      {required String label, IconData? prefix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefix != null ? Icon(prefix, size: 18) : null,
      isDense: true,
      filled: true,
      fillColor: filledColor(ctx),
      contentPadding: fieldContentPadding,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
    );
  }

  // یک TextStyle پیش‌فرض برای فیلدها
  static TextStyle textStyle() {
    return const TextStyle(fontSize: fontSize);
  }

  // Wrapper برای دکمه با ارتفاع ثابت
  static Widget buttonSized({required Widget child}) {
    return SizedBox(height: buttonHeight, child: child);
  }

  // Helper برای ساخت فیلد با ارتفاع ثابت یا طبیعی
  static Widget sizedField(BuildContext ctx, Widget field) {
    if (fieldHeight != null) {
      return SizedBox(height: fieldHeight, child: field);
    }
    return field;
  }
}
