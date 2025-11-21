// lib/src/pages/auth/login/login_page.dart
// صفحه ورود — فولدر جدا و فایل جدا
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final res = await auth.loginWithEmail(_emailCtrl.text.trim());
    setState(() {
      _loading = false;
      _message = res.message;
    });
    if (res.success) {
      // وارد شدیم؛ به صفحه اصلی می‌رویم
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('ورود')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'ورود به اپ میزان',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'ایمیل',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: _loading ? null : _onLogin,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text('ورود / بررسی لایسنس'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/register'),
                  child: const Text('ثبت‌نام جدید'),
                ),
                const SizedBox(height: 12),
                if (_message != null)
                  Text(_message!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                if (auth.licenseToken != null)
                  Column(
                    children: [
                      const Text(
                        'لایسنس محلی فعال است',
                        style: TextStyle(color: Colors.green),
                      ),
                      SelectableText(
                        auth.licenseToken ?? '',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
