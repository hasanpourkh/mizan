// lib/src/providers/auth_provider.dart
// Provider مدیریت احراز هویت و لایسنس — ایمن‌سازی فراخوانی‌های دیتابیس
// - قبل از استفاده از AppDatabase تلاش برای init انجام میدهیم (در صورت امکان).
// - همهٔ فراخوانی‌های مربوط به sqlite در try/catch قرار گرفتند تا اپ کرش نکند
//   اگر دیتابیس مقداردهی نشده یا مسیر تنظیم نشده باشد.
// - کامنتهای فارسی مختصر برای هر بخش قرار دارد.

import 'package:flutter/material.dart';
import '../core/api/api_service.dart';
import '../core/device/device_id_windows.dart';
import '../core/license/license_manager.dart';
import '../core/db/app_database.dart'; // استفاده از facade یکپارچهٔ AppDatabase
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class _Result {
  final bool success;
  final String message;
  _Result(this.success, this.message);
}

class AuthProvider extends ChangeNotifier {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  String? licenseToken;
  Map<String, dynamic>? licensePayload;

  AuthProvider() {
    _loadFromStorage();
  }

  // بارگذاری توکن محلی و اعتبارسنجی اولیه (آفلاین)
  Future<void> _loadFromStorage() async {
    licenseToken = await _secure.read(key: 'license_token');
    if (licenseToken != null) {
      final payload = await LicenseManager.verifyJwtOffline(licenseToken!);
      if (payload != null) {
        licensePayload = payload;
      } else {
        // توکن محلی نامعتبر شده -> حذف میشود
        licenseToken = null;
        await _secure.delete(key: 'license_token');
      }
    }
    notifyListeners();
  }

  // ثبتنام: ارسال درخواست به سرور و درج رکورد محلی pending (در صورت امکان)
  Future<_Result> registerUser({
    required String email,
    required String firstName,
    required String lastName,
    required String username,
    required String phone,
    required String storeName,
  }) async {
    final deviceHash = await DeviceId.getDeviceHash();
    final res = await ApiService.register(
      email: email,
      firstName: firstName,
      lastName: lastName,
      username: username,
      phone: phone,
      storeName: storeName,
      deviceHash: deviceHash,
    );

    if (res['success'] == true) {
      // تلاش برای درج رکورد محلی؛ اگر دیتابیس مقداردهی نشده باشد فقط از آن عبور می‌کنیم
      try {
        // اگر دیتابیس init نشده، سعی کن init کنی (اگر مسیر تنظیم نشده باشد init خطا میدهد و catch میشود)
        try {
          await AppDatabase.init();
        } catch (_) {
          // اگر init ناموفق بود، ادامه میدهیم بدون درج محلی
        }

        await AppDatabase.insertPendingRequest({
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'username': username,
          'phone': phone,
          'store_name': storeName,
          'device_hash': deviceHash,
          'status': 'pending',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (e) {
        // در صورت خطا در درج محلی (مثلاً DB مقداردهی نشده)، صرفاً لاگ می‌کنیم و ادامه می‌دهیم
        // (می‌توانی این خطا را به لاگ فایل یا سرویس خطایابی بفرستی)
      }

      return _Result(true, res['message'] ?? 'درخواست ارسال شد.');
    }

    return _Result(false, res['message']?.toString() ?? 'خطا در ثبتنام');
  }

  // ورود/بررسی لایسنس با ایمیل یا deviceHash
  // عملکرد:
  // - تماس با سرور برای بررسی لایسنس
  // - در صورت دریافت token: اعتبارسنجی آفلاین، ذخیره امن و بروزرسانی وضعیت محلی (امکان‌پذیر باشد)
  // - در صورت عدم دریافت token: در صورت وجود status از سرور، تلاش برای بروزرسانی وضعیت محلی انجام میشود (در try/catch)
  Future<_Result> loginWithEmail(String email) async {
    final deviceHash = await DeviceId.getDeviceHash();
    final res = await ApiService.check(deviceHash: deviceHash, email: email);

    // اگر سرور لایسنس فعال برگرداند
    if (res['success'] == true && res['license_token'] != null) {
      final token = res['license_token'] as String;
      // اعتبارسنجی آفلاین توکن با public key (در صورت فعال بودن)
      final payload = await LicenseManager.verifyJwtOffline(token);
      if (payload != null) {
        // ذخیره امن توکن
        try {
          await _secure.write(key: 'license_token', value: token);
        } catch (_) {}
        licenseToken = token;
        licensePayload = payload;

        // تلاش برای بروزرسانی وضعیت محلی به active (اگر ممکن باشد)
        try {
          // init ممکن است خطا بدهد اگر مسیر تنظیم نشده باشد؛ در آن صورت catch می‌شود
          try {
            await AppDatabase.init();
          } catch (_) {}
          await AppDatabase.updateRequestStatusByEmailOrDevice(
              email: email, deviceHash: deviceHash, status: 'active');
        } catch (_) {
          // اگر دیتابیس مقداردهی نشده یا عملیات ناموفق بود، نادیده می گیریم
        }

        notifyListeners();
        return _Result(true, 'ورود موفق. لایسنس معتبر است.');
      } else {
        // اگر توکن نامعتبر باشد، پیام مناسب بده
        return _Result(false, 'توکن دریافت شده نامعتبر یا منقضی است.');
      }
    } else {
      // پاسخ ناموفق: ممکن است pending یا rejected یا expired باشد
      final msg = res['message']?.toString() ?? 'لایسنس فعال یافت نشد.';
      // اگر سرور وضعیت خاصی فرستاده، وضعیت محلی را بروز کن (در صورت امکان)
      if (res.containsKey('status')) {
        final status = res['status']?.toString() ?? '';
        if (status.isNotEmpty) {
          try {
            try {
              await AppDatabase.init();
            } catch (_) {}
            await AppDatabase.updateRequestStatusByEmailOrDevice(
                email: email, deviceHash: deviceHash, status: status);
            // در صورت rejected بهتر است لایسنس محلی هم پاک شود
            if (status == 'rejected') {
              try {
                await AppDatabase.deleteLocalLicense();
              } catch (_) {}
              try {
                await _secure.delete(key: 'license_token');
              } catch (_) {}
              licenseToken = null;
              licensePayload = null;
              notifyListeners();
            }
          } catch (_) {
            // اگر دیتابیس مقداردهی نشده یا update ناموفق بود، ادامه می‌دهیم بدون کرش
          }
        }
      }
      return _Result(false, msg);
    }
  }

  Future<void> logout() async {
    licenseToken = null;
    licensePayload = null;
    try {
      await _secure.delete(key: 'license_token');
    } catch (_) {}
    notifyListeners();
  }
}
