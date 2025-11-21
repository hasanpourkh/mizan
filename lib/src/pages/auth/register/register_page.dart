// lib/src/pages/auth/register/register_page.dart
// صفحه ثبت‌نام — فولدر جدا و فایل جدا
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailCtrl = TextEditingController();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _storeCtrl = TextEditingController();
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _userCtrl.dispose();
    _phoneCtrl.dispose();
    _storeCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final res = await auth.registerUser(
      email: _emailCtrl.text.trim(),
      firstName: _firstCtrl.text.trim(),
      lastName: _lastCtrl.text.trim(),
      username: _userCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      storeName: _storeCtrl.text.trim(),
    );
    setState(() {
      _loading = false;
      _message = res.message;
    });
    if (res.success) {
      // پیام موفقیت و بازگشت به صفحه ورود
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('درخواست ثبت شد'),
          content: Text(
            'درخواست با موفقیت ارسال شد. پس از تایید مدیر لایسنس برای شما ایمیل می‌شود.\n\n$requestInfo',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('باشه'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(c).pop();
                Navigator.of(context).pop();
              },
              child: const Text('بازگشت'),
            ),
          ],
        ),
      );
    }
  }

  String get requestInfo => 'ایمیل: ${_emailCtrl.text.trim()}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ثبت‌نام')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text(
                  'فرم ثبت‌نام',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _firstCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نام',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _lastCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نام خانوادگی',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نام کاربری',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ایمیل',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'شماره موبایل',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _storeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم فروشگاه',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: _loading ? null : _onRegister,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text('ارسال درخواست ثبت‌نام'),
                  ),
                ),
                const SizedBox(height: 12),
                if (_message != null)
                  Text(_message!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
