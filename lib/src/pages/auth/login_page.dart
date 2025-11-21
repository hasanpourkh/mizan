// lib/src/pages/auth/login_page.dart
// صفحهٔ ورود عمومی (Login) — اجازه میدهد هم ادمین و هم کاربران (اشخاص) که توسط مدیر اعتباردهی شده‌اند وارد شوند.
// - از AdminAuth.loginWithUsernamePassword برای احراز استفاده میکند.
// - پس از ورود موفق، سشن پایدار ذخیره میشود و تا logout ادامه خواهد داشت (دیگر لازم نیست هر بار وارد شوی).
// - پس از موفقیت، بازگشت به داشبورد یا روت مشخص شده انجام می‌شود.
// - کامنتهای فارسی مختصر برای هر بخش وجود دارد.

import 'package:flutter/material.dart';
import '../../core/auth/admin_auth.dart';
import '../../core/notifications/notification_service.dart';

class LoginPage extends StatefulWidget {
  // نام روت مقصد پس از ورود موفق (پیش‌فرض '/dashboard' — اگر در پروژه نام دیگری داری این مقدار را هنگام push تغییر بده)
  final String redirectRoute;
  const LoginPage({super.key, this.redirectRoute = '/dashboard'});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final u = _userCtrl.text.trim();
    final p = _passCtrl.text;
    if (u.isEmpty || p.isEmpty) {
      NotificationService.showError(
          context, 'خطا', 'نام‌کاربری و رمز را وارد کنید');
      return;
    }
    setState(() => _loading = true);
    try {
      final ok = await AdminAuth.loginWithUsernamePassword(u, p);
      if (ok) {
        NotificationService.showSuccess(context, 'ورود موفق', 'خوش آمدید');
        // بازگشت به صفحهٔ مقصد (یا بستن صفحهٔ مودال)
        // اگر روت وجود ندارد، فقط Navigator.pop کنید
        try {
          Navigator.of(context).pushReplacementNamed(widget.redirectRoute);
        } catch (_) {
          Navigator.of(context).pop(true);
        }
      } else {
        NotificationService.showError(
            context, 'خطا', 'نام‌کاربری یا رمز اشتباه است');
      }
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'فرآیند ورود با خطا مواجه شد: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('ورود به سیستم',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
              controller: _userCtrl,
              decoration: const InputDecoration(
                  labelText: 'نام کاربری', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'رمز عبور',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                  icon:
                      Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure)),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('ورود'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              // هدایت کاربر به صفحهٔ پروفایل برای تنظیم credential ادمین (در صورت نیاز)
              Navigator.of(context).pushNamed('/profile');
            },
            child: const Text('اگر اعتبار ادمین ندارید به پروفایل بروید'),
          )
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ورود'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildCard(),
          ),
        ),
      ),
    );
  }
}
