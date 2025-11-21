// lib/src/core/auth/admin_auth.dart
// سرویس کوچک احراز هویت ادمین و ویجتِ محافظ (AdminGate).
// - نگهداری credential ادمین در flutter_secure_storage با کلیدهای:
//   admin_username و admin_password_hash (SHA256)
// - متد requireAdmin(context) که در صورت نبود سشن، دیالوگ لاگین را باز میکند.
// - AdminGate ویجتی ساده است که قبل از نمایش child، احراز هویت ادمین را اجباری میکند.
// - چند متد سازگاری (getCurrentSession, loginWithUsernamePassword, logout)
//   اضافه شده تا صفحات قدیمی که انتظار APIهای قبلی را داشتند بدون خطا کار کنند.
// کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AdminAuth {
  static const _storage = FlutterSecureStorage();
  static bool _sessionAuthenticated = false;

  // هش کردن رمز (SHA256)
  static String _hash(String pass) {
    final bytes = utf8.encode(pass);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // بررسی اینکه آیا credential ادمین تنظیم شده است
  static Future<bool> hasAdminCredentials() async {
    final u = await _storage.read(key: 'admin_username');
    final h = await _storage.read(key: 'admin_password_hash');
    return (u != null && u.isNotEmpty && h != null && h.isNotEmpty);
  }

  // ست کردن credential (ProfilePage هم همین کار را انجام می‌دهد، این برای استفاده داخلی مفید است)
  static Future<void> setAdminCredentials(
      String username, String password) async {
    final h = _hash(password);
    await _storage.write(key: 'admin_username', value: username.trim());
    await _storage.write(key: 'admin_password_hash', value: h);
    _sessionAuthenticated = true;
  }

  // حذف credential
  static Future<void> clearAdminCredentials() async {
    await _storage.delete(key: 'admin_username');
    await _storage.delete(key: 'admin_password_hash');
    _sessionAuthenticated = false;
  }

  // اعتبارسنجی لاگین
  static Future<bool> verifyAdminLogin(String username, String password) async {
    final storedUser = await _storage.read(key: 'admin_username');
    final storedHash = await _storage.read(key: 'admin_password_hash');
    if (storedUser == null || storedHash == null) return false;
    if (storedUser.trim() != username.trim()) return false;
    final hash = _hash(password);
    final ok = hash == storedHash;
    if (ok) _sessionAuthenticated = true;
    return ok;
  }

  // خروج از سشن (پاک نمیکند credential ذخیره شده، فقط session را غیرفعال میکند)
  static void logoutSession() {
    _sessionAuthenticated = false;
  }

  // آیا الان session احراز شده است؟
  static bool isSessionAuthenticated() => _sessionAuthenticated;

  // سازگاری: برگرداندن سشن فعلی (برای فایلهایی که قبلاً AdminAuth.getCurrentSession صدا میزدند)
  // اگر سشن فعال نباشد null برمیگرداند.
  static Future<Map<String, dynamic>?> getCurrentSession() async {
    if (!_sessionAuthenticated) return null;
    final username = await _storage.read(key: 'admin_username');
    if (username == null) return null;
    // بازگرداندن یک Map ساده حاوی username و display_name (برای نمایش در UI)
    return {
      'username': username,
      'display_name': username,
    };
  }

  // سازگاری: متد لاگین مبتنی بر نامکاربری/رمز که بسیاری از صفحات قدیمی از آن استفاده میکنند.
  // فقط wrapper روی verifyAdminLogin است.
  static Future<bool> loginWithUsernamePassword(
      String username, String password) async {
    final ok = await verifyAdminLogin(username, password);
    return ok;
  }

  // سازگاری: logout متد async که قبلاً توسط صفحات انتظار میرفت قابل await باشد.
  static Future<void> logout() async {
    logoutSession();
    // در صورت نیاز میتوان عملیات async اضافی اینجا اضافه کرد
  }

  // متدی که اطمینان میدهد کاربر ادمین است؛ اگر credential وجود داشته باشد دیالوگ لاگین نمایش داده میشود.
  // اگر credential وجود نداشته باشد، پیغام و دکمهٔ راهنمایی برای رفتن به صفحهٔ پروفایل جهت تنظیم نشان میدهد.
  // مقدار true/false برمیگرداند که نشان میدهد اجازه نمایش محتوای محافظت‌شده داده شود یا نه.
  static Future<bool> requireAdmin(BuildContext context) async {
    if (_sessionAuthenticated) return true;

    final hasCred = await hasAdminCredentials();
    if (!hasCred) {
      // اگر credential تنظیم نشده، کاربر را راهنمایی کن تا به پروفایل برود و آن را تنظیم کند.
      final res = await showDialog<bool>(
        context: context,
        builder: (c) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('دسترسی ادمین نیاز است'),
              content: const Text(
                  'اعتبار ورود ادمین تنظیم نشده است. برای محدود کردن دسترسی و مدیریت کاربران، ابتدا در صفحهٔ پروفایل اعتبار ادمین را تنظیم کنید.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(c).pop(false),
                    child: const Text('بعداً')),
                FilledButton.tonal(
                    onPressed: () => Navigator.of(c).pop(true),
                    child: const Text('رفتن به پروفایل')),
              ],
            ),
          );
        },
      );
      if (res == true) {
        // هدایت به پروفایل برای تنظیم credential
        Navigator.of(context).pushNamed('/profile');
      }
      return false;
    }

    // credential وجود دارد؛ نمایش فرم لاگین
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        final userCtrl = TextEditingController();
        final passCtrl = TextEditingController();
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('ورود ادمین'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: userCtrl,
                    decoration: const InputDecoration(
                        labelText: 'نام کاربری', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'رمز عبور', border: OutlineInputBorder())),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(c).pop(false),
                  child: const Text('انصراف')),
              FilledButton.tonal(
                  onPressed: () async {
                    final u = userCtrl.text.trim();
                    final p = passCtrl.text;
                    final ok = await AdminAuth.verifyAdminLogin(u, p);
                    if (ok) {
                      Navigator.of(c).pop(true);
                    } else {
                      // نمایش خطا و ماندن در دیالوگ
                      ScaffoldMessenger.of(c).showSnackBar(const SnackBar(
                          content: Text('نام‌کاربری یا رمز اشتباه است')));
                    }
                  },
                  child: const Text('ورود')),
            ],
          ),
        );
      },
    );
    return success == true;
  }
}

