// lib/src/pages/settings/print_settings_page.dart
// صفحهٔ تنظیمات چاپ — به‌روزرسانی برای:
// - اضافه کردن فیلد "نام نمایش شبکه" برای ردیف‌هایی که پلتفرم == 'other' (یا در صورت نیاز قابل ویرایش)
// - social_links همچنان به صورت JSON ذخیره می‌شود اما اکنون شامل 'display_name' خواهد بود
// - بارگذاری و نمایش مقدار display_name در فرم
// - کامنت‌های فارسی مختصر برای هر بخش
//
// توجه: این فایل با ساختار فعلی پروژه سازگار است و فقط رفتار تنظیمات چاپ را گسترش می‌دهد.

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';

class _SocialField {
  String platform;
  final TextEditingController ctrl; // آیدی / آدرس
  final TextEditingController displayCtrl; // نام نمایش (برای other یا سفارشی)
  String? iconPath;
  _SocialField(
      {required this.platform, String initial = '', String display = ''})
      : ctrl = TextEditingController(text: initial),
        displayCtrl = TextEditingController(text: display);

  Map<String, dynamic> toMap() {
    return {
      'platform': platform,
      'display_name': displayCtrl.text.trim(),
      'handle': ctrl.text.trim(),
      'icon_path': iconPath ?? '',
    };
  }

  void dispose() {
    ctrl.dispose();
    displayCtrl.dispose();
  }
}

class PrintSettingsPage extends StatefulWidget {
  const PrintSettingsPage({super.key});

  @override
  State<PrintSettingsPage> createState() => _PrintSettingsPageState();
}

class _PrintSettingsPageState extends State<PrintSettingsPage> {
  // فرم اصلی
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _websiteCtrl = TextEditingController();
  final TextEditingController _adTextCtrl =
      TextEditingController(); // متن تبلیغاتی

  // چهار شماره
  final TextEditingController _shopPhoneCtrl = TextEditingController();
  final TextEditingController _mobile1Ctrl = TextEditingController();
  final TextEditingController _mobile2Ctrl = TextEditingController();
  final TextEditingController _otherPhoneCtrl = TextEditingController();

  // لوگو
  String? _logoPath;

  // پیشفرض سایز برگه
  String _paperSize = 'A4';

