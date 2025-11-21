// lib/src/pages/debug/db_error_page.dart
// صفحهٔ خطای دیتابیس: وقتی AppDatabase.init با خطا مواجه شود این صفحه نمایش داده میشود.
// - نمایش پیام خطا (پیغام قابل فهم برای کاربر)
// - دکمهٔ "رفتن به تنظیمات" تا کاربر مسیر دیتابیس را تنظیم کند
// - دکمهٔ "تلاش مجدد" تا دوباره init اجرا شود
// کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'package:flutter/material.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';

class DebugDbErrorPage extends StatefulWidget {
  final String message;
  const DebugDbErrorPage({super.key, required this.message});

  @override
  State<DebugDbErrorPage> createState() => _DebugDbErrorPageState();
}

class _DebugDbErrorPageState extends State<DebugDbErrorPage> {
  bool _trying = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _lastError = widget.message;
  }

  // تلاش مجدد برای init دیتابیس؛ اگر موفق شد کاربر را به login/onboarding هدایت میکنیم
  Future<void> _retryInit() async {
    setState(() {
      _trying = true;
      _lastError = null;
    });
    try {
      await AppDatabase.init();
      final hasProfile = await AppDatabase.hasBusinessProfile();
      final next = hasProfile ? '/login' : '/onboarding';
      NotificationService.showSuccess(
          context, 'موفق', 'دیتابیس با موفقیت بارگذاری شد.', onOk: () {
        Navigator.of(context).pushReplacementNamed(next);
      });
    } catch (e) {
      setState(() {
        _lastError = e.toString();
        _trying = false;
      });
      NotificationService.showError(
          context, 'خطا', 'بارگذاری دیتابیس انجام نشد: $_lastError');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('خطای دیتابیس'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تنظیم مسیر دیتابیس لازم است',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      _lastError ?? widget.message,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                        'توضیح کوتاه: اپ تنها از مسیر دیتابیسی که در تنظیمات مشخص کرده‌اید استفاده می‌کند.'),
                    const SizedBox(height: 6),
                    const Text(
                        'اگر مسیر در دسترس نیست یا نیاز به دسترسی ادمین دارد، آن را از طریق صفحهٔ تنظیمات تغییر دهید.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.settings),
                    label: const Text('رفتن به تنظیمات'),
                    onPressed: () {
                      Navigator.of(context).pushNamed('/settings');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: _trying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.replay),
                    label: const Text('تلاش مجدد'),
                    onPressed: _trying ? null : _retryInit,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Expanded(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SingleChildScrollView(
                    child: Text(
                      'راهنمایی سریع:\n\n'
                      '1) اگر از مسیر پیشفرض استفاده نمی‌کنید، وارد تنظیمات برنامه شده و مسیر فایل دیتابیس (.db) را انتخاب کنید.\n'
                      '2) مسیرهایی مانند "Program Files" ممکن است نیاز به مجوز ادمین داشته باشند. بهتر است از پوشهٔ Documents یا پوشه‌ای که حق نوشتن دارید استفاده کنید.\n'
                      '3) قبل از حذف یا جابجایی فایل، از هر دو فایل یک بکاپ تهیه کنید.\n\n'
                      'اگر نیاز داری من یک اسکریپت کوچک برای انتقال/همگام‌سازی فایل دیتابیس بین مسیرها بنویسم بگو تا آماده کنم.',
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
