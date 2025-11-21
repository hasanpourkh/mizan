// lib/src/core/update/update_service.dart
// سرویس بررسی و دانلود آپدیت از آدرس cofeclick.ir/mizan
// کامنت فارسی مختصر: fetchLatest() برای گرفتن JSON آپدیت، downloadUpdate() برای دانلود فایل به پوشهٔ محلی app support.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'update_model.dart';

class UpdateService {
  UpdateService._();
  // آدرس JSON مشخصات آپدیت روی سایت شما (قابل تغییر)
  static const String _updateJsonUrl = 'https://cofeclick.ir/mizan/update.json';

  // گرفتن آخرین اطلاعات بروزرسانی از سرور
  static Future<UpdateInfo?> fetchLatest() async {
    try {
      final resp = await http
          .get(Uri.parse(_updateJsonUrl))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final Map<String, dynamic> j =
          jsonDecode(resp.body) as Map<String, dynamic>;
      // انتظار داریم JSON حداقل فیلدهای version, notes, url داشته باشد
      if (!j.containsKey('version') || !j.containsKey('url')) return null;
      return UpdateInfo.fromJson(j);
    } catch (e) {
      // در صورت خطا null برگردان
      return null;
    }
  }

  // دانلود فایل آپدیت و ذخیره در پوشهٔ app support/mizan_updates/
  // onProgress: callback اختیاری با مقدار 0.0..1.0
  // بازمیگرداند مسیر فایل ذخیره‌شده یا null درصورت خطا
  static Future<String?> downloadUpdate(String fileUrl,
      {void Function(double progress)? onProgress}) async {
    try {
      final uri = Uri.parse(fileUrl);
      final client = http.Client();
      final req = http.Request('GET', uri);
      final streamed = await client.send(req);

      if (streamed.statusCode != 200) {
        client.close();
        return null;
      }

      final appSupport = await _getUpdatesDir();
      final filename = _fileNameFromUri(uri);
      final outPath = p.join(appSupport.path, filename);
      final file = File(outPath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      final sink = file.openWrite();

      final contentLength = streamed.contentLength ?? 0;
      int received = 0;

      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (onProgress != null && contentLength > 0) {
          final prog = received / contentLength;
          try {
            onProgress(prog.clamp(0.0, 1.0));
          } catch (_) {}
        }
      }

      await sink.close();
      client.close();
      return outPath;
    } catch (e) {
      return null;
    }
  }

  // کمک: مسیر پوشه updates داخل Application Support یا معادل دسکتاپ
  static Future<Directory> _getUpdatesDir() async {
    Directory dir;
    try {
      final appDoc = await getApplicationSupportDirectory();
      dir = Directory(p.join(appDoc.path, 'mizan_updates'));
    } catch (_) {
      final doc = await getApplicationDocumentsDirectory();
      dir = Directory(p.join(doc.path, 'mizan_updates'));
    }
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _fileNameFromUri(Uri u) {
    final basename = p.basename(u.path);
    if (basename.isEmpty) {
      // fallback: use timestamp
      return 'mizan_update_${DateTime.now().millisecondsSinceEpoch}';
    }
    return basename;
  }
}
