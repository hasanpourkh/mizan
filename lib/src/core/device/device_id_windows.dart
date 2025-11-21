// lib/src/core/device/device_id_windows.dart
// خواندن MachineGuid از رجیستری ویندوز و تولید device_hash (SHA256)
// اگر رجیستری در دسترس نبود، fallback به hostname
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class DeviceId {
  // مقدار هش دستگاه (SHA256 رشتهٔ ترکیبی)
  static Future<String> getDeviceHash() async {
    String identifier = '';

    if (Platform.isWindows) {
      try {
        // استفاده از Process.run برای خواندن MachineGuid از رجیستری ویندوز
        final result = await Process.run('reg', [
          'query',
          r'HKLM\SOFTWARE\Microsoft\Cryptography',
          '/v',
          'MachineGuid',
        ]);
        final out = result.stdout?.toString() ?? '';
        final lines = out.split(RegExp(r'\r?\n'));
        for (var l in lines) {
          if (l.contains('MachineGuid')) {
            final parts = l.trim().split(RegExp(r'\s+'));
            if (parts.length >= 3) {
              identifier = parts.last;
              break;
            }
          }
        }
      } catch (e) {
        // fallback handled below
        identifier = '';
      }
    }

    // fallback: از hostname استفاده کن اگر MachineGuid پیدا نشد
    if (identifier.isEmpty) {
      try {
        identifier = Platform.localHostname;
      } catch (e) {
        identifier = DateTime.now().millisecondsSinceEpoch.toString();
      }
    }

    final bytes = utf8.encode(identifier);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
