// lib/src/pages/profile/profile_page.dart
// صفحه پروفایل کاربر — شامل دو بخش:
// 1) پروفایل شخصی (نام، ایمیل، آواتار) که در flutter_secure_storage ذخیره میشود.
// 2) خلاصه اطلاعات کسب‌وکار (بارگذاری از sqlite: business_profile) با امکان ویرایش و ذخیره.
// کامنتهای فارسی مختصر برای هر بخش قرار دارد.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/db/database.dart';
import '../../core/notifications/notification_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _storage = const FlutterSecureStorage();

  // کنترلرهای اطلاعات شخصی
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _avatarCtrl = TextEditingController();

  // مقادیر پروفایل کسب‌وکار (خوانده از sqlite)
  Map<String, dynamic>? _businessProfile;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);

    // بارگذاری پروفایل شخصی از secure storage
    final name = await _storage.read(key: 'profile_name');
    final email = await _storage.read(key: 'profile_email');
    final avatar = await _storage.read(key: 'profile_avatar');

    // بارگذاری پروفایل کسب‌وکار از sqlite
    final business = await AppDatabase.getBusinessProfile();

    // اگر اطلاعات شخصی خالی باشد، از business_profile به عنوان fallback استفاده کن
    _nameCtrl.text = name ?? (business?['business_name']?.toString() ?? '');
    _emailCtrl.text = email ?? (business?['email']?.toString() ?? '');
    _avatarCtrl.text = avatar ?? '';

    setState(() {
      _businessProfile = business;
      _loading = false;
    });
  }

  Future<void> _savePersonal() async {
    setState(() => _loading = true);
    await _storage.write(key: 'profile_name', value: _nameCtrl.text.trim());
    await _storage.write(key: 'profile_email', value: _emailCtrl.text.trim());
    await _storage.write(key: 'profile_avatar', value: _avatarCtrl.text.trim());
    setState(() => _loading = false);
    NotificationService.showSuccess(
        context, 'ذخیره شد', 'اطلاعات شخصی ذخیره شد');
    // در صورت تمایل می‌توانیم اطلاعاتی را به business_profile هم منتقل کنیم (اختیاری)
  }

  Future<void> _saveBusiness(Map<String, dynamic> updated) async {
    setState(() => _loading = true);
    try {
      // بارها saveBusinessProfile یک upsert ساده انجام می‌دهد
      await AppDatabase.saveBusinessProfile(updated);
      NotificationService.showSuccess(
          context, 'ذخیره شد', 'اطلاعات کسب‌وکار به‌روزرسانی شد', onOk: () {
        _loadAll();
      });
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'ذخیره اطلاعات انجام نشد');
    } finally {
      setState(() => _loading = false);
    }
  }

  // نمایش یک Dialog برای ویرایش سریع مقادیر کسب‌وکار
  Future<void> _editBusinessDialog() async {
    final bp = Map<String, dynamic>.from(_businessProfile ?? {});
    final businessNameCtrl =
        TextEditingController(text: bp['business_name']?.toString() ?? '');
    final legalNameCtrl =
        TextEditingController(text: bp['legal_name']?.toString() ?? '');
    final phoneCtrl =
        TextEditingController(text: bp['phone']?.toString() ?? '');
    final emailCtrl =
        TextEditingController(text: bp['email']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (c) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('ویرایش سریع اطلاعات کسب‌وکار'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: businessNameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'نام کسب‌وکار',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: legalNameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'نام قانونی', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                        labelText: 'تلفن', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                        labelText: 'ایمیل کسب‌وکار',
                        border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(c).pop(),
                  child: const Text('انصراف')),
              FilledButton.tonal(
                onPressed: () {
                  // update map and save
                  bp['business_name'] = businessNameCtrl.text.trim();
                  bp['legal_name'] = legalNameCtrl.text.trim();
                  bp['phone'] = phoneCtrl.text.trim();
                  bp['email'] = emailCtrl.text.trim();
                  Navigator.of(c).pop(bp);
                },
                child: const Text('ذخیره'),
              ),
            ],
          ),
        );
      },
    ).then((res) {
      if (res != null && res is Map<String, dynamic>) {
        // merge with existing fields to avoid data loss
        final merged = Map<String, dynamic>.from(_businessProfile ?? {});
        merged.addAll(res);
        _saveBusiness(merged);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('پروفایل من'),
        actions: [
          IconButton(
            tooltip: 'ویرایش سریع اطلاعات کسب‌وکار',
            icon: const Icon(Icons.business),
            onPressed: _businessProfile == null ? null : _editBusinessDialog,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      const Text('پروفایل شخصی',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // پیش‌نمایش آواتار
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: (_avatarCtrl.text.isNotEmpty)
                                ? NetworkImage(_avatarCtrl.text)
                                : null,
                            child: _avatarCtrl.text.isEmpty
                                ? Text(_nameCtrl.text.isNotEmpty
                                    ? _nameCtrl.text[0]
                                    : 'U')
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                TextField(
                                  controller: _nameCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'نام',
                                      border: OutlineInputBorder()),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _emailCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'ایمیل',
                                      border: OutlineInputBorder()),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _avatarCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'آدرس تصویر (URL)',
                                      border: OutlineInputBorder()),
                                  onChanged: (_) {
                                    setState(() {}); // بروزرسانی پیش‌نمایش
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: _savePersonal,
                              child: const Text('ذخیره اطلاعات شخصی'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: () async {
                              // پاکسازی اطلاعات شخصی
                              await _storage.delete(key: 'profile_name');
                              await _storage.delete(key: 'profile_email');
                              await _storage.delete(key: 'profile_avatar');
                              _loadAll();
                              NotificationService.showToast(
                                  context, 'اطلاعات شخصی پاک شد');
                            },
                            child: const Text('پاکسازی'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('اطلاعات کسب‌وکار',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (_businessProfile == null)
                        const Text(
                            'اطلاعات کسب‌وکار یافت نشد. ویـزارد را اجرا کنید.')
                      else
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'نام کسب‌وکار: ${_businessProfile!['business_name'] ?? ''}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text(
                                    'نام قانونی: ${_businessProfile!['legal_name'] ?? ''}'),
                                const SizedBox(height: 6),
                                Text(
                                    'نوع: ${_businessProfile!['business_type'] ?? ''}'),
                                const SizedBox(height: 6),
                                Text(
                                    'زمینه فعالیت: ${_businessProfile!['activity_area'] ?? ''}'),
                                const SizedBox(height: 6),
                                Text(
                                    'تلفن: ${_businessProfile!['phone'] ?? ''}'),
                                const SizedBox(height: 6),
                                Text(
                                    'ایمیل: ${_businessProfile!['email'] ?? ''}'),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    FilledButton.tonal(
                                      onPressed: _editBusinessDialog,
                                      child: const Text('ویرایش سریع'),
                                    ),
                                    const SizedBox(width: 12),
                                    OutlinedButton(
                                      onPressed: () {
                                        // باز کردن صفحهٔ کامل تنظیمات کسب‌وکار
                                        Navigator.of(context)
                                            .pushNamed('/settings/business');
                                      },
                                      child: const Text('ویرایش کامل'),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
