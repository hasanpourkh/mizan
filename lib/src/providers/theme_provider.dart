// lib/src/providers/theme_provider.dart
// Provider ساده برای مدیریت حالت روز/شب (ThemeMode) در اپ
// فایل جدا برای تفکیک منطق تم و قابلیت استفاده در همه جای برنامه.
// کامنت‌های فارسی مختصر قرار دارد.

import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;

  ThemeProvider();

  ThemeMode get mode => _mode;

  bool get isDark {
    if (_mode == ThemeMode.system) {
      final brightness = WidgetsBinding.instance.window.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _mode == ThemeMode.dark;
  }

  void setLight() {
    _mode = ThemeMode.light;
    notifyListeners();
  }

  void setDark() {
    _mode = ThemeMode.dark;
    notifyListeners();
  }

  void toggle() {
    if (_mode == ThemeMode.dark) {
      setLight();
    } else {
      setDark();
    }
  }

  void setSystem() {
    _mode = ThemeMode.system;
    notifyListeners();
  }
}
