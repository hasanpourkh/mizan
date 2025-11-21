// lib/src/pages/sales/sale_utils.dart
// توابع کمکی مرتبط با فروش: تولید شمارهٔ فاکتور از ConfigManager و محاسبه جمع‌ها
// کامنت فارسی مختصر برای هر تابع قرار دارد.

import '../../core/config/config_manager.dart';

/// تولید شمارهٔ فاکتور بر اساس تنظیمات (invoice_prefix, invoice_start, invoice_counter).
/// این تابع کانتر را نیز افزایش می‌دهد.
Future<String> generateInvoiceNo() async {
  try {
    final prefix = await ConfigManager.get('invoice_prefix') ?? 'INV';
    final startStr = await ConfigManager.get('invoice_start') ?? '1000';
    final counterStr = await ConfigManager.get('invoice_counter');
    int start = int.tryParse(startStr) ?? 1000;
    int counter;
    if (counterStr == null) {
      counter = start;
    } else {
      counter = int.tryParse(counterStr) ?? start;
    }
    final inv = '$prefix$counter';
    // ذخیره کانتر افزایش‌یافته
    await ConfigManager.saveConfig(
        {'invoice_counter': (counter + 1).toString()});
    return inv;
  } catch (_) {
    return 'INV${DateTime.now().millisecondsSinceEpoch}';
  }
}
