// lib/src/pages/dashboard/splash_dashboard_page.dart
// صفحهٔ شروع / داشبورد ابتدایی — نسخهٔ اصلاح‌شده برای رفع ارورهای null-safety
// - بررسی‌های null-safe برای فیلدهای business_profile اضافه شد.
// - مسیر دیتابیس (currentDbPath) به‌صورت async خوانده و نگهداری میشود تا نمایش داده شود.
// - کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'package:flutter/material.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/auth/admin_auth.dart';
import '../../theme/app_theme.dart';

class SplashDashboardPage extends StatefulWidget {
  const SplashDashboardPage({super.key});

  @override
  State<SplashDashboardPage> createState() => _SplashDashboardPageState();
}

class _SplashDashboardPageState extends State<SplashDashboardPage> {
  bool _loading = true;
  Map<String, dynamic>? _businessProfile;
  Map<String, dynamic>? _session;
  String? _licenseInfo;
  String? _currentDbPath; // مسیر فعلی دیتابیس برای نمایش در UI

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    setState(() => _loading = true);
    try {
      try {
        await AppDatabase.init();
      } catch (_) {}
      final bp = await AppDatabase.getBusinessProfile().catchError((_) => null);
      _businessProfile = bp;
    } catch (_) {
      _businessProfile = null;
    }

    try {
      final sess = await AdminAuth.getCurrentSession().catchError((_) => null);
      _session = sess;
    } catch (_) {
      _session = null;
    }

    try {
      final lic = await AppDatabase.getLocalLicense().catchError((_) => null);
      if (lic != null) {
        final owner = lic['owner']?.toString() ?? '';
        final expRaw = lic['expires_at'];
        DateTime? exp;
        if (expRaw != null) {
          final millis =
              (expRaw is int) ? expRaw : int.tryParse(expRaw.toString()) ?? 0;
          if (millis > 0) exp = DateTime.fromMillisecondsSinceEpoch(millis);
        }
        _licenseInfo = owner.isNotEmpty ? owner : 'لایسنس موجود';
        if (exp != null) {
          _licenseInfo =
              '$_licenseInfo — انقضا: ${exp.toLocal().toString().split(' ').first}';
        }
      } else {
        _licenseInfo = null;
      }
    } catch (_) {
      _licenseInfo = null;
    }

