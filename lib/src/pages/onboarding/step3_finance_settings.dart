// lib/src/pages/onboarding/step3_finance_settings.dart
// مرحلهٔ سوم ویـزارد Onboarding: تنظیمات مالی و انبار.
// - فیلدهای تاریخ با DatePicker انتخاب می‌شوند و در provider ذخیره می‌شوند.
// - (اختیاری) اگر shamsi_date را نصب کنی تاریخ انتخاب‌شده به شمسی تبدیل و ذخیره می‌شود.
// - کنترل‌ها همگی با OnboardingProvider همگام شده‌اند.
// کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart'; // اضافه کن: shamsi_date: ^1.1.0 در pubspec
import '../../providers/onboarding_provider.dart';

class Step3FinanceSettings extends StatefulWidget {
  const Step3FinanceSettings({super.key});

  @override
  State<Step3FinanceSettings> createState() => _Step3FinanceSettingsState();
}

class _Step3FinanceSettingsState extends State<Step3FinanceSettings> {
  late TextEditingController _vatCtrl;
  late TextEditingController _fiscalTitleCtrl;

  @override
  void initState() {
    super.initState();
    _vatCtrl = TextEditingController();
    _fiscalTitleCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prov = Provider.of<OnboardingProvider>(context, listen: false);
    _vatCtrl.text = prov.vatRate.toStringAsFixed(2);
    _fiscalTitleCtrl.text = prov.fiscalTitle;
  }

  @override
  void dispose() {
    _vatCtrl.dispose();
    _fiscalTitleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndSaveJalaliDate(BuildContext ctx, bool isStart) async {
    final prov = Provider.of<OnboardingProvider>(ctx, listen: false);
    final initial = DateTime.now();
    final picked = await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    try {
      final j = Jalali.fromDateTime(picked);
      final val =
          '${j.year.toString().padLeft(4, '0')}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
      if (isStart) {
        prov.fiscalStart = val;
      } else {
        prov.fiscalEnd = val;
      }
    } catch (_) {
      final val =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      if (isStart) {
        prov.fiscalStart = val;
      } else {
        prov.fiscalEnd = val;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(builder: (context, prov, _) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Text('تنظیمات مالی و انبار',
                  style: Theme.of(context).textTheme.titleMedium)),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _vatCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'نرخ مالیات (%)',
                          border: OutlineInputBorder()),
                      onChanged: (v) {
                        final parsed =
                            double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
                        prov.vatRate = parsed;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _fiscalTitleCtrl,
                      decoration: const InputDecoration(
                          labelText: 'عنوان دوره مالی',
                          border: OutlineInputBorder()),
                      onChanged: (v) => prov.fiscalTitle = v,
                    ),
                  )
                ]),

                const SizedBox(height: 12),

                // انتخاب تاریخ شروع و پایان (با نمایش مقدار از provider)
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickAndSaveJalaliDate(context, true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'شروع دوره مالی',
                            border: OutlineInputBorder()),
                        child: Text(prov.fiscalStart.isNotEmpty
                            ? prov.fiscalStart
                            : 'انتخاب تاریخ'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickAndSaveJalaliDate(context, false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'پایان دوره مالی',
                            border: OutlineInputBorder()),
                        child: Text(prov.fiscalEnd.isNotEmpty
                            ? prov.fiscalEnd
                            : 'انتخاب تاریخ'),
                      ),
                    ),
                  ),
                ]),

                const SizedBox(height: 12),

                // تنظیمات انبار و ارزیابی
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(children: [
                      SwitchListTile(
                        value: prov.inventoryEnabled,
                        onChanged: (v) => prov.inventoryEnabled = v,
                        title: const Text('فعال‌سازی مدیریت انبار'),
                      ),
                      SwitchListTile(
                        value: prov.inventorySystem,
                        onChanged: (v) => prov.inventorySystem = v,
                        title: const Text('سیستم انبار فعال'),
                      ),
                      Row(children: [
                        const Expanded(flex: 2, child: Text('روش ارزیابی')),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: prov.inventoryValuation,
                            items: const [
                              DropdownMenuItem(
                                  value: 'FIFO', child: Text('FIFO')),
                              DropdownMenuItem(
                                  value: 'LIFO', child: Text('LIFO')),
                              DropdownMenuItem(
                                  value: 'Weighted',
                                  child: Text('Weighted Average')),
                            ],
                            onChanged: (v) {
                              if (v != null) prov.inventoryValuation = v;
                            },
                            decoration: const InputDecoration(
                                border: OutlineInputBorder()),
                          ),
                        ),
                      ]),
                      SwitchListTile(
                        value: prov.multiCurrency,
                        onChanged: (v) => prov.multiCurrency = v,
                        title: const Text('چندارزی'),
                      ),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: prov.currency,
                            items: const [
                              DropdownMenuItem(
                                  value: 'IRR', child: Text('IRR')),
                              DropdownMenuItem(
                                  value: 'USD', child: Text('USD')),
                              DropdownMenuItem(
                                  value: 'EUR', child: Text('EUR')),
                            ],
                            onChanged: (v) {
                              if (v != null) prov.currency = v;
                            },
                            decoration: const InputDecoration(
                                labelText: 'واحد پول',
                                border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: prov.calendar,
                            items: const [
                              DropdownMenuItem(
                                  value: 'gregorian', child: Text('میلادی')),
                              DropdownMenuItem(
                                  value: 'jalali', child: Text('شمسی')),
                            ],
                            onChanged: (v) {
                              if (v != null) prov.calendar = v;
                            },
                            decoration: const InputDecoration(
                                labelText: 'تقویم',
                                border: OutlineInputBorder()),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ),

                const SizedBox(height: 12),

                // دکمه داخلی حذف شد (ناوبری در wizard انجام می‌شود)
              ]),
            ),
          ),
        ],
      );
    });
  }
}
