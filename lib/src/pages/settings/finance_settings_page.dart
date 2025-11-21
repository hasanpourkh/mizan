// lib/src/pages/settings/finance_settings_page.dart
// صفحه تنظیمات مالی: حذف persian_datetime_picker و استفاده از jalali_utils
// - انتخابگر تاریخ شروع اکنون از showDatePicker استفاده میکند و نتیجه به صورت رشتهٔ Jalali ذخیره میشود.
// - بقیهٔ رفتارها حفظ شده است.
// - کامنتهای فارسی مختصر برای هر بخش وجود دارد.

import 'package:flutter/material.dart';
import '../../core/db/database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/utils/jalali_utils.dart';

class FinanceSettingsPage extends StatefulWidget {
  const FinanceSettingsPage({super.key});

  @override
  State<FinanceSettingsPage> createState() => _FinanceSettingsPageState();
}

class _FinanceSettingsPageState extends State<FinanceSettingsPage> {
  final Map<String, TextEditingController> _ctrl = {};
  bool _loading = true;
  Map<String, dynamic> _data = {};

  // گزینهها: برای واحد پول از زوج (کد, برچسب) استفاده میکنیم تا مقدار value همواره یکتا باشد
  final List<String> _inventorySystems = [
    'سیستم حسابداری انبار',
    'سیستم ساده موجودی',
    'مدیریت کاردکس'
  ];
  final List<String> _inventoryValuations = ['FIFO', 'LIFO', 'میانگین موزون'];
  final List<Map<String, String>> _currencies = [
    {'code': 'IRR', 'label': 'IRR - ریال ایران'},
    {'code': 'USD', 'label': 'USD - دلار'},
    {'code': 'EUR', 'label': 'EUR - یورو'},
  ];
  final List<String> _calendars = ['هجری شمسی', 'میلادی'];

  @override
  void initState() {
    super.initState();
    _initControllers();
    _load();
  }

  void _initControllers() {
    final keys = [
      'inventory_system',
      'inventory_valuation',
      'multi_currency',
      'inventory_enabled',
      'currency', // این فیلد کد واحد پول را نگه میدارد (مثلاً 'IRR')
      'calendar',
      'vat_rate',
      'fiscal_start',
      'fiscal_end',
      'fiscal_title',
    ];
    for (var k in keys) {
      _ctrl[k] = TextEditingController();
    }
  }

  // بارگذاری از دیتابیس و تطبیق با گزینهها
  Future<void> _load() async {
    setState(() => _loading = true);
    final bp = await AppDatabase.getBusinessProfile();
    _data = bp ?? {};

    // مقداردهی کنترلرها با fallback منطقی
    _ctrl['inventory_system']!.text =
        _data['inventory_system']?.toString() ?? _inventorySystems.first;
    _ctrl['inventory_valuation']!.text =
        _data['inventory_valuation']?.toString() ?? _inventoryValuations.first;
    _ctrl['multi_currency']!.text = (_data['multi_currency'] == 1 ? '1' : '0');
    _ctrl['inventory_enabled']!.text =
        (_data['inventory_enabled'] == 1 ? '1' : '0');

    // خواندن واحد پول ذخیره شده: ممکن است در DB فقط 'IRR' ذخیره شده باشد یا 'IRR' قبلاً ذخیره نشده
    final storedCurrency = _data['currency']?.toString();
    if (storedCurrency != null && storedCurrency.isNotEmpty) {
      final found = _currencies.firstWhere(
          (c) =>
              c['code'] == storedCurrency ||
              c['label']?.startsWith(storedCurrency) == true,
          orElse: () => _currencies.first);
      _ctrl['currency']!.text = found['code']!;
    } else {
      _ctrl['currency']!.text = _currencies.first['code']!;
    }

    _ctrl['calendar']!.text = _data['calendar']?.toString() ?? _calendars.first;
    _ctrl['vat_rate']!.text = (_data['vat_rate']?.toString() ?? '10');
    _ctrl['fiscal_start']!.text = _data['fiscal_start']?.toString() ?? '';
    _ctrl['fiscal_end']!.text = _data['fiscal_end']?.toString() ?? '';
    _ctrl['fiscal_title']!.text = _data['fiscal_title']?.toString() ?? '';
    setState(() => _loading = false);
  }

