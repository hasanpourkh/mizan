// lib/src/pages/persons/sellers_list_page.dart
// صفحهٔ فهرست فروشندگان — نمایش همهٔ اشخاصی که type_seller == true
// - امکان ویرایش/حذف هر فروشنده (از طریق مسیر قدیمی و AppDatabase)
// - اگر type_seller ستون وجود نداشته باشد، fallback به لیست خالی انجام میشود.
// - کامنت فارسی مختصر برای هر بخش

import 'package:flutter/material.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../persons/new_person_page.dart';

class SellersListPage extends StatefulWidget {
  const SellersListPage({super.key});

  @override
  State<SellersListPage> createState() => _SellersListPageState();
}

class _SellersListPageState extends State<SellersListPage> {
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
      final all = await AppDatabase.getPersons();
      // اگر ستون type_seller وجود داشته باشد فیلتر کن، در غیر این صورت همه را نمایش نده
      final hasType = all.isNotEmpty && all.first.containsKey('type_seller');
      final filtered = hasType
          ? all.where((p) {
              final v = p['type_seller'];
              if (v == null) return false;
              if (v is int) return v == 1;
              if (v is bool) return v;
              if (v is String) return v == '1' || v.toLowerCase() == 'true';
              return false;
            }).toList()
          : [];
      setState(() => _rows = filtered);
    } catch (e) {
      setState(() => _rows = []);
      NotificationService.showToast(context, 'بارگذاری انجام نشد: $e',
          backgroundColor: Colors.orange);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف فروشنده'),
        content: const Text('آیا از حذف این فروشنده اطمینان دارید؟'),
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
        await AppDatabase.deletePerson(id);
        NotificationService.showToast(context, 'فروشنده حذف شد');
        await _load();
      } catch (e) {
        NotificationService.showError(context, 'خطا', 'حذف انجام نشد: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewRows = _q.trim().isEmpty
        ? _rows
        : _rows.where((r) {
            final name = r['display_name']?.toString().toLowerCase() ?? '';
            final phone = r['phone']?.toString().toLowerCase() ?? '';
            return name.contains(_q.toLowerCase()) ||
                phone.contains(_q.toLowerCase());
          }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('فهرست فروشندگان')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'افزودن فروشنده جدید',
        onPressed: () => Navigator.of(context)
            .pushNamed('/persons/new')
            .then((_) => _load()),
        child: const Icon(Icons.person_add),
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
                              hintText: 'جستجو فروشنده'),
                          onChanged: (v) => setState(() => _q = v))),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                      onPressed: _load, child: const Text('بارگذاری مجدد')),
                ]),
                const SizedBox(height: 12),
                Expanded(
                    child: Card(
                  child: viewRows.isEmpty
                      ? const Center(child: Text('فروشنده‌ای یافت نشد'))
                      : ListView.separated(
                          itemCount: viewRows.length,
                          separatorBuilder: (_, __) => const Divider(height: 6),
                          itemBuilder: (ctx, idx) {
                            final p = viewRows[idx];
                            final id = (p['id'] is int)
                                ? p['id'] as int
                                : int.tryParse(p['id']?.toString() ?? '') ?? 0;
                            final display = p['display_name']?.toString() ??
                                '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}';
                            final phone = p['phone']?.toString() ?? '';
                            return ListTile(
                              title: Text(display),
                              subtitle: Text(phone),
                              trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () async {
                                          final person =
                                              Map<String, dynamic>.from(p);
                                          await Navigator.of(context).push(
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const NewPersonPage()));
                                          await _load();
                                        }),
                                    IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => _delete(id)),
                                  ]),
                            );
                          }),
                )),
              ]),
            ),
    );
  }
}
