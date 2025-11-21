// lib/src/pages/onboarding/step1_business_info.dart
// مرحلهٔ 1 ویـزارد: نام کسب‌وکار و زبان پیش‌فرض
// - مقدار واردشده در این صفحه در مرحلهٔ بعد به‌صورت خودکار پر میشود.
// کامنت فارسی مختصر

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/onboarding_provider.dart';

class Step1BusinessInfo extends StatefulWidget {
  const Step1BusinessInfo({super.key});

  @override
  State<Step1BusinessInfo> createState() => _Step1BusinessInfoState();
}

class _Step1BusinessInfoState extends State<Step1BusinessInfo> {
  late TextEditingController _nameCtrl;
  String _lang = 'فارسی';

  @override
  void initState() {
    super.initState();
    final prov = Provider.of<OnboardingProvider>(context, listen: false);
    _nameCtrl = TextEditingController(text: prov.businessNameStep1);
    _lang = prov.language;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<OnboardingProvider>(context);
    return ListView(
      children: [
        const Text('مرحله اول - معرفی کسب‌وکار',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'نام کسب و کار',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            prov.businessNameStep1 = v;
          },
        ),
        const SizedBox(height: 12),
        const Text('زبان پیش‌فرض کسب‌وکار', style: TextStyle(fontSize: 15)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('فارسی'),
                value: 'فارسی',
                groupValue: _lang,
                onChanged: (v) {
                  setState(() => _lang = v ?? 'فارسی');
                  prov.language = _lang;
                },
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('English'),
                value: 'English',
                groupValue: _lang,
                onChanged: (v) {
                  setState(() => _lang = v ?? 'English');
                  prov.language = _lang;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'نام قانونی به‌صورت خودکار در مرحلهٔ بعد بر اساس نام کسب‌وکار پر می‌شود (قابل ویرایش).',
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}
