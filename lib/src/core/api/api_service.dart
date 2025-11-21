// lib/src/core/api/api_service.dart
// سرویس HTTP بهبود یافته با مدیریت خطا و افزایش timeout و تلاش مجدد (retry).
// - زمان تایم‌اوت پیش‌فرض افزایش یافت (30s).
// - لاگ‌های ساده برای دیباگ.
// - هندل کردن Timeout, Socket, SSL و پاسخ‌های غیر 200.
// - ساختار بازگشتی سازگار با نسخه‌ی قبلی ('success' و 'message' و در صورت وجود بدنه‌ی JSON).
//
// توجه: فقط این فایل را جایگزین کن، سپس یک بار flutter clean && flutter pub get اجرا و برنامه را مجدداً تست کن.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiService {
  // آدرس پایه سرور — در صورت نیاز میتوانی مقدار را تغییر دهی
  static String baseUrl = 'https://cofeclick.ir/wp-json/mizan/v1';

  // زمان تایم‌اوت پیش‌فرض برای درخواست‌ها
  static Duration timeoutDuration = const Duration(seconds: 30);

  // حداکثر تعداد تلاش (تعداد دفعات retry)
  static const int _maxRetries = 2;

  // یک http.Client مشترک برای بازده بهتر
  static final http.Client _client = http.Client();

  // Helper داخلی برای ارسال POST با retry و مدیریت خطا
  static Future<Map<String, dynamic>> _post(String path, Map body,
      {Duration? timeout}) async {
    final uri = Uri.parse('$baseUrl$path');
    final d = timeout ?? timeoutDuration;

    int attempt = 0;
    while (true) {
      try {
        // لاگ ساده برای دیباگ (در توسعه میتوانی این را برداری)
        // print('ApiService POST -> $uri (attempt ${attempt + 1})');

        final response = await _client.post(
          uri,
          body: jsonEncode(body),
          headers: {'Content-Type': 'application/json'},
        ).timeout(d);

        // تلاش برای پارس کردن JSON پاسخ
        final text = response.body;
        Map<String, dynamic>? parsed;
        try {
          if (text.isNotEmpty) {
            final jsonR = jsonDecode(text);
            if (jsonR is Map<String, dynamic>) parsed = jsonR;
          }
        } catch (e) {
          // پاسخ JSON نامعتبر است؛ ولی ممکن است statusCode نیز نشان‌دهنده‌ی خطا باشد
          parsed = null;
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          // موفق: اگر parsed موجود است همان را برگردان
          if (parsed != null) return parsed;
          // در غیر اینصورت سازگاری با ساختار قدیمی
          return {
            'success': true,
            'message': 'عملیات با موفقیت انجام شد',
            'raw': text
          };
        } else {
          // پاسخ نا موفق از سرور
          final serverMsg = parsed != null
              ? (parsed['message']?.toString() ?? parsed.toString())
              : 'خطا از سرور: ${response.statusCode}';
          return {
            'success': false,
            'message': serverMsg,
            'status': response.statusCode
          };
        }
      } on TimeoutException catch (_) {
        // تایم‌اوت رخ داد
        attempt++;
        if (attempt > _maxRetries) {
          return {
            'success': false,
            'message':
                'اتمام زمان ارتباط با سرور (Timeout). لطفاً اتصال اینترنت را بررسی کنید.'
          };
        }
        // backoff قبل از retry
        await Future.delayed(Duration(milliseconds: 300 * attempt));
        continue;
      } on SocketException catch (e) {
        // مشکل شبکه یا قطع اینترنت
        return {
          'success': false,
          'message':
              'خطای شبکه: ${e.message}. اتصال اینترنت یا فایروال را بررسی کنید.'
        };
      } on HandshakeException catch (e) {
        // خطای SSL / certificate
        return {
          'success': false,
          'message':
              'خطای امنیتی در SSL/Certificate: ${e.message}. اگر از گواهی خودامضاء استفاده می‌کنید، روی سرور از گواهی معتبر استفاده کنید.'
        };
      } on FormatException catch (e) {
        // خطای پارس JSON محلی
        return {
          'success': false,
          'message': 'پاسخ نامعتبر از سرور: ${e.message}'
        };
      } catch (e) {
        // سایر خطاهای غیرمنتظره
        return {'success': false, 'message': 'خطا در ارتباط با سرور: $e'};
      }
    }
  }

  // ثبت درخواست
  static Future<Map<String, dynamic>> register({
    required String email,
    required String firstName,
    required String lastName,
    required String username,
    required String phone,
    required String storeName,
    required String deviceHash,
  }) async {
    final body = {
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'username': username,
      'phone': phone,
      'store_name': storeName,
      'device_hash': deviceHash,
    };
    return await _post('/register', body);
  }

  // بررسی وضعیت و دریافت license_token اگر فعال باشد
  static Future<Map<String, dynamic>> check({
    required String deviceHash,
    String? email,
  }) async {
    final body = {'device_hash': deviceHash};
    if (email != null && email.isNotEmpty) body['email'] = email;
    return await _post('/check', body);
  }

  // اعتبارسنجی آنلاین JWT (اختیاری)
  static Future<Map<String, dynamic>> validate({
    required String licenseToken,
  }) async {
    final body = {'license_token': licenseToken};
    return await _post('/validate', body);
  }
}
