// lib/main.dart
// ورودی برنامه — تغییر: برای جلوگیری از نمایش صفحهٔ onboarding به‌صورت خودکار
// حالا initialRoute همیشه /login است مگر اینکه خطای init دیتابیس رخ دهد.
// - توجه: این تغییر فقط مانع هدایت خودکار به /onboarding می‌شود؛ فایل‌های onboarding دست نخورده‌اند.
// - توضیح خیلی کوتاه (فارسی): اگر خواستی دوباره onboarding فعال بشه اطلاع بده تا شرط hasBusinessProfile بازگردانده شود.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/app.dart';
import 'src/providers/auth_provider.dart';
import 'src/providers/theme_provider.dart';
import 'src/core/db/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // فعالسازی sqflite_ffi برای دسکتاپ
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  String? initErrorMessage;
  bool dbInitialized = false;
  // تغییر مهم: initialRoute را پیشفرض روی '/login' قرار میدهیم تا onboarding خودکار نمایش داده نشود
  String initialRoute = '/login';

  try {
    await AppDatabase.init();
    dbInitialized = true;
    // اگر خواستی شرط هدایت خودکار بر اساس وجود پروفایل را بازگردانیم:
    // final hasProfile = await AppDatabase.hasBusinessProfile();
    // initialRoute = hasProfile ? '/login' : '/onboarding';
    // اما فعلاً همیشه به /login میرویم تا صفحهٔ onboarding باز نشود.
  } catch (e) {
    initErrorMessage = e.toString();
    initialRoute = '/db-error';
  }

  runApp(
    MultiProvider(
      providers: [
        // Providers برنامه — فقط provider های اصلی نگه داشته شده‌اند.
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MyApp(
        initialRoute: initialRoute,
        dbInitErrorMessage: initErrorMessage,
        dbInitialized: dbInitialized,
      ),
    ),
  );
}
