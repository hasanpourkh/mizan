// lib/src/pages/persons/shareholders_page.dart
// صفحهٔ فهرست سهامداران: نمایش فقط رکوردهای type_shareholder == true
// - جدول شبیه صفحهٔ لیست اشخاص، اما ستونهای مرتبط با سهام (درصد، مجموع سهام) برجسته شده‌اند
// - امکان ویرایش درصد (دیالوگ ساده) و بررسی مجموع (اجازهٔ افزایش تا 100%)
// - کامنت فارسی مختصر برای هر بخش

import 'package:flutter/material.dart';
import '../../core/db/database.dart';
import '../../core/notifications/notification_service.dart';

class ShareholdersPage extends StatefulWidget {
  const ShareholdersPage({super.key});

  @override
  State<ShareholdersPage> createState() => _ShareholdersPageState();
}

class _ShareholdersPageState extends State<ShareholdersPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadShareholders();
  }

  Future<void> _loadShareholders() async {
    setState(() => _loading = true);
    try {
      final all = await AppDatabase.getPersons();
      _rows = all
          .where((p) {
            final v = p['type_shareholder'];
            if (v == null) return false;
            if (v is int) return v == 1;
            if (v is bool) return v;
            if (v is String) return v == '1' || v.toLowerCase() == 'true';
            return false;
          })
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      _rows = [];
    } finally {
      setState(() => _loading = false);
    }
  }

  // باز کردن دیالوگ برای ویرایش درصد سهام شخص
  Future<void> _editSharePercent(Map<String, dynamic> person) async {
    final idRaw = person['id'];
    final id =
        (idRaw is int) ? idRaw : int.tryParse(idRaw?.toString() ?? '') ?? 0;
    final old = (person['shareholder_percentage'] is num)
        ? (person['shareholder_percentage'] as num).toDouble()
        : double.tryParse(person['shareholder_percentage']?.toString() ?? '') ??
            0.0;
    final ctrl = TextEditingController(text: old.toStringAsFixed(2));
    final res = await showDialog<bool>(
      context: context,
      builder: (c) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('ویرایش درصد سهام'),
            content: TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'درصد سهام (مثلاً 12.5)'),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(c).pop(false),
                  child: const Text('لغو')),
              FilledButton.tonal(
                  onPressed: () => Navigator.of(c).pop(true),
                  child: const Text('ذخیره')),
            ],
          ),
        );
      },
    );

    if (res == true) {
      final parsed = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
      if (parsed <= 0.0) {
        NotificationService.showError(context, 'خطا', 'درصد معتبر وارد کنید');
        return;
      }
      if (parsed > 100.0) {
        NotificationService.showError(
            context, 'خطا', 'درصد نمیتواند بیشتر از 100 باشد');
        return;
      }
      final can = await AppDatabase.canAddShareholder(parsed - old);
      if (!can) {
        final total = await AppDatabase.getTotalSharePercentage();
        final remain = (100.0 - total).clamp(0.0, 100.0);
        NotificationService.showError(context, 'خطا',
            'با این تغییر، مجموع سهام از 100 بیشتر میشود. باقیمانده: ${remain.toStringAsFixed(2)}%');
        return;
      }
      // update types (share percentage) از facade
      await AppDatabase.updatePersonTypes(
          id, {'shareholder_percentage': parsed, 'type_shareholder': 1});
      NotificationService.showToast(context, 'درصد با موفقیت بروزرسانی شد');
      await _loadShareholders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سهامداران')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('کد')),
                        DataColumn(label: Text('نام نمایشی')),
                        DataColumn(label: Text('نام')),
                        DataColumn(label: Text('تلفن')),
                        DataColumn(label: Text('ایمیل')),
                        DataColumn(label: Text('درصد سهام')),
                        DataColumn(label: Text('مجموع فعلی سهام')),
                        DataColumn(label: Text('عملیات')),
                      ],
                      rows: _rows.map((r) {
                        final id = (r['id'] is int)
                            ? r['id'] as int
                            : int.tryParse(r['id']?.toString() ?? '') ?? 0;
                        final account = r['account_code']?.toString() ?? '';
                        final display = r['display_name']?.toString() ?? '';
                        final first = r['first_name']?.toString() ?? '';
                        final phone = r['phone']?.toString() ?? '';
                        final email = r['email']?.toString() ?? '';
                        final percent = (r['shareholder_percentage'] is num)
                            ? (r['shareholder_percentage'] as num)
                                .toDouble()
                                .toStringAsFixed(2)
                            : (r['shareholder_percentage']?.toString() ?? '0');
                        return DataRow(cells: [
                          DataCell(Text(account)),
                          DataCell(Text(display)),
                          DataCell(Text(first)),
                          DataCell(Text(phone)),
                          DataCell(Text(email)),
                          DataCell(Text('$percent %')),
                          DataCell(FutureBuilder<double>(
                            future: AppDatabase.getTotalSharePercentage(),
                            builder: (c, s) {
                              if (!s.hasData) return const Text('...');
                              return Text('${s.data!.toStringAsFixed(2)} %');
                            },
                          )),
                          DataCell(Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: 'ویرایش درصد',
                                onPressed: () => _editSharePercent(r),
                              ),
                              IconButton(
                                icon: const Icon(Icons.more_vert),
                                onPressed: () => NotificationService.showToast(
                                    context, 'عملیات بیشتر روی $id'),
                              )
                            ],
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
