// lib/src/core/notifications/notification_service.dart
// سرویس نمایش نوتیفیکیشن: پیاده‌سازی ساده و بدون وابستگی به پکیج‌هایی که با SDK شما مشکل دارند.
// - showConfirm اکنون پارامترهای اختیاری برای آیکن و برچسب دکمه‌ها می‌پذیرد.
// - کامنت‌های فارسی مختصر برای درک هر متد.

import 'package:flutter/material.dart';

class NotificationService {
  // نمایش مودال موفقیت با یک دکمه تأیید
  static Future<void> showSuccess(
      BuildContext context, String title, String msg,
      {VoidCallback? onOk}) async {
    await showDialog(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(title)
          ]),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(c).pop();
                if (onOk != null) onOk();
              },
              child: const Text('باشه'),
            ),
          ],
        ),
      ),
    );
  }

  // نمایش مودال خطا با دکمهٔ فهمیدم
  static Future<void> showError(BuildContext context, String title, String msg,
      {VoidCallback? onOk}) async {
    await showDialog(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(title)
          ]),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(c).pop();
                if (onOk != null) onOk();
              },
              child: const Text('متوجه شدم'),
            ),
          ],
        ),
      ),
    );
  }

  // نمایش مودال تأیید (Confirm) با دکمه‌های تایید و انصراف
  // اکنون پارامترهای اختیاری: icon, confirmLabel, cancelLabel
  static Future<bool> showConfirm(
    BuildContext context,
    String title,
    String msg, {
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    IconData? icon,
    String confirmLabel = 'تایید',
    String cancelLabel = 'انصراف',
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(children: [
            if (icon != null)
              Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(title)
          ]),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(c).pop(false);
                if (onCancel != null) onCancel();
              },
              child: Text(cancelLabel),
            ),
            FilledButton.tonal(
              onPressed: () {
                Navigator.of(c).pop(true);
                onConfirm();
              },
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
    return res == true;
  }

  // نمایش پیام کوتاه (Toast) با SnackBar (قابل استفاده در هر جای برنامه)
  static void showToast(BuildContext context, String message,
      {Color? backgroundColor, Duration? duration}) {
    final snack = SnackBar(
      content: Text(message, textAlign: TextAlign.right),
      duration: duration ?? const Duration(seconds: 2),
      backgroundColor: backgroundColor ?? Colors.black87,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(snack);
  }
}