  // social links: 10 ردیف
  final List<_SocialField> _socials = List.generate(
      10, (_) => _SocialField(platform: 'instagram', initial: '', display: ''));

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bp = await AppDatabase.getBusinessProfile();
      if (bp != null) {
        _nameCtrl.text = bp['business_name']?.toString() ?? '';
        _addressCtrl.text = bp['address']?.toString() ?? '';
        _websiteCtrl.text = bp['website']?.toString() ?? '';
        _adTextCtrl.text = bp['print_ad_text']?.toString() ?? '';
        _logoPath = (bp['logo_path']?.toString() ?? bp['logo']?.toString());
        _paperSize = bp['default_paper']?.toString() ?? _paperSize;

        // phone
        final phoneRaw = bp['phone']?.toString() ?? '';
        if (phoneRaw.isNotEmpty) {
          final parts = phoneRaw.split(RegExp(r'\s*\|\s*|;|,|/|\s{2,}|\s'));
          if (parts.isNotEmpty) {
            _shopPhoneCtrl.text = parts.isNotEmpty ? parts[0] : '';
          }
          if (parts.length > 1) _mobile1Ctrl.text = parts[1];
          if (parts.length > 2) _mobile2Ctrl.text = parts[2];
          if (parts.length > 3) _otherPhoneCtrl.text = parts[3];
        }

        // social_links: ممکن است JSON string یا لیست باشد
        final slRaw = bp['social_links'];
        try {
          List decoded = [];
          if (slRaw == null) {
            decoded = [];
          } else if (slRaw is String && slRaw.isNotEmpty) {
            final d = json.decode(slRaw);
            if (d is List) {
              decoded = d;
            } else if (d is Map) decoded = [d];
          } else if (slRaw is List) decoded = slRaw;
          if (decoded.isNotEmpty) {
            for (var i = 0; i < decoded.length && i < _socials.length; i++) {
              final e = decoded[i];
              if (e is Map) {
                _socials[i].platform =
                    (e['platform']?.toString() ?? _socials[i].platform);
                _socials[i].ctrl.text = e['handle']?.toString() ?? '';
                _socials[i].displayCtrl.text =
                    e['display_name']?.toString() ?? '';
                final ip = e['icon_path']?.toString() ?? '';
                _socials[i].iconPath = ip.isNotEmpty ? ip : null;
              }
            }
          }
        } catch (_) {
          // ignore parse error
        }
      }
    } catch (e) {
      NotificationService.showToast(context, 'بارگذاری انجام نشد: $e',
          backgroundColor: Colors.orange);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickLogo() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.image);
      if (res == null || res.files.isEmpty) return;
      final p = res.files.single.path;
      if (p == null) return;
      setState(() => _logoPath = p);
      NotificationService.showToast(context, 'لوگو انتخاب شد');
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'انتخاب لوگو انجام نشد: $e');
    }
  }

  Future<void> _pickSocialIcon(int idx) async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.image);
      if (res == null || res.files.isEmpty) return;
      final p = res.files.single.path;
      if (p == null) return;
      setState(() => _socials[idx].iconPath = p);
      NotificationService.showToast(context, 'آیکون انتخاب شد');
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'انتخاب آیکون انجام نشد: $e');
    }
  }

  void _removeSocialIcon(int idx) {
    setState(() => _socials[idx].iconPath = null);
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final name = _nameCtrl.text.trim();
      final address = _addressCtrl.text.trim();
      final website = _websiteCtrl.text.trim();
      final adText = _adTextCtrl.text.trim();

      final phones = <String>[];
      if (_shopPhoneCtrl.text.trim().isNotEmpty) {
        phones.add(_shopPhoneCtrl.text.trim());
      }
      if (_mobile1Ctrl.text.trim().isNotEmpty) {
        phones.add(_mobile1Ctrl.text.trim());
      }
      if (_mobile2Ctrl.text.trim().isNotEmpty) {
        phones.add(_mobile2Ctrl.text.trim());
      }
      if (_otherPhoneCtrl.text.trim().isNotEmpty) {
        phones.add(_otherPhoneCtrl.text.trim());
      }

      // social_links: فقط ردیف‌هایی که handle پر دارند ذخیره می‌شوند
      final socialMaps = <Map<String, dynamic>>[];
      for (final s in _socials) {
        final handle = s.ctrl.text.trim();
        if (handle.isNotEmpty) {
          socialMaps.add(s.toMap());
        }
      }

      final data = <String, dynamic>{
        'business_name': name,
        'address': address,
        'website': website,
        'logo_path': _logoPath ?? '',
        'phone': phones.join(' | '),
        'default_paper': _paperSize,
        'social_links': json.encode(socialMaps),
        'print_ad_text': adText,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

      await AppDatabase.saveBusinessProfile(data);

      NotificationService.showSuccess(
          context, 'ذخیره شد', 'تنظیمات چاپ ذخیره شد');
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'ذخیره انجام نشد: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DropdownMenuItem<String>> _platformItems() {
    const opts = [
      ['instagram', 'اینستاگرام'],
      ['telegram', 'تلگرام'],
      ['whatsapp', 'واتساپ'],
      ['facebook', 'فیسبوک'],
      ['twitter', 'توییتر'],
      ['linkedin', 'لینکداین'],
      ['aparat', 'آپارات'],
      ['youtube', 'یوتیوب'],
      ['tiktok', 'تیک‌تاک'],
      ['other', 'سایر (نام دلخواه)'],
    ];
    return opts
        .map((o) => DropdownMenuItem(value: o[0], child: Text(o[1])))
        .toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _websiteCtrl.dispose();
    _adTextCtrl.dispose();
    _shopPhoneCtrl.dispose();
    _mobile1Ctrl.dispose();
    _mobile2Ctrl.dispose();
    _otherPhoneCtrl.dispose();
    for (final s in _socials) {
      s.dispose();
    }
    super.dispose();
  }

  Widget _buildSocialRow(int idx) {
    final s = _socials[idx];
    return Padding(
      key: ValueKey('social_row_$idx'),
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: DropdownButtonFormField<String>(
              initialValue: s.platform,
              items: _platformItems(),
              onChanged: (v) => setState(() => s.platform = v ?? 'other'),
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  labelText: 'پلتفرم'),
            ),
          ),
          const SizedBox(width: 8),
          // اگر پلتفرم 'other' است فیلد نام نمایش را نشان بده تا فارسی/دلخواه وارد شود
          if (s.platform == 'other')
            SizedBox(
              width: 140,
              child: TextField(
                controller: s.displayCtrl,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    labelText: 'نام شبکه (فارسی)'),
              ),
            )
          else
            const SizedBox(width: 0, height: 0),
          if (s.platform == 'other') const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: s.ctrl,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  labelText: 'آیدی / آدرس'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'انتخاب آیکون',
            onPressed: () => _pickSocialIcon(idx),
            icon: s.iconPath != null && s.iconPath!.isNotEmpty
                ? CircleAvatar(
                    radius: 18, backgroundImage: FileImage(File(s.iconPath!)))
                : const Icon(Icons.image, size: 28),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'حذف آیکون',
            icon: const Icon(Icons.clear, color: Colors.red),
            onPressed: () => _removeSocialIcon(idx),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات چاپ'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text('اطلاعات سربرگ فاکتور',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  TextField(
                                      controller: _nameCtrl,
                                      decoration: const InputDecoration(
                                          labelText: 'نام فروشگاه',
                                          border: OutlineInputBorder())),
                                  const SizedBox(height: 8),
                                  TextField(
                                      controller: _addressCtrl,
                                      decoration: const InputDecoration(
                                          labelText: 'آدرس',
                                          border: OutlineInputBorder()),
                                      maxLines: 2),
                                  const SizedBox(height: 8),
                                  TextField(
                                      controller: _websiteCtrl,
                                      decoration: const InputDecoration(
                                          labelText: 'وبسایت (اختیاری)',
                                          border: OutlineInputBorder())),
                                  const SizedBox(height: 8),
                                  TextField(
                                      controller: _adTextCtrl,
                                      decoration: const InputDecoration(
                                          labelText:
                                              'متن تبلیغاتی (برای سربرگ چاپ)',
                                          border: OutlineInputBorder()),
                                      maxLines: 3),
                                  const SizedBox(height: 12),
                                  Row(children: [
                                    if (_logoPath != null &&
                                        _logoPath!.isNotEmpty)
                                      CircleAvatar(
                                          radius: 36,
                                          backgroundImage:
                                              FileImage(File(_logoPath!)))
                                    else
                                      const CircleAvatar(
                                          radius: 36, child: Icon(Icons.store)),
                                    const SizedBox(width: 12),
                                    FilledButton.tonal(
                                        onPressed: _pickLogo,
                                        child: const Text('انتخاب لوگو')),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                        onPressed: () =>
                                            setState(() => _logoPath = null),
                                        child: const Text('حذف لوگو')),
                                  ]),
                                ]),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // شماره‌ها
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text('شماره‌ها',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  TextField(
                                      controller: _shopPhoneCtrl,
                                      decoration: const InputDecoration(
                                          labelText: 'شماره فروشگاه',
                                          border: OutlineInputBorder()),
                                      keyboardType: TextInputType.phone),
                                  const SizedBox(height: 8),
                                  TextField(
                                      controller: _mobile1Ctrl,
                                      decoration: const InputDecoration(
                                          labelText: 'موبایل 1',
                                          border: OutlineInputBorder()),
                                      keyboardType: TextInputType.phone),
                                  const SizedBox(height: 8),
                                  TextField(
                                      controller: _mobile2Ctrl,
                                      decoration: const InputDecoration(
                                          labelText: 'موبایل 2',
                                          border: OutlineInputBorder()),
                                      keyboardType: TextInputType.phone),
                                  const SizedBox(height: 8),
                                  TextField(
                                      controller: _otherPhoneCtrl,
                                      decoration: const InputDecoration(
                                          labelText: 'شماره اضافی',
                                          border: OutlineInputBorder()),
                                      keyboardType: TextInputType.phone),
                                  const SizedBox(height: 8),
                                  const Text(
                                      'تذکر: تنها شماره‌هایی که مقدار دارند در سربرگ/فاکتور نمایش داده می‌شوند.',
                                      style: TextStyle(
                                          color: Colors.black54, fontSize: 12)),
                                ]),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // social links
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                      'شبکه‌های اجتماعی (حداکثر 10 لینک برای چاپ)',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  const Text(
                                      'برای هر ردیف: پلتفرم، نام (برای سایر پلتفرم‌ها) و آیدی/آدرس و آیکون را انتخاب کن. تنها ردیف‌های پرشده چاپ خواهند شد.',
                                      style: TextStyle(
                                          color: Colors.black54, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  ...List.generate(_socials.length,
                                      (i) => _buildSocialRow(i)),
                                  const SizedBox(height: 8),
                                ]),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // پیشفرض سایز برگه و دکمه‌ها
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text('پیش‌فرض چاپ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Expanded(
                                        child: RadioListTile<String>(
                                            value: 'A4',
                                            groupValue: _paperSize,
                                            title: const Text('A4'),
                                            onChanged: (v) => setState(
                                                () => _paperSize = v ?? 'A4'))),
                                    Expanded(
                                        child: RadioListTile<String>(
                                            value: 'A5',
                                            groupValue: _paperSize,
                                            title: const Text('A5'),
                                            onChanged: (v) => setState(
                                                () => _paperSize = v ?? 'A5'))),
                                  ]),
                                ]),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Row(children: [
                          Expanded(
                              child: FilledButton.tonal(
                                  onPressed: _save,
                                  child: const Text('ذخیره تنظیمات'))),
                          const SizedBox(width: 8),
                          OutlinedButton(
                              onPressed: _load,
                              child: const Text('بارگذاری مجدد')),
                        ]),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
