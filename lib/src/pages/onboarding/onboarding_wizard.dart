// lib/src/pages/onboarding/onboarding_wizard.dart
// ویـزارد onboarding: مدیریت سه مرحله (اطلاعات اولیه، جزئیات کسب‌وکار، تنظیمات مالی)
// - ناوبری (ادامه/بازگشت/ذخیره) فقط در این فایل انجام میشود.
// - ارجاع‌ها و importها اصلاح شده‌اند تا خطای path نداشته باشیم.
// - از OnboardingProvider برای state و اعتبارسنجی استفاده می‌شود.
// کامنت فارسی مختصر در هر بخش قرار دارد.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/onboarding_provider.dart';
import 'step1_business_info.dart';
import 'step2_business_details.dart';
import 'step3_finance_settings.dart';
import '../../core/navigation/app_navigator.dart';

class OnboardingWizard extends StatefulWidget {
  const OnboardingWizard({super.key});

  @override
  State<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<OnboardingWizard> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // اعتبارسنجی مرحلهٔ 2: نام فروشگاه باید پر شده باشد
  bool _validateStep2(OnboardingProvider prov) {
    final name = prov.businessName.trim();
    if (name.isEmpty) {
      prov.setError('نام فروشگاه خالی است. لطفاً نام فروشگاه را وارد کنید.');
      return false;
    }
    prov.clearError();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(builder: (context, prov, _) {
      final int step = prov.step;
      Widget content;
      switch (step) {
        case 1:
          content = const Step1BusinessInfo();
          break;
        case 2:
          content = const Step2BusinessDetails();
          break;
        default:
          content = const Step3FinanceSettings();
      }

      return Scaffold(
        appBar: AppBar(title: const Text('راه‌اندازی اولیه')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                // نوار مرحلهٔ ساده
                Row(children: [Expanded(child: StepIndicator(current: step))]),
                const SizedBox(height: 12),

                // نمایش پیام خطا (اگر موجود باشد)
                if (prov.error != null && prov.error!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(prov.error!,
                                    style: const TextStyle(color: Colors.red))),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 6),

                // محتوای مرحله
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollCtrl,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: content,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // دکمه‌های پایانی: بازگشت / ادامه یا ذخیره
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: prov.loading || step == 1
                          ? null
                          : () {
                              prov.back();
                              _scrollCtrl.animateTo(0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut);
                            },
                      child: const Text('بازگشت'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: prov.loading
                            ? null
                            : () async {
                                if (step == 1) {
                                  final ok = prov.applyStep1();
                                  if (ok) {
                                    prov.next();
                                    prov.clearError();
                                    _scrollCtrl.animateTo(0,
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content:
                                                Text(prov.error ?? 'خطا')));
                                  }
                                } else if (step == 2) {
                                  if (!_validateStep2(prov)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content:
                                                Text(prov.error ?? 'خطا')));
                                    return;
                                  }
                                  prov.next();
                                  prov.clearError();
                                  _scrollCtrl.animateTo(0,
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut);
                                } else {
                                  final ok = await prov.saveProfile();
                                  if (ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'پروفایل با موفقیت ذخیره شد')));
                                    AppNavigator.pushReplacementNamed('/login');
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content:
                                                Text(prov.error ?? 'خطا')));
                                  }
                                }
                              },
                        child: prov.loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Text(step < 3 ? 'ادامه' : 'ذخیره و پایان'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class StepIndicator extends StatelessWidget {
  final int current;
  const StepIndicator({super.key, required this.current});

  Widget _buildItem(
      int index, String title, BuildContext context, bool active) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: active
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            child: Text('$index',
                style: TextStyle(color: active ? Colors.white : Colors.black)),
          ),
          const SizedBox(height: 6),
          Text(title,
              style:
                  TextStyle(fontSize: 12, color: active ? null : Colors.grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildItem(1, 'اطلاعات اولیه', context, current == 1),
        _buildItem(2, 'جزئیات کسب‌وکار', context, current == 2),
        _buildItem(3, 'تنظیمات مالی', context, current == 3),
      ],
    );
  }
}
