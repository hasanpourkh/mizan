// lib/src/core/config/config_manager.dart
// ConfigManager ساده و مستقل برای ذخیره‌سازی تنظیمات محلی به صورت فایل JSON.
// - مسیر ذخیره: <ApplicationDocuments>/mizan_config.json
// - متدها: getDbFilePath, setDbFilePath, get, saveConfig, getStoragePath.
// - کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class ConfigManager {
  ConfigManager._();

  static const String _fileName = 'mizan_config.json';
  static Map<String, dynamic>? _cache;

  // مسیر فایل config در Documents
  static Future<String> _filePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, _fileName);
  }

  // برگرداندن مسیر Documents (فولدر ذخیره‌سازی برنامه) - برای Settings استفاده میشود
  static Future<String> getStoragePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  // بارگذاری config از دیسک (و کش کردن)
  static Future<Map<String, dynamic>> _loadAll() async {
    if (_cache != null) return _cache!;
    try {
      final path = await _filePath();
      final f = File(path);
      if (!await f.exists()) {
        _cache = <String, dynamic>{};
        return _cache!;
      }
      final txt = await f.readAsString();
      final map = json.decode(txt) as Map<String, dynamic>;
      _cache = map;
      return _cache!;
    } catch (_) {
      _cache = <String, dynamic>{};
      return _cache!;
    }
  }

  // ذخیره کل config به دیسک
  static Future<void> _saveAll() async {
    try {
      final path = await _filePath();
      final f = File(path);
      final dir = f.parent;
      if (!await dir.exists()) await dir.create(recursive: true);
      await f.writeAsString(json.encode(_cache ?? <String, dynamic>{}));
    } catch (_) {
      // swallow errors; caller may handle
    }
  }

  // گرفتن مقدار مسیر دیتابیس اگر تنظیم شده باشد
  static Future<String?> getDbFilePath() async {
    final m = await _loadAll();
    final v = m['db_file_path'];
    if (v == null) return null;
    return v.toString();
  }

  // تنظیم مسیر دیتابیس (و ذخیره روی دیسک)
  static Future<void> setDbFilePath(String path) async {
    final m = await _loadAll();
    m['db_file_path'] = path;
    await _saveAll();
  }

  // گرفتن مقدار عمومی بر اساس key
  static Future<String?> get(String key) async {
    final m = await _loadAll();
    final v = m[key];
    if (v == null) return null;
    return v.toString();
  }

  // ذخیره یا بروزرسانی چند کلید/مقدار
  static Future<void> saveConfig(Map<String, dynamic> items) async {
    final m = await _loadAll();
    items.forEach((k, v) => m[k] = v);
    await _saveAll();
  }
}
