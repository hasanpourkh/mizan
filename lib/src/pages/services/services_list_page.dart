// lib/src/pages/services/services_list_page.dart
// صفحهٔ فهرست خدمات — نمایش، جستجو، افزودن سریع، ویرایش و حذف.
// - از AppDatabase.getServices استفاده میکند.
// - کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'package:flutter/material.dart';
import 'package:mizan/src/core/db/daos/services_dao.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';
import 'new_service_page.dart';

class ServicesListPage extends StatefulWidget {
  const ServicesListPage({super.key});

  @override
  State<ServicesListPage> createState() => _ServicesListPageState();
}

class _ServicesListPageState extends State<ServicesListPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await AppDatabase.getServices();
      setState(() => _rows = rows);
    } catch (e) {
      setState(() => _rows = []);
      NotificationService.showToast(context, 'بارگذاری خدمات انجام نشد: $e',
          backgroundColor: Colors.orange);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف خدمت'),
        content: const Text('آیا از حذف این خدمت مطمئن هستید؟'),
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
    if (ok == true) {
      try {
        await AppDatabase.deleteService(id);
        NotificationService.showToast(context, 'خدمت حذف شد');
        await _load();
      } catch (e) {
        NotificationService.showError(context, 'خطا', 'حذف انجام نشد: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _q.trim().isEmpty
        ? _rows
        : _rows.where((r) {
            final name = r['name']?.toString().toLowerCase() ?? '';
            final code = r['code']?.toString().toLowerCase() ?? '';
            return name.contains(_q.toLowerCase()) ||
                code.contains(_q.toLowerCase());
          }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('فهرست خدمات')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'افزودن خدمت جدید',
        onPressed: () async {
          await Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const NewServicePage()));
          await _load();
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: TextField(
                          decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'جستجو خدمات'),
                          onChanged: (v) => setState(() => _q = v))),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                      onPressed: _load, child: const Text('بارگذاری مجدد')),
                ]),
                const SizedBox(height: 12),
                Expanded(
                    child: Card(
                        child: _rows.isEmpty
                            ? const Center(child: Text('هیچ خدمتی ثبت نشده'))
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (ctx, idx) {
                                  final r = filtered[idx];
                                  final id = r['id']?.toString() ?? '';
                                  final name = r['name']?.toString() ?? '';
                                  final price = (r['price'] is num)
                                      ? (r['price'] as num).toDouble()
                                      : double.tryParse(
                                              r['price']?.toString() ?? '') ??
                                          0.0;
                                  final cat =
                                      r['category_id']?.toString() ?? '';
                                  return ListTile(
                                    title: Text(name),
                                    subtitle: Text(
                                        'قیمت: ${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)} · دسته: $cat'),
                                    trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                              icon: const Icon(Icons.edit),
                                              onPressed: () async {
                                                await Navigator.of(context)
                                                    .push(MaterialPageRoute(
                                                        builder: (_) =>
                                                            NewServicePage(
                                                                editing: Map<
                                                                        String,
                                                                        dynamic>.from(
                                                                    r))));
                                                await _load();
                                              }),
                                          IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.red),
                                              onPressed: () => _delete(
                                                  int.tryParse(id) ?? 0)),
                                        ]),
                                  );
                                },
                              ))),
              ]),
            ),
    );
  }
}
