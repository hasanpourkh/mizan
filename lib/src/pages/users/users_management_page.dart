// lib/src/pages/users/users_management_page.dart
// صفحه مدیریت کاربران (User Management) — فقط قابل مشاهده و استفاده توسط ادمین.
// - فهرست اشخاص را نشان میدهد و امکان فیلتر براساس نقش (کارمندان، فروشندگان، سهامداران).
// - برای هر شخص میتوان نامکاربری و رمز تعریف کرد (نگهداری در flutter_secure_storage برای هر person).
// - رمز بصورت SHA256 هش میشود و ذخیره میگردد؛ همچنین امکان حذف اعتبار برای یک شخص وجود دارد.
// - کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/auth/admin_auth.dart';

class UsersManagementPage extends StatefulWidget {
  const UsersManagementPage({super.key});

  @override
  State<UsersManagementPage> createState() => _UsersManagementPageState();
}

enum UserFilter { all, employees, sellers, shareholders }

class _UsersManagementPageState extends State<UsersManagementPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _persons = [];
  UserFilter _filter = UserFilter.all;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await AppDatabase.init();
      final list = await AppDatabase.getPersons();
      _persons = list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      _persons = [];
      NotificationService.showToast(context, 'بارگذاری انجام نشد: $e',
          backgroundColor: Colors.orange);
    } finally {
      setState(() => _loading = false);
    }
  }

  // کلیدهای نگهداری credential برای شخص: user_{id}_username و user_{id}_password_hash
  String _keyUser(int id) => 'user_${id}_username';
  String _keyPass(int id) => 'user_${id}_password_hash';

  // خواندن username برای شخص
  Future<String?> _getUsernameFor(int id) async {
    return await _storage.read(key: _keyUser(id));
  }

  // تعیین username/password برای شخص
  Future<void> _setCredentialsFor(
      int id, String username, String password) async {
    final hash = _hashPassword(password);
    await _storage.write(key: _keyUser(id), value: username.trim());
    await _storage.write(key: _keyPass(id), value: hash);
    NotificationService.showToast(context, 'اعتبار کاربر ذخیره شد');
    setState(() {});
  }

  // حذف credential برای شخص
  Future<void> _clearCredentialsFor(int id) async {
    await _storage.delete(key: _keyUser(id));
    await _storage.delete(key: _keyPass(id));
    NotificationService.showToast(context, 'اعتبار کاربر حذف شد');
    setState(() {});
  }

  String _hashPassword(String pass) {
    final bytes = utf8.encode(pass);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // باز کردن دیالوگ ست کردن/ویرایش اعتبار برای شخص
  Future<void> _openSetCredDialog(Map<String, dynamic> person) async {
    final idRaw = person['id'];
    final id =
        (idRaw is int) ? idRaw : int.tryParse(idRaw?.toString() ?? '') ?? 0;
    final display = person['display_name']?.toString() ??
        '${person['first_name'] ?? ''} ${person['last_name'] ?? ''}';
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    final existing = await _getUsernameFor(id);
    if (existing != null) userCtrl.text = existing;

    await showDialog(
      context: context,
      builder: (c) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('تنظیم اعتبار برای $display'),
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
                        labelText: 'رمز عبور (جدید)',
                        border: OutlineInputBorder())),
                const SizedBox(height: 8),
                const Text(
                    'نکته: رمز جدید وارد کنید تا بهروزرسانی شود. اگر میخواهید رمز را حذف کنید از دکمهٔ حذف اعتبار استفاده کنید.',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(c).pop(),
                  child: const Text('لغو')),
              FilledButton.tonal(
                  onPressed: () async {
                    final u = userCtrl.text.trim();
                    final p = passCtrl.text;
                    if (u.isEmpty || p.length < 4) {
                      NotificationService.showError(context, 'خطا',
                          'نامکاربری و رمز معتبر نیست (رمز حداقل 4 کاراکتر)');
                      return;
                    }
                    await _setCredentialsFor(id, u, p);
                    Navigator.of(c).pop();
                  },
                  child: const Text('ذخیره')),
            ],
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> get _viewRows {
    switch (_filter) {
      case UserFilter.employees:
        return _persons.where((p) => _flagIsTrue(p['type_employee'])).toList();
      case UserFilter.sellers:
        return _persons.where((p) => _flagIsTrue(p['type_seller'])).toList();
      case UserFilter.shareholders:
        return _persons
            .where((p) => _flagIsTrue(p['type_shareholder']))
            .toList();
      case UserFilter.all:
      default:
        return _persons;
    }
  }

  bool _flagIsTrue(dynamic v) {
    if (v == null) return false;
    if (v is int) return v == 1;
    if (v is bool) return v;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // صفحهٔ مدیریت کاربران محافظتشده: از AdminGate استفاده کن
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('مدیریت کاربران (Users)')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(children: [
                      ChoiceChip(
                          label: const Text('همه'),
                          selected: _filter == UserFilter.all,
                          onSelected: (_) =>
                              setState(() => _filter = UserFilter.all)),
                      const SizedBox(width: 8),
                      ChoiceChip(
                          label: const Text('کارمندان'),
                          selected: _filter == UserFilter.employees,
                          onSelected: (_) =>
                              setState(() => _filter = UserFilter.employees)),
                      const SizedBox(width: 8),
                      ChoiceChip(
                          label: const Text('فروشندگان'),
                          selected: _filter == UserFilter.sellers,
                          onSelected: (_) =>
                              setState(() => _filter = UserFilter.sellers)),
                      const SizedBox(width: 8),
                      ChoiceChip(
                          label: const Text('سهامداران'),
                          selected: _filter == UserFilter.shareholders,
                          onSelected: (_) => setState(
                              () => _filter = UserFilter.shareholders)),
                      const Spacer(),
                      FilledButton.tonal(
                          onPressed: _load, child: const Text('بارگذاری مجدد')),
                    ]),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Card(
                        child: _viewRows.isEmpty
                            ? const Center(
                                child: Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: Text('هیچ کاربری یافت نشد')))
                            : ListView.separated(
                                itemCount: _viewRows.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (ctx, idx) {
                                  final p = _viewRows[idx];
                                  final id = (p['id'] is int)
                                      ? p['id'] as int
                                      : int.tryParse(
                                              p['id']?.toString() ?? '') ??
                                          0;
                                  final display = p['display_name']
                                          ?.toString() ??
                                      '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}';
                                  return FutureBuilder<String?>(
                                    future: _getUsernameFor(id),
                                    builder: (c, s) {
                                      final username =
                                          s.hasData ? s.data : null;
                                      return ListTile(
                                        title: Text(display),
                                        subtitle: Text(username != null
                                            ? 'نامکاربری: $username'
                                            : 'اعتبار تنظیم نشده'),
                                        trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                  icon:
                                                      const Icon(Icons.vpn_key),
                                                  tooltip:
                                                      'تنظیم/ویرایش اعتبار',
                                                  onPressed: () =>
                                                      _openSetCredDialog(p)),
                                              IconButton(
                                                  icon: const Icon(Icons.delete,
                                                      color: Colors.red),
                                                  tooltip: 'حذف اعتبار',
                                                  onPressed: () async {
                                                    final ok = await showDialog<
                                                            bool>(
                                                        context: context,
                                                        builder: (c) =>
                                                            Directionality(
                                                                textDirection:
                                                                    TextDirection
                                                                        .rtl,
                                                                child:
                                                                    AlertDialog(
                                                                  title: const Text(
                                                                      'حذف اعتبار'),
                                                                  content: Text(
                                                                      'آیا میخواهید اعتبار کاربر "$display" حذف شود؟'),
                                                                  actions: [
                                                                    TextButton(
                                                                        onPressed: () =>
                                                                            Navigator.of(c).pop(
                                                                                false),
                                                                        child: const Text(
                                                                            'خیر')),
                                                                    FilledButton.tonal(
                                                                        onPressed: () =>
                                                                            Navigator.of(c).pop(
                                                                                true),
                                                                        child: const Text(
                                                                            'حذف')),
                                                                  ],
                                                                )));
                                                    if (ok == true) {
                                                      await _clearCredentialsFor(
                                                          id);
                                                    }
                                                  }),
                                            ]),
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.person_add),
          label: const Text('ایجاد شخص جدید'),
          onPressed: () => Navigator.of(context)
              .pushNamed('/persons/new')
              .then((_) => _load()),
        ),
      ),
    );
  }
}
