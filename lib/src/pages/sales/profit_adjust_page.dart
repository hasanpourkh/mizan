// lib/src/pages/sales/profit_adjust_page.dart
// صفحهٔ ثبت تعدیل سود سهامداران: یک تعدیل (adjustment) به جدول profit_shares اضافه میکند.
// - کاربر میتواند شخص، مبلغ، توضیح و تاریخ را وارد کند.
// - همهٔ عملیات داخل تراکنش و امن انجام میشود.
// - کامنت فارسی مختصر برای هر بخش.

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';

class ProfitAdjustPage extends StatefulWidget {
  const ProfitAdjustPage({super.key});

  @override
  State<ProfitAdjustPage> createState() => _ProfitAdjustPageState();
}

class _ProfitAdjustPageState extends State<ProfitAdjustPage> {
  List<Map<String, dynamic>> _persons = [];
  int? _selectedPersonId;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPersons();
  }

  Future<void> _loadPersons() async {
    final ps = await AppDatabase.getPersons();
    setState(() => _persons = ps);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (d != null) setState(() => _selectedDate = d);
  }

  Future<void> _saveAdjust() async {
    final pid = _selectedPersonId;
    final amt = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final note = _noteCtrl.text.trim();
    if (pid == null) {
      NotificationService.showError(context, 'خطا', 'یک شخص را انتخاب کنید');
      return;
    }
    if (amt == 0.0) {
      NotificationService.showError(context, 'خطا', 'مبلغ معتبر وارد کنید');
      return;
    }

    setState(() => _saving = true);
    try {
      final db = await AppDatabase.db;
      final now = _selectedDate.millisecondsSinceEpoch;
      await db.transaction((txn) async {
        await txn.insert('profit_shares', {
          'sale_id': null,
          'sale_line_id': null,
          'person_id': pid,
          'percent': 0,
          'amount': amt,
          'is_adjustment': 1,
          'note': note,
          'created_at': now
        });
      });
      NotificationService.showSuccess(
          context, 'ثبت شد', 'تعدیل با موفقیت ثبت شد');
      _amountCtrl.clear();
      _noteCtrl.clear();
      await _loadPersons();
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'ثبت تعدیل انجام نشد: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  String _fmtJalali(DateTime d) {
    final j = Jalali.fromDateTime(d);
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ثبت تعدیل سود سهامداران'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int?>(
                    initialValue: _selectedPersonId,
                    decoration: const InputDecoration(
                        labelText: 'انتخاب شخص', isDense: true),
                    items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('- انتخاب -'))
                        ] +
                        _persons.map((p) {
                          final id = (p['id'] is int)
                              ? p['id'] as int
                              : int.tryParse(p['id']?.toString() ?? '') ?? 0;
                          final name = p['display_name']?.toString() ??
                              '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}';
                          return DropdownMenuItem<int?>(
                              value: id, child: Text(name));
                        }).toList(),
                    onChanged: (v) => setState(() => _selectedPersonId = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                      controller: _amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText:
                              'مبلغ (مثبت برای اضافه / منفی برای کم کردن)',
                          isDense: true)),
                  const SizedBox(height: 8),
                  TextField(
                      controller: _noteCtrl,
                      decoration: const InputDecoration(
                          labelText: 'یادداشت (اختیاری)', isDense: true)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: Text('تاریخ: ${_fmtJalali(_selectedDate)}')),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                        onPressed: _pickDate,
                        child: const Text('انتخاب تاریخ')),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: FilledButton.tonal(
                            onPressed: _saving ? null : _saveAdjust,
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Text('ثبت تعدیل'))),
                    const SizedBox(width: 8),
                    OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('انصراف')),
                  ])
                ]),
          ),
        ),
      ),
    );
  }
}
