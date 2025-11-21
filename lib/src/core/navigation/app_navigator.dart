// lib/src/core/navigation/app_navigator.dart
// Façade سادهٔ ناوبری: یک navigatorKey یکتا فراهم می‌کند تا از ایجاد
// Navigator‌های با GlobalKey تکراری جلوگیری شود و از طریق این key
// ناوبری امن انجام شود.
// کامنت فارسی مختصر برای درک سریع هر متد.

import 'package:flutter/material.dart';

class AppNavigator {
  // GlobalKey یکتا برای Navigator اپلیکیشن
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // pushReplacementNamed امن (از طریق navigatorKey)
  static Future<dynamic>? pushReplacementNamed(String routeName,
      {Object? arguments}) {
    try {
      return navigatorKey.currentState
          ?.pushReplacementNamed(routeName, arguments: arguments);
    } catch (_) {
      return null;
    }
  }

  // pushNamed امن
  static Future<T?>? pushNamed<T extends Object?>(String routeName,
      {Object? arguments}) {
    try {
      return navigatorKey.currentState
          ?.pushNamed<T>(routeName, arguments: arguments);
    } catch (_) {
      return null;
    }
  }

  // pop امن
  static void pop<T extends Object?>([T? result]) {
    try {
      navigatorKey.currentState?.pop<T>(result);
    } catch (_) {}
  }
}
