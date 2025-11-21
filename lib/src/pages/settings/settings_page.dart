// lib/src/pages/settings/settings_page.dart
// صفحهٔ تنظیمات پایه — شامل گزینهٔ تم (نمونه) و دکمه پاکسازی کش/دیتا
// به‌روزرسانی: افزودن بخش "بروزرسانی برنامه" که کاربر را به مسیر /settings/update هدایت میکند.
// کامنتهای فارسی مختصر دارد.

import 'package:flutter/material.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/app_info.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text('تنظیمات برنامه',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.palette),
                    title: const Text('تم تیره / روشن'),
                    subtitle: const Text(
                        'در نسخهٔ آینده امکان تغییر تم به‌صورت دائمی اضافه می‌شود.'),
                    trailing: Switch(
                      value: Theme.of(context).brightness == Brightness.dark,
                      onChanged: (v) {
                        NotificationService.showToast(
                            context, 'تغییر تم ذخیره نشد (نسخه آزمایشی)');
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.notifications),
                    title: const Text('نوتیفیکیشن‌ها'),
                    subtitle: const Text(
                        'نمایش مودال‌ها و توست‌ها برای عملیات مختلف'),
                    trailing: FilledButton.tonal(
                      onPressed: () {
                        NotificationService.showSuccess(context, 'نمایش نمونه',
                            'این یک نوتیفیکیشن تستی است');
                      },
                      child: const Text('نمایش تست'),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ---------------- بخش جدید: بروزرسانی برنامه ----------------
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.system_update),
                    title: const Text('بروزرسانی برنامه'),
                    subtitle: const Text(
                        'بررسی نسخهٔ جدید و دانلود آن از سرور (cofeclick.ir/mizan)'),
                    trailing: FilledButton.tonal(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/settings/update');
                      },
                      child: const Text('بررسی و مدیریت'),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                FilledButton.tonal(
                  onPressed: () {
                    NotificationService.showConfirm(context, 'پاکسازی کش',
                        'آیا از پاکسازی کش/دیتا مطمئن هستید؟', onConfirm: () {
                      NotificationService.showToast(context, 'پاکسازی انجام شد',
                          duration: const Duration(seconds: 2));
                    });
                  },
                  child: const Text('پاکسازی کش/دیتا (نمونه)'),
                ),
                const SizedBox(height: 12),
                const Center(
                    child: Text('نسخهٔ فعلی: ${AppInfo.version}',
                        style: TextStyle(color: Colors.black54))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
