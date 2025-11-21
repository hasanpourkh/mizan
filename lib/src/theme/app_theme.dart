// lib/src/theme/app_theme.dart
// تم برنامه با پالت رنگ، فونت محلی و مقیاس‌بندی متن یکپارچه.
// - استفاده از CardThemeData برای سازگاری با نسخه‌های جدید فلاتر
// - فونت پیش‌فرض IRANSansXFaNum (مطمئن شو فایل‌ها در assets/fonts/ قرار دارند)
// کامنت‌های فارسی مختصر در هر بخش قرار دارد.

import 'package:flutter/material.dart';

class AppTheme {
  // پالت رنگ اصلی
  static const Color primary = Color(0xFF216EFD);
  static const Color primaryVariant = Color(0xFF0B5ED7);
  static const Color accent = Color(0xFF2EA44F);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color scaffoldLight = Color(0xFFF6F8FA);
  static const Color scaffoldDark = Color(0xFF0D1117);
  static const Color neutral700 = Color(0xFF24292F);
  static const Color neutral500 = Color(0xFF6E7781);

  static const double borderRadius = 10.0;

  // تابع کمکی ایجاد TextTheme با فونت پروژه
  static TextTheme _buildTextTheme(TextTheme base, String fontFamily) {
    return base.copyWith(
      titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: neutral700,
          fontFamily: fontFamily),
      titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: neutral700,
          fontFamily: fontFamily),
      bodyLarge:
          TextStyle(fontSize: 15, color: neutral700, fontFamily: fontFamily),
      bodyMedium:
          TextStyle(fontSize: 14, color: neutral500, fontFamily: fontFamily),
      bodySmall:
          TextStyle(fontSize: 13, color: neutral500, fontFamily: fontFamily),
      labelLarge: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, fontFamily: fontFamily),
    );
  }

  // تم روشن
  static ThemeData lightTheme({String fontFamily = 'IRANSansXFaNum'}) {
    final base = ThemeData(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: surface,
        onPrimary: Colors.white,
        onSurface: neutral700,
      ),
      scaffoldBackgroundColor: scaffoldLight,
      useMaterial3: true,
      fontFamily: fontFamily,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    // AppBar سفارشی
    final appBar = AppBarTheme(
      backgroundColor: surface,
      foregroundColor: neutral700,
      elevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(
          color: neutral700,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily),
      iconTheme: const IconThemeData(color: neutral700),
    );

    final elevatedButton = ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius)),
        textStyle:
            TextStyle(fontWeight: FontWeight.w600, fontFamily: fontFamily),
      ),
    );

    final filledButton = FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryVariant,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius)),
        textStyle: TextStyle(fontFamily: fontFamily),
      ),
    );

    final inputDecoration = base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Colors.grey.shade200)),
    );

    // کارت‌ها: استفاده از CardThemeData برای سازگاری با API جدید
    final card = CardThemeData(
      color: surface,
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    );

    return base.copyWith(
      appBarTheme: appBar,
      elevatedButtonTheme: elevatedButton,
      filledButtonTheme: filledButton,
      textTheme: _buildTextTheme(base.textTheme, fontFamily),
      inputDecorationTheme: inputDecoration,
      cardTheme: card,
      dividerColor: Colors.grey.shade200,
    );
  }

  // تم تیره
  static ThemeData darkTheme({String fontFamily = 'IRANSansXFaNum'}) {
    final base = ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: Color(0xFF161B22),
        onPrimary: Colors.white,
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: scaffoldDark,
      useMaterial3: true,
      fontFamily: fontFamily,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    final appBar = AppBarTheme(
      backgroundColor: const Color(0xFF0B1220),
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily),
      iconTheme: const IconThemeData(color: Colors.white),
    );

    final elevatedButton = ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 1,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius)),
        textStyle: TextStyle(fontFamily: fontFamily),
      ),
    );

    final filledButton = FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryVariant,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius)),
        textStyle: TextStyle(fontFamily: fontFamily),
      ),
    );

    final inputDecoration = base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: const Color(0xFF0D1117),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Colors.grey.shade800)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Colors.grey.shade800)),
    );

    final card = CardThemeData(
      color: const Color(0xFF0B1220),
      elevation: 1.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    );

    return base.copyWith(
      appBarTheme: appBar,
      elevatedButtonTheme: elevatedButton,
      filledButtonTheme: filledButton,
      textTheme: _buildTextTheme(base.textTheme, fontFamily)
          .apply(bodyColor: Colors.white, displayColor: Colors.white),
      inputDecorationTheme: inputDecoration,
      cardTheme: card,
      dividerColor: const Color(0xFF21262D),
    );
  }
}