    // خواندن مسیر فعلی دیتابیس (async) برای نمایش در UI
    try {
      final p =
          await AppDatabase.getCurrentDbFilePath().catchError((_) => null);
      _currentDbPath = p;
    } catch (_) {
      _currentDbPath = null;
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _requireAdminAndNavigate(String route) async {
    try {
      final ok = await AdminAuth.requireAdmin(context);
      if (ok) {
        Navigator.of(context).pushNamed(route);
      } else {
        NotificationService.showToast(context, 'دسترسی ادمین مورد نیاز است',
            backgroundColor: Colors.orange);
      }
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'چک دسترسی انجام نشد: $e');
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushNamed('/login');
  }

  Future<void> _logout() async {
    await AdminAuth.logout();
    setState(() {
      _session = null;
    });
    NotificationService.showToast(context, 'خارج شدید');
  }

  Widget _buildHeader(BuildContext ctx) {
    final businessName =
        (_businessProfile?['business_name']?.toString() ?? '').trim();
    final title =
        businessName.isNotEmpty ? businessName : 'Mizan - حسابداری محلی';

    final businessType =
        (_businessProfile?['business_type']?.toString() ?? '').trim();
    final city = (_businessProfile?['city']?.toString() ?? '').trim();
    final subtitle = (businessType.isNotEmpty || city.isNotEmpty)
        ? '$businessType${businessType.isNotEmpty && city.isNotEmpty ? ' • ' : ''}$city'
        : 'سیستم محلی مدیریت فروش و انبار';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: AppTheme.primary,
              child: Text(title.isNotEmpty ? title[0] : 'M',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.neutral700)),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.login),
                        label: Text(
                            _session == null ? 'ورود' : 'ورود / سوئیچ کاربر'),
                        onPressed: _goToLogin,
                      ),
                      FilledButton.tonal(
                        onPressed: () {
                          Navigator.of(context).pushNamed('/profile');
                        },
                        child: const Text('پروفایل'),
                      ),
                      OutlinedButton(
                          onPressed: _initAll,
                          child: const Text('بارگذاری مجدد')),
                    ])
                  ]),
            ),
            const SizedBox(width: 12),
            Column(children: [
              if (_session != null) ...[
                Text(
                    'کاربر: ${_session!['display_name'] ?? _session!['username']}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                FilledButton.tonal(
                    onPressed: _logout, child: const Text('خروج')),
              ] else
                const Text('وارد نشده',
                    style: TextStyle(color: Colors.black54)),
            ])
          ],
        ),
      ),
    );
  }

  Widget _actionCard(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      Color? color}) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 14.0),
          child: Row(
            children: [
              CircleAvatar(
                  radius: 26,
                  backgroundColor: color ?? AppTheme.primary,
                  child: Icon(icon, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 13)),
                  ])),
              const Icon(Icons.chevron_left, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext ctx) {
    final items = <Widget>[
      _actionCard(
          icon: Icons.point_of_sale,
          title: 'فروش جدید',
          subtitle: 'ایجاد فاکتور و ثبت فروش',
          onTap: () => Navigator.of(context).pushNamed('/sales/new'),
          color: Colors.green),
      _actionCard(
          icon: Icons.shopping_bag,
          title: 'محصولات',
          subtitle: 'فهرست و مدیریت محصولات',
          onTap: () => Navigator.of(context).pushNamed('/products/list'),
          color: Colors.indigo),
      _actionCard(
          icon: Icons.people,
          title: 'اشخاص',
          subtitle: 'مشتریان، فروشندگان و کل فهرست اشخاص',
          onTap: () => Navigator.of(context).pushNamed('/persons/list'),
          color: Colors.orange),
      _actionCard(
          icon: Icons.admin_panel_settings,
          title: 'مدیریت کاربران',
          subtitle: 'تعریف نام‌کاربری/رمز برای پرسنل (فقط ادمین)',
          onTap: () => _requireAdminAndNavigate('/users'),
          color: Colors.purple),
      _actionCard(
          icon: Icons.settings,
          title: 'تنظیمات برنامه',
          subtitle: 'تنظیم مسیر دیتابیس، فایلها و فاکتورها',
          onTap: () => _requireAdminAndNavigate('/settings'),
          color: Colors.teal),
      _actionCard(
          icon: Icons.business,
          title: 'اطلاعات کسب‌وکار',
          subtitle: 'ویرایش نام، آدرس و جزئیات کسب‌وکار',
          onTap: () => _requireAdminAndNavigate('/settings/business'),
          color: Colors.blue),
      _actionCard(
          icon: Icons.account_balance_wallet,
          title: 'تنظیمات مالی',
          subtitle: 'پیکربندی مالیاتی و انبار (فقط ادمین)',
          onTap: () => _requireAdminAndNavigate('/settings/finance'),
          color: Colors.brown),
      _actionCard(
          icon: Icons.restore,
          title: 'بازگردانی دیتابیس',
          subtitle: 'Restore / تغییر مسیر دیتابیس (فقط ادمین)',
          onTap: () => _requireAdminAndNavigate('/settings/restore_db'),
          color: Colors.red),
    ];

    final width = MediaQuery.of(ctx).size.width;
    int cols = 3;
    if (width < 700) {
      cols = 1;
    } else if (width < 1100) cols = 2;

    return GridView.count(
      crossAxisCount: cols,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mizan — داشبورد'),
        actions: [
          IconButton(
              tooltip: 'بارگذاری مجدد',
              onPressed: _initAll,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(14.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 12),
                      if (_licenseInfo != null)
                        Card(
                          color: Colors.yellow.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                const Icon(Icons.verified,
                                    color: Colors.orange),
                                const SizedBox(width: 10),
                                Expanded(child: Text('لایسنس: $_licenseInfo')),
                                FilledButton.tonal(
                                    onPressed: () {
                                      NotificationService.showToast(
                                          context, 'اطلاعات لایسنس بررسی شد');
                                    },
                                    child: const Text('بررسی')),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text('عملیات سریع',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      _buildGrid(context),
                      const SizedBox(height: 18),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('اطلاعات بیشتر',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                const Text('نسخه برنامه: 1.0.0'),
                                const SizedBox(height: 6),
                                SelectableText(
                                    'پایگاه‌داده: ${_currentDbPath ?? 'نامشخص'}',
                                    style: const TextStyle(
                                        fontFamily: 'monospace')),
                                const SizedBox(height: 10),
                                TextButton(
                                    onPressed: () =>
                                        _requireAdminAndNavigate('/settings'),
                                    child:
                                        const Text('رفتن به تنظیمات پیشرفته')),
                              ]),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
