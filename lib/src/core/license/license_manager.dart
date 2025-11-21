// lib/src/core/license/license_manager.dart
// اعتبارسنجی JWT (موقتی): فقط decode و بررسی expiry از payload انجام می‌شود.
// هشدار امنیتی: در این نسخه امضای JWT در کلاینت بررسی نمی‌شود.
// نسخهٔ بعدی: بررسی RS256 با کلید عمومی یا native را اضافه خواهیم کرد.
import 'dart:convert';

class LicenseManager {
  // این متد به‌صورت موقت payload را بدون بررسی امضا برمی‌گرداند
  static Future<Map<String, dynamic>?> verifyJwtOffline(String token) async {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payloadPart = parts[1];
      // normalize base64Url و decode
      String normalized = base64Url.normalize(payloadPart);
      final payloadBytes = base64Url.decode(normalized);
      final payloadJson = jsonDecode(utf8.decode(payloadBytes));
      if (payloadJson is Map) {
        // بررسی expire (مقدار expires_at باید بر حسب timestamp ثانیه باشد)
        if (payloadJson.containsKey('expires_at') &&
            payloadJson['expires_at'] != null) {
          final exp = int.tryParse(payloadJson['expires_at'].toString()) ?? 0;
          final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
          if (exp > 0 && nowSec > exp) {
            return null; // منقضی شده
          }
        }
        return Map<String, dynamic>.from(payloadJson);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
