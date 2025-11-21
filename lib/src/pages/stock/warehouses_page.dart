// lib/src/pages/stock/warehouses_page.dart
// صفحهٔ مدیریت انبارها (فهرست / افزودن / ویرایش / حذف)
// - اطمینان از استفاده از AppDatabase (lib/src/core/db/app_database.dart) برای همهٔ عملیات
// - هندلینگ خطا در صورت عدم مقداردهی دیتابیس و نمایش پیام مناسب
// - هنگام ذخیرهٔ انبار جدید، پیام واضحی در صورت خطا نمایش داده می‌شود.
// - کامنت فارسی مختصر در هر بخش وجود دارد.
//
// جایگزین فایل موجود با همین مسیر کن.

import 'package:flutter/material.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';

class WarehousesPage extends StatefulWidget {
  const WarehousesPage({super.key});

  @override
  State<WarehousesPage> createState() => _WarehousesPageState();
}

class _WarehousesPageState extends State<WarehousesPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // بارگذاری لیست انبارها از AppDatabase با هندلینگ خطا (مثلاً دیتابیس مقداردهی نشده)
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await AppDatabase.getWarehouses();
      if (mounted) {
        setState(() => _rows = List<Map<String, dynamic>>.from(list));
      }
    } catch (e) {
      // اگر دیتابیس مقداردهی نشده یا خطای دیگر، پیام واضح بده
      final err = e.toString();
      if (err.contains('دیتابیس مقداردهی نشده') || err.contains('init')) {
        NotificationService.showError(context, 'خطا',
            'دیتابیس مقداردهی نشده است. لطفاً اپ را بازراه‌اندازی کن یا مسیر دیتابیس را در تنظیمات بررسی کن.');
      } else {
        NotificationService.showError(
            context, 'خطا', 'بارگذاری انبارها انجام نشد: $e');
      }
      if (mounted) setState(() => _rows = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // باز کردن فرم افزودن/ویرایش انبار در دیالوگ
  Future<void> _openEditor([Map<String, dynamic>? editing]) async {
    final nameCtrl =
        TextEditingController(text: editing?['name']?.toString() ?? '');
    final codeCtrl =
        TextEditingController(text: editing?['code']?.toString() ?? '');
    final addrCtrl =
        TextEditingController(text: editing?['address']?.toString() ?? '');
    final phoneCtrl =
        TextEditingController(text: editing?['phone']?.toString() ?? '');
    final emailCtrl =
        TextEditingController(text: editing?['email']?.toString() ?? '');
    final managerCtrl =
        TextEditingController(text: editing?['manager']?.toString() ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) {
        return AlertDialog(
          title: Text(editing == null ? 'افزودن انبار جدید' : 'ویرایش انبار'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'نام انبار', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                        labelText: 'کد انبار (اختیاری)',
                        border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(
                    controller: addrCtrl,
                    decoration: const InputDecoration(
                        labelText: 'آدرس', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(
                              labelText: 'تلفن',
                              border: OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(
                              labelText: 'ایمیل',
                              border: OutlineInputBorder()))),
                ]),
                const SizedBox(height: 8),
                TextField(
                    controller: managerCtrl,
                    decoration: const InputDecoration(
                        labelText: 'مدیر انبار', border: OutlineInputBorder())),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('لغو')),
            FilledButton.tonal(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('ذخیره')),
          ],
        );
      },
    );

    if (ok != true) {
      return;
    }

    final item = <String, dynamic>{
      'name': nameCtrl.text.trim(),
      'code': codeCtrl.text.trim(),
      'address': addrCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
      'email': emailCtrl.text.trim(),
      'manager': managerCtrl.text.trim(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };

    if (editing != null && editing['id'] != null) item['id'] = editing['id'];

    try {
      await AppDatabase.saveWarehouse(item);
      NotificationService.showSuccess(context, 'ذخیره شد', 'انبار ذخیره شد');
      await _load();
    } catch (e) {
      final err = e.toString();
      if (err.contains('دیتابیس مقداردهی نشده') || err.contains('init')) {
        NotificationService.showError(context, 'ذخیره انجام نشد',
            'دیتابیس مقداردهی نشده است. قبل از ایجاد انبار، دیتابیس را مقداردهی کن.');
      } else {
        NotificationService.showError(
            context, 'ذخیره انجام نشد', 'خطا در ذخیرهٔ انبار: $e');
      }
    }
  }

  // حذف انبار با دیالوگ تایید
  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف انبار'),
        content: const Text(
            'آیا از حذف این انبار مطمئن هستید؟ این عملیات ممکن است داده‌های انبار مرتبط را نیز تحت تاثیر قرار دهد.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('لغو')),
          FilledButton.tonal(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('حذف')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await AppDatabase.deleteWarehouse(id);
      NotificationService.showToast(context, 'انبار حذف شد');
      await _load();
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'حذف انبار انجام نشد: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('انبارها')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'افزودن انبار',
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(children: [
                        const Expanded(
                            child: Text('فهرست انبارها',
                                style: TextStyle(fontWeight: FontWeight.w600))),
                        FilledButton.tonal(
                            onPressed: _load,
                            child: const Text('بارگذاری مجدد')),
                      ]),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _rows.isEmpty
                          ? const Center(child: Text('انبری ثبت نشده است'))
                          : ListView.separated(
                              itemCount: _rows.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                final r = _rows[idx];
                                final id = (r['id'] is int)
                                    ? r['id'] as int
                                    : int.tryParse(r['id']?.toString() ?? '') ??
                                        0;
                                return ListTile(
                                  title: Text(r['name']?.toString() ?? ''),
                                  subtitle: Text((r['code']?.toString() ?? '') +
                                      (r['address'] != null
                                          ? ' • ${r['address']}'
                                          : '')),
                                  trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                            icon: const Icon(Icons.edit),
                                            onPressed: () => _openEditor(r)),
                                        IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () => _delete(id)),
                                      ]),
                                );
                              },
                            ),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
