// lib/src/pages/sales/sale_customer_picker.dart
// ویجت/دیالوگ انتخاب مشتری با جستجو — بازشونده از صفحهٔ فروش
// - وقتی کاربر فیلد مشتری را کلیک کند این دیالوگ باز می‌شود و امکان جستجو و انتخاب دارد.
// - خروجی: Map<String,dynamic>? (رکورد مشتری انتخاب‌شده) یا null اگر بسته شد.
// کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'package:flutter/material.dart';
import '../../core/db/app_database.dart';

Future<Map<String, dynamic>?> showCustomerPickerDialog(
    BuildContext context) async {
  final persons = await AppDatabase.getPersons();
  // فیلتر اولیه: اگر ستون type_customer موجود باشد از آن استفاده میکنیم، در غیر این صورت همه اشخاص نمایش داده می‌شوند
  List<Map<String, dynamic>> customers;
  final hasType = persons.any((p) => p.containsKey('type_customer'));
  if (hasType) {
    final filtered = persons.where((p) {
      final v = p['type_customer'];
      if (v == null) return false;
      if (v is int) return v == 1;
      if (v is bool) return v;
      if (v is String) return v == '1' || v.toLowerCase() == 'true';
      return false;
    }).toList();
    customers = filtered.isNotEmpty ? filtered : List.from(persons);
  } else {
    customers = List.from(persons);
  }

  final TextEditingController searchCtrl = TextEditingController();
  List<Map<String, dynamic>> list = List.from(customers);

  final selected = await showDialog<Map<String, dynamic>?>(
    context: context,
    builder: (c) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(builder: (ctx, setSt) {
          void applyFilter() {
            final t = searchCtrl.text.trim().toLowerCase();
            if (t.isEmpty) {
              list = List.from(customers);
            } else {
              list = customers.where((p) {
                final name = p['display_name']?.toString().toLowerCase() ?? '';
                final first = p['first_name']?.toString().toLowerCase() ?? '';
                final last = p['last_name']?.toString().toLowerCase() ?? '';
                final phone = p['phone']?.toString().toLowerCase() ?? '';
                final email = p['email']?.toString().toLowerCase() ?? '';
                return name.contains(t) ||
                    first.contains(t) ||
                    last.contains(t) ||
                    phone.contains(t) ||
                    email.contains(t);
              }).toList();
            }
            setSt(() {});
          }

          searchCtrl.addListener(() => applyFilter());

          return AlertDialog(
            title: const Text('انتخاب مشتری'),
            content: SizedBox(
              width: 640,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'جستجو مشتری (نام/تلفن/ایمیل)'),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: list.isEmpty
                        ? const Center(child: Text('مشتری یافت نشد'))
                        : ListView.separated(
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 6),
                            itemBuilder: (ctx2, idx) {
                              final p = list[idx];
                              final title = p['display_name']?.toString() ??
                                  '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}';
                              final subtitle = p['phone']?.toString() ??
                                  p['email']?.toString() ??
                                  '';
                              return ListTile(
                                title: Text(title),
                                subtitle: Text(subtitle),
                                onTap: () => Navigator.of(c).pop(p),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(c).pop(null),
                  child: const Text('بستن')),
            ],
          );
        }),
      );
    },
  );

  searchCtrl.dispose();
  return selected;
}
