// lib/src/pages/onboarding/step2_business_details.dart
// مرحلهٔ دوم ویـزارد Onboarding: جزئیات کسب‌وکار.
// - نام فروشگاه در این مرحله قابل ویرایش است.
// - صفحه فقط فرم است؛ ناوبری در onboarding_wizard انجام می‌شود.
// - Dropdownها nullable با placeholder تا assertion مربوط به duplicate value ندهد.
// کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/onboarding_provider.dart';

class Step2BusinessDetails extends StatefulWidget {
  const Step2BusinessDetails({super.key});

  @override
  State<Step2BusinessDetails> createState() => _Step2BusinessDetailsState();
}

class _Step2BusinessDetailsState extends State<Step2BusinessDetails> {
  late TextEditingController _businessNameCtrl;
  late TextEditingController _legalNameCtrl;
  late TextEditingController _activityAreaCtrl;
  late TextEditingController _nationalIdCtrl;
  late TextEditingController _economicCodeCtrl;
  late TextEditingController _registrationNumberCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _faxCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _postalCodeCtrl;

  @override
  void initState() {
    super.initState();
    _businessNameCtrl = TextEditingController();
    _legalNameCtrl = TextEditingController();
    _activityAreaCtrl = TextEditingController();
    _nationalIdCtrl = TextEditingController();
    _economicCodeCtrl = TextEditingController();
    _registrationNumberCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _faxCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _websiteCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _postalCodeCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prov = Provider.of<OnboardingProvider>(context, listen: false);
    _businessNameCtrl.text = prov.businessName;
    _legalNameCtrl.text = prov.legalName;
    _activityAreaCtrl.text = prov.activityArea;
    _nationalIdCtrl.text = prov.nationalId;
    _economicCodeCtrl.text = prov.economicCode;
    _registrationNumberCtrl.text = prov.registrationNumber;
    _phoneCtrl.text = prov.phone;
    _faxCtrl.text = prov.fax;
    _addressCtrl.text = prov.address;
    _websiteCtrl.text = prov.website;
    _emailCtrl.text = prov.email;
    _postalCodeCtrl.text = prov.postalCode;
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _legalNameCtrl.dispose();
    _activityAreaCtrl.dispose();
    _nationalIdCtrl.dispose();
    _economicCodeCtrl.dispose();
    _registrationNumberCtrl.dispose();
    _phoneCtrl.dispose();
    _faxCtrl.dispose();
    _addressCtrl.dispose();
    _websiteCtrl.dispose();
    _emailCtrl.dispose();
    _postalCodeCtrl.dispose();
    super.dispose();
  }

  List<DropdownMenuItem<String?>> _buildStringItems(
      List<String> options, String placeholder) {
    final items = <DropdownMenuItem<String?>>[
      DropdownMenuItem<String?>(value: null, child: Text(placeholder))
    ];
    final seen = <String>{};
    for (final o in options) {
      if (seen.add(o)) {
        items.add(DropdownMenuItem<String?>(value: o, child: Text(o)));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(builder: (context, prov, _) {
      final businessTypes = ['فروشگاهی', 'خدماتی', 'تولیدی', 'تجاری'];
      final countries = ['ایران', 'افغانستان', 'امارات', 'ترکیه'];
      final provinces = ['تهران', 'اصفهان', 'خراسان', 'البرز'];
      final cities = ['تهران', 'مشهد', 'اصفهان', 'کرج'];

      final businessTypeValue =
          prov.businessType.isEmpty ? null : prov.businessType;
      final countryValue = prov.country.isEmpty ? null : prov.country;
      final provinceValue = prov.province.isEmpty ? null : prov.province;
      final cityValue = prov.city.isEmpty ? null : prov.city;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text('اطلاعات کسب‌وکار',
                  style: Theme.of(context).textTheme.titleMedium)),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _businessNameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'نام فروشگاه',
                          border: OutlineInputBorder()),
                      onChanged: (v) => prov.businessName = v,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _legalNameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'نام قانونی',
                          border: OutlineInputBorder()),
                      onChanged: (v) => prov.legalName = v,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _activityAreaCtrl,
                      decoration: const InputDecoration(
                          labelText: 'حوزهٔ فعالیت',
                          border: OutlineInputBorder()),
                      onChanged: (v) => prov.activityArea = v,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _nationalIdCtrl,
                      decoration: const InputDecoration(
                          labelText: 'شناسه ملی', border: OutlineInputBorder()),
                      onChanged: (v) => prov.nationalId = v,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _economicCodeCtrl,
                      decoration: const InputDecoration(
                          labelText: 'کد اقتصادی',
                          border: OutlineInputBorder()),
                      onChanged: (v) => prov.economicCode = v,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _registrationNumberCtrl,
                      decoration: const InputDecoration(
                          labelText: 'شماره ثبت', border: OutlineInputBorder()),
                      onChanged: (v) => prov.registrationNumber = v,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: businessTypeValue,
                      items: _buildStringItems(businessTypes, 'نوع کسب‌وکار'),
                      onChanged: (v) => prov.businessType = v ?? '',
                      decoration:
                          const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: countryValue,
                      items: _buildStringItems(countries, 'کشور'),
                      onChanged: (v) => prov.country = v ?? '',
                      decoration:
                          const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: provinceValue,
                      items: _buildStringItems(provinces, 'استان'),
                      onChanged: (v) => prov.province = v ?? '',
                      decoration:
                          const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: cityValue,
                      items: _buildStringItems(cities, 'شهر'),
                      onChanged: (v) => prov.city = v ?? '',
                      decoration:
                          const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(
                              labelText: 'تلفن', border: OutlineInputBorder()),
                          onChanged: (v) => prov.phone = v)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          controller: _faxCtrl,
                          decoration: const InputDecoration(
                              labelText: 'نمابر (fax)',
                              border: OutlineInputBorder()),
                          onChanged: (v) => prov.fax = v)),
                ]),
                const SizedBox(height: 12),
                TextField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(
                        labelText: 'آدرس', border: OutlineInputBorder()),
                    maxLines: 2,
                    onChanged: (v) => prov.address = v),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: _websiteCtrl,
                          decoration: const InputDecoration(
                              labelText: 'وبسایت',
                              border: OutlineInputBorder()),
                          onChanged: (v) => prov.website = v)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(
                              labelText: 'ایمیل', border: OutlineInputBorder()),
                          onChanged: (v) => prov.email = v)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: _postalCodeCtrl,
                          decoration: const InputDecoration(
                              labelText: 'کد پستی',
                              border: OutlineInputBorder()),
                          onChanged: (v) => prov.postalCode = v)),
                  const SizedBox(width: 12),
                  Expanded(child: Container()),
                ]),
              ]),
            ),
          ),
        ],
      );
    });
  }
}