  // ذخیره مقادیر: currency مطابق کد ذخیره میشود (IRR, USD, EUR)
  Future<void> _save() async {
    setState(() => _loading = true);
    final Map<String, dynamic> toSave = Map<String, dynamic>.from(_data);
    toSave['inventory_system'] = _ctrl['inventory_system']!.text.trim();
    toSave['inventory_valuation'] = _ctrl['inventory_valuation']!.text.trim();
    toSave['multi_currency'] = (_ctrl['multi_currency']!.text == '1') ? 1 : 0;
    toSave['inventory_enabled'] =
        (_ctrl['inventory_enabled']!.text == '1') ? 1 : 0;
    toSave['currency'] = _ctrl['currency']!.text.trim(); // ذخیره کد واحد پول
    toSave['calendar'] = _ctrl['calendar']!.text.trim();
    toSave['vat_rate'] = double.tryParse(_ctrl['vat_rate']!.text) ?? 0.0;
    toSave['fiscal_start'] = _ctrl['fiscal_start']!.text.trim();
    toSave['fiscal_end'] = _ctrl['fiscal_end']!.text.trim();
    toSave['fiscal_title'] = _ctrl['fiscal_title']!.text.trim();
    toSave['created_at'] = DateTime.now().millisecondsSinceEpoch;

    try {
      await AppDatabase.saveBusinessProfile(toSave);
      NotificationService.showSuccess(
          context, 'ذخیره شد', 'تنظیمات مالی ذخیره شد');
      _load();
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'ذخیره انجام نشد');
    } finally {
      setState(() => _loading = false);
    }
  }

  // انتخابگر تاریخ: از pickJalaliDate در jalali_utils استفاده می‌کنیم
  Future<void> _pickFiscalStart() async {
    try {
      final picked = await pickJalaliDate(context,
          initialJalali: _ctrl['fiscal_start']!.text);
      if (picked != null) {
        _ctrl['fiscal_start']!.text = picked;
        // محاسبه پایان یک سال جلو (شمسی)
        final j = parseJalaliString(picked);
        if (j != null) {
          final jEnd = j.addYears(1);
          _ctrl['fiscal_end']!.text = jalaliToString(jEnd);
        }
        setState(() {});
      }
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'انتخاب تاریخ انجام نشد: $e');
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  @override
  void dispose() {
    for (var c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('تنظیمات مالی'),
          elevation: 1,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: ListView(
                      children: [
                        const Text('تنظیمات مالی و انبار',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),

                        // ردیف اول: سیستم انبار / روش ارزیابی / چندارزی
                        Row(children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: DropdownButtonFormField<String>(
                                initialValue: _ctrl['inventory_system']!.text,
                                decoration: _dec('سیستم حسابداری انبار'),
                                items: _inventorySystems
                                    .map((e) => DropdownMenuItem(
                                        value: e, child: Text(e)))
                                    .toList(),
                                onChanged: (v) => setState(() =>
                                    _ctrl['inventory_system']!.text = v ?? ''),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: DropdownButtonFormField<String>(
                                initialValue:
                                    _ctrl['inventory_valuation']!.text,
                                decoration: _dec('روش ارزیابی انبار'),
                                items: _inventoryValuations
                                    .map((e) => DropdownMenuItem(
                                        value: e, child: Text(e)))
                                    .toList(),
                                onChanged: (v) => setState(() =>
                                    _ctrl['inventory_valuation']!.text =
                                        v ?? ''),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('قابلیت چندارزی'),
                                value: _ctrl['multi_currency']!.text == '1',
                                onChanged: (v) => setState(() =>
                                    _ctrl['multi_currency']!.text =
                                        (v == true) ? '1' : '0'),
                              ),
                            ),
                          ),
                        ]),

                        // ردیف دوم: فعالسازی انبار / واحد پول / تقویم
                        Row(children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('فعالسازی انبارداری'),
                                value: _ctrl['inventory_enabled']!.text == '1',
                                onChanged: (v) => setState(() =>
                                    _ctrl['inventory_enabled']!.text =
                                        (v == true) ? '1' : '0'),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: DropdownButtonFormField<String>(
                                initialValue: _ctrl['currency']!.text.isNotEmpty
                                    ? _ctrl['currency']!.text
                                    : _currencies.first['code'],
                                decoration: _dec('واحد پول اصلی'),
                                items: _currencies
                                    .map((c) => DropdownMenuItem(
                                        value: c['code'],
                                        child: Text(c['label']!)))
                                    .toList(),
                                onChanged: (v) => setState(() =>
                                    _ctrl['currency']!.text =
                                        v ?? _currencies.first['code']!),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: DropdownButtonFormField<String>(
                                initialValue: _ctrl['calendar']!.text.isNotEmpty
                                    ? _ctrl['calendar']!.text
                                    : _calendars.first,
                                decoration: _dec('تقویم'),
                                items: _calendars
                                    .map((e) => DropdownMenuItem(
                                        value: e, child: Text(e)))
                                    .toList(),
                                onChanged: (v) => setState(() =>
                                    _ctrl['calendar']!.text =
                                        v ?? _calendars.first),
                              ),
                            ),
                          ),
                        ]),

                        // ردیف سوم: مالیات / تاریخ شروع / تاریخ پایان
                        Row(children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: TextField(
                                  controller: _ctrl['vat_rate'],
                                  decoration: _dec('نرخ مالیات (%)'),
                                  keyboardType: TextInputType.number),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: GestureDetector(
                                onTap: _pickFiscalStart,
                                child: AbsorbPointer(
                                  child: TextField(
                                      controller: _ctrl['fiscal_start'],
                                      decoration:
                                          _dec('تاریخ شروع سال مالی (شمسی)')),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: AbsorbPointer(
                                child: TextField(
                                    controller: _ctrl['fiscal_end'],
                                    decoration:
                                        _dec('تاریخ پایان سال مالی (خودکار)')),
                              ),
                            ),
                          ),
                        ]),

                        const SizedBox(height: 12),
                        TextField(
                            controller: _ctrl['fiscal_title'],
                            decoration: _dec('عنوان سال مالی')),

                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: FilledButton.tonal(
                                    onPressed: _save,
                                    child: const Text('ذخیره تنظیمات مالی'))),
                            const SizedBox(width: 12),
                            OutlinedButton(
                                onPressed: _load,
                                child: const Text('بارگذاری مجدد')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ));
  }
}