// ویجت محافظ: قبل از نمایش child اطمینان میدهد کاربر ادمین است.
// اگر requireAdmin موفق نشود، صفحهٔ onDenied یا یک کارت راهنما نمایش میدهد.
class AdminGate extends StatefulWidget {
  final Widget child;
  final Widget? onDenied; // ویجت اختیاری که هنگام عدم اجازه نمایش داده شود

  const AdminGate({super.key, required this.child, this.onDenied});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  late Future<bool> _allowed;

  @override
  void initState() {
    super.initState();
    // بررسی اجازه (ممکن است دیالوگ لاگین باز شود)
    _allowed = AdminAuth.requireAdmin(context);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _allowed,
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final ok = snap.data == true;
        if (ok) return widget.child;
        // اگر اجازه نیست، ویجت onDenied یا یک کارت راهنما نشان بده
        return widget.onDenied ??
            Center(
              child: Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('دسترسی مجاز نیست',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text(
                        'برای دسترسی به این بخش باید با حساب ادمین وارد شوید یا اعتبار ادمین تنظیم شود.'),
                    const SizedBox(height: 12),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      FilledButton.tonal(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/profile');
                          },
                          child: const Text('رفتن به پروفایل')),
                      const SizedBox(width: 8),
                      OutlinedButton(
                          onPressed: () {
                            // تلاش مجدد برای احراز هویت
                            setState(() {
                              _allowed = AdminAuth.requireAdmin(context);
                            });
                          },
                          child: const Text('تلاش مجدد')),
                    ])
                  ]),
                ),
              ),
            );
      },
    );
  }
}
