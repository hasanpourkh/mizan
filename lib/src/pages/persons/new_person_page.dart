// lib/src/pages/persons/new_person_page.dart
// صفحهٔ "شخص جدید" — فرم کامل افزودن شخص با تولید خودکار کد حسابداری و ذخیره در AppDatabase.
// اصلاحات: سوئیچ "فروشنده" اضافه شد و هنگام ذخیره مقدار type_seller ارسال می‌شود.
// کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';
import 'persons_styles.dart';
import '../../core/utils/jalali_utils.dart';

class NewPersonPage extends StatefulWidget {
  const NewPersonPage({super.key});

  @override
  State<NewPersonPage> createState() => _NewPersonPageState();
}

class _NewPersonPageState extends State<NewPersonPage> {
  // کنترلرهای فرم
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _displayCtrl = TextEditingController();
  final _nationalCtrl = TextEditingController();
  final _economicCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _avatarUrlCtrl = TextEditingController();
  final _birthCtrl = TextEditingController();
  final _membershipCtrl = TextEditingController();
  final _creditCtrl = TextEditingController(text: '0');
  final _balanceCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _sharePercentCtrl = TextEditingController(text: '0');

  String? _localAvatarPath;
  bool _loading = false;

  // account code
  bool _accountAuto = true;

  // دستهبندیها
  List<Map<String, dynamic>> _categories = [];
  int _selectedCategoryId = 0;

  // نوع شخص: سوئیچها
  bool _isCustomer = false;
  bool _isSupplier = false;
  bool _isShareholder = false;
  bool _isEmployee = false;
  bool _isSeller = false; // اضافه شد: فروشنده

  @override
  void initState() {
    super.initState();
    _loadCategoriesIfAny();
    if (_accountAuto) _fillNextAccountCode();
  }

  Future<void> _loadCategoriesIfAny() async {
    try {
      final cats = await AppDatabase.getPersonCategories();
      if (!mounted) return;
      setState(() => _categories = cats);
    } catch (_) {
      // ignore
    }
  }

  // گرفتن کد حساب بعدی از DB و نمایش در فیلد (فقط preview، مقدار نهایی هنگام ذخیره تولید میشود)
  Future<void> _fillNextAccountCode() async {
    try {
      final next = await AppDatabase.getNextAccountCode();
      if (!mounted) return;
      setState(() => _accountCtrl.text = next);
    } catch (_) {}
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _displayCtrl.dispose();
    _nationalCtrl.dispose();
    _economicCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _countryCtrl.dispose();
    _postalCtrl.dispose();
    _avatarUrlCtrl.dispose();
    _birthCtrl.dispose();
    _membershipCtrl.dispose();
    _creditCtrl.dispose();
    _balanceCtrl.dispose();
    _notesCtrl.dispose();
    _accountCtrl.dispose();
    _sharePercentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndSaveAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.single.path;
      if (filePath == null) return;

      String storagePath;
      try {
        final appDoc = await getApplicationSupportDirectory();
        storagePath = p.join(appDoc.path, 'mizan_assets');
      } catch (_) {
        final doc = await getApplicationDocumentsDirectory();
        storagePath = p.join(doc.path, 'mizan_assets');
      }

      final destDir = Directory(storagePath);
      if (!await destDir.exists()) await destDir.create(recursive: true);

      final ext = p.extension(filePath);
      final fileName = 'person_${DateTime.now().millisecondsSinceEpoch}$ext';
      final destPath = p.join(destDir.path, fileName);
      await File(filePath).copy(destPath);

      if (!mounted) return;
      setState(() {
        _localAvatarPath = destPath;
        _avatarUrlCtrl.text = destPath;
      });

      NotificationService.showToast(context, 'تصویر با موفقیت ذخیره شد');
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'انتخاب یا ذخیره تصویر با خطا مواجه شد: $e');
    }
  }

  Future<void> _pickJalali(TextEditingController ctrl) async {
    try {
      final picked = await pickJalaliDate(context, initialJalali: ctrl.text);
      if (picked != null && mounted) setState(() => ctrl.text = picked);
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'انتخاب تاریخ انجام نشد: $e');
    }
  }

  Future<void> _onToggleShareholder(bool value) async {
    if (!value) {
      if (!mounted) return;
      setState(() => _isShareholder = false);
      return;
    }
    try {
      final total = await AppDatabase.getTotalSharePercentage();
      if (total >= 100.0) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (c) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('امکان افزودن سهامدار وجود ندارد'),
              content: const Text(
                  'مجموع درصد سهام فعلی >= 100% است. ابتدا درصد یک سهامدار را کاهش دهید.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(c).pop(),
                    child: const Text('باشه'))
              ],
            ),
          ),
        );
        return;
      } else {
        final remain = (100.0 - total).clamp(0.0, 100.0);
        if (!mounted) return;
        setState(() {
          _isShareholder = true;
          _sharePercentCtrl.text = remain.toStringAsFixed(2);
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isShareholder = true);
    }
  }

  Future<void> _save() async {
    if (_firstCtrl.text.trim().isEmpty && _displayCtrl.text.trim().isEmpty) {
      NotificationService.showError(
          context, 'خطا', 'نام یا نام نمایشی را وارد کنید');
      return;
    }

    double sharePercent = 0.0;
    if (_isShareholder) {
      final pText = _sharePercentCtrl.text.trim();
      final parsed = double.tryParse(pText.replaceAll(',', '.'));
      if (parsed == null || parsed <= 0.0) {
        NotificationService.showError(
            context, 'خطا', 'درصد سهام معتبر وارد کنید');
        return;
      }
      if (parsed > 100.0) {
        NotificationService.showError(
            context, 'خطا', 'درصد سهام نمیتواند بیشتر از 100 باشد');
        return;
      }
      final canAdd = await AppDatabase.canAddShareholder(parsed);
      if (!canAdd) {
        final total = await AppDatabase.getTotalSharePercentage();
        final remain = (100.0 - total).clamp(0.0, 100.0);
        NotificationService.showError(context, 'خطا',
            'مجموع درصد سهام با این مقدار از 100 بیشتر میشود. مقدار قابل اضافه: ${remain.toStringAsFixed(2)}%');
        return;
      }
      sharePercent = parsed;
    }

    setState(() => _loading = true);

    // اگر خودکار است، موقع ذخیره مقدار قطعی تولید کن
    if (_accountAuto) {
      try {
        final next = await AppDatabase.getNextAccountCode();
        _accountCtrl.text = next;
      } catch (_) {}
    }

    final data = {
      'first_name': _firstCtrl.text.trim(),
      'last_name': _lastCtrl.text.trim(),
      'display_name': _displayCtrl.text.trim().isNotEmpty
          ? _displayCtrl.text.trim()
          : ('${_firstCtrl.text.trim()} ${_lastCtrl.text.trim()}').trim(),
      'national_id': _nationalCtrl.text.trim(),
      'economic_code': _economicCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'province': _provinceCtrl.text.trim(),
      'country': _countryCtrl.text.trim(),
      'postal_code': _postalCtrl.text.trim(),
      'avatar_url': _avatarUrlCtrl.text.trim(),
      'avatar_local_path': _localAvatarPath ?? _avatarUrlCtrl.text.trim(),
      'birth_date': _birthCtrl.text.trim(),
      'membership_date': _membershipCtrl.text.trim(),
      'account_code': _accountCtrl.text.trim(),
      'category_id': _selectedCategoryId == 0 ? null : _selectedCategoryId,
      'credit_limit': double.tryParse(_creditCtrl.text.trim()) ?? 0.0,
      'balance': double.tryParse(_balanceCtrl.text.trim()) ?? 0.0,
      'notes': _notesCtrl.text.trim(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      final id = await AppDatabase.savePerson(data);

      final types = {
        'type_customer': _isCustomer ? 1 : 0,
        'type_supplier': _isSupplier ? 1 : 0,
        'type_shareholder': _isShareholder ? 1 : 0,
        'type_employee': _isEmployee ? 1 : 0,
        'type_seller': _isSeller ? 1 : 0, // اضافه شد
        'shareholder_percentage': _isShareholder ? sharePercent : 0.0,
      };
      try {
        await AppDatabase.updatePersonTypes(id, types);
      } catch (_) {}

      if (!mounted) return;
      NotificationService.showSuccess(
          context, 'ذخیره شد', 'شخص با موفقیت ذخیره شد', onOk: () {
        Navigator.of(context).pushReplacementNamed('/persons/list');
      });
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'ذخیره انجام نشد: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Widget _categoryDropdown(BuildContext ctx) {
    final items = <DropdownMenuItem<int>>[
      const DropdownMenuItem(value: 0, child: Text('بدون دسته')),
      ..._categories.map((c) {
        final id = c['id'] is int
            ? c['id'] as int
            : int.tryParse(c['id']?.toString() ?? '0') ?? 0;
        final name = c['name']?.toString() ?? '';
        return DropdownMenuItem(value: id, child: Text(name));
      }).toList()
    ];
    return DropdownButtonFormField<int>(
      initialValue: _selectedCategoryId,
      decoration:
          PersonFormStyle.inputDecoration(ctx, label: 'دستهبندی (اشخاص)'),
      items: items,
      onChanged: (v) {
        if (!mounted) return;
        setState(() => _selectedCategoryId = v ?? 0);
      },
    );
  }

  Widget _styledField({
    required TextEditingController controller,
    required String label,
    IconData? prefix,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
  }) {
    final field = TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      style: PersonFormStyle.textStyle(),
      decoration: PersonFormStyle.inputDecoration(context,
          label: label, prefix: prefix),
    );
    return PersonFormStyle.sizedField(context, field);
  }

  Widget _typesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('نوع شخص', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            SizedBox(
              width: 220,
              child: SwitchListTile(
                title: const Text('مشتری'),
                value: _isCustomer,
                onChanged: (v) {
                  if (!mounted) return;
                  setState(() => _isCustomer = v);
                },
                contentPadding: EdgeInsets.zero,
              ),
            ),
            SizedBox(
              width: 220,
              child: SwitchListTile(
                title: const Text('تأمینکننده'),
                value: _isSupplier,
                onChanged: (v) {
                  if (!mounted) return;
                  setState(() => _isSupplier = v);
                },
                contentPadding: EdgeInsets.zero,
              ),
            ),
            SizedBox(
              width: 220,
              child: SwitchListTile(
                title: const Text('فروشنده'),
                value: _isSeller,
                onChanged: (v) {
                  if (!mounted) return;
                  setState(() => _isSeller = v);
                },
                contentPadding: EdgeInsets.zero,
              ),
            ),
            SizedBox(
              width: 220,
              child: SwitchListTile(
                title: const Text('سهامدار'),
                value: _isShareholder,
                onChanged: (v) => _onToggleShareholder(v),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            SizedBox(
              width: 220,
              child: SwitchListTile(
                title: const Text('کارمند'),
                value: _isEmployee,
                onChanged: (v) {
                  if (!mounted) return;
                  setState(() => _isEmployee = v);
                },
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ]),
          if (_isShareholder) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sharePercentCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: PersonFormStyle.inputDecoration(context,
                        label: 'درصد سهام (مثلاً 12.5)'),
                    style: PersonFormStyle.textStyle(),
                  ),
                ),
                const SizedBox(width: 12),
                PersonFormStyle.buttonSized(
                  child: FilledButton.tonal(
                      onPressed: () async {
                        try {
                          final total =
                              await AppDatabase.getTotalSharePercentage();
                          final remain = (100.0 - total).clamp(0.0, 100.0);
                          NotificationService.showToast(context,
                              'مجموع فعلی: ${total.toStringAsFixed(2)}%. باقیمانده: ${remain.toStringAsFixed(2)}%');
                        } catch (_) {
                          NotificationService.showToast(
                              context, 'خطا در دریافت وضعیت سهام');
                        }
                      },
                      child: const Text('نمایش وضعیت سهام',
                          style:
                              TextStyle(fontSize: PersonFormStyle.fontSize))),
                )
              ],
            )
          ]
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('شخص جدید')),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: PersonFormStyle.maxFormWidth),
          child: Padding(
            padding: const EdgeInsets.all(PersonFormStyle.horizontalPadding),
            child: LayoutBuilder(builder: (context, constraints) {
              final maxW = constraints.maxWidth;
              int columns = 3;
              if (maxW < 900) columns = 2;
              if (maxW < 600) columns = 1;
              const gap = PersonFormStyle.columnGap;
              final fieldWidth = (maxW - (columns - 1) * gap - 32) / columns;

              Widget colWrap(List<Widget> children) {
                return Wrap(
                  spacing: gap,
                  runSpacing: 8,
                  children: children
                      .map((w) => SizedBox(width: fieldWidth, child: w))
                      .toList(),
                );
              }

              const avatarRadius = PersonFormStyle.avatarRadius;
              final avatarWidget = CircleAvatar(
                radius: avatarRadius,
                backgroundImage:
                    (_localAvatarPath != null && _localAvatarPath!.isNotEmpty)
                        ? FileImage(File(_localAvatarPath!))
                        : (_avatarUrlCtrl.text.isNotEmpty
                            ? NetworkImage(_avatarUrlCtrl.text)
                            : null) as ImageProvider?,
                child: (_localAvatarPath == null && _avatarUrlCtrl.text.isEmpty)
                    ? Icon(Icons.person, size: avatarRadius)
                    : null,
              );

              return ListView(
                children: [
                  const Text('فرم افزودن شخص/مشتری',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: PersonFormStyle.sectionSpacing),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(children: [
                        Row(
                          children: [
                            avatarWidget,
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _avatarUrlCtrl,
                                decoration: PersonFormStyle.inputDecoration(
                                    context,
                                    label: 'آدرس تصویر (URL یا مسیر محلی)'),
                                onChanged: (_) {
                                  if (!mounted) return;
                                  setState(() {});
                                },
                                style: PersonFormStyle.textStyle(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 110,
                              child: PersonFormStyle.buttonSized(
                                child: FilledButton.tonal(
                                    onPressed: _pickAndSaveAvatar,
                                    child: const Text('انتخاب تصویر',
                                        style: TextStyle(
                                            fontSize:
                                                PersonFormStyle.fontSize))),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _accountCtrl,
                                decoration: PersonFormStyle.inputDecoration(
                                    context,
                                    label: 'کد حسابداری'),
                                enabled: !_accountAuto,
                                style: PersonFormStyle.textStyle(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              children: [
                                const Text('خودکار',
                                    style: TextStyle(
                                        fontSize: PersonFormStyle.fontSize)),
                                Switch(
                                    value: _accountAuto,
                                    onChanged: (v) async {
                                      if (!mounted) return;
                                      setState(() => _accountAuto = v);
                                      if (v) await _fillNextAccountCode();
                                    }),
                              ],
                            )
                          ],
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: PersonFormStyle.sectionSpacing),
                  colWrap([
                    _styledField(controller: _firstCtrl, label: 'نام'),
                    _styledField(controller: _lastCtrl, label: 'نام خانوادگی'),
                    _styledField(
                        controller: _displayCtrl,
                        label: 'نام نمایشی (نمایش در فهرست)'),
                    _styledField(
                        controller: _nationalCtrl,
                        label: 'شناسه ملی',
                        keyboardType: TextInputType.number),
                    _styledField(
                        controller: _economicCtrl,
                        label: 'کد اقتصادی',
                        keyboardType: TextInputType.number),
                    _styledField(
                        controller: _phoneCtrl,
                        label: 'تلفن',
                        keyboardType: TextInputType.phone),
                    _styledField(
                        controller: _emailCtrl,
                        label: 'ایمیل',
                        keyboardType: TextInputType.emailAddress),
                    _styledField(controller: _addressCtrl, label: 'آدرس'),
                    _styledField(controller: _cityCtrl, label: 'شهر'),
                    _styledField(controller: _provinceCtrl, label: 'استان'),
                    _styledField(controller: _countryCtrl, label: 'کشور'),
                    _styledField(
                        controller: _postalCtrl,
                        label: 'کد پستی',
                        keyboardType: TextInputType.number),
                  ]),
                  const SizedBox(height: PersonFormStyle.sectionSpacing),
                  colWrap([
                    _styledField(
                        controller: _creditCtrl,
                        label: 'حد اعتبار (مبلغ)',
                        keyboardType: TextInputType.number),
                    _styledField(
                        controller: _balanceCtrl,
                        label: 'مانده حساب',
                        keyboardType: TextInputType.number),
                  ]),
                  const SizedBox(height: PersonFormStyle.sectionSpacing),
                  Row(children: [
                    Expanded(
                        child: GestureDetector(
                            onTap: () => _pickJalali(_birthCtrl),
                            child: AbsorbPointer(
                                child: _styledField(
                                    controller: _birthCtrl,
                                    label: 'تاریخ تولد (شمسی)')))),
                    const SizedBox(width: PersonFormStyle.columnGap),
                    Expanded(
                        child: GestureDetector(
                            onTap: () => _pickJalali(_membershipCtrl),
                            child: AbsorbPointer(
                                child: _styledField(
                                    controller: _membershipCtrl,
                                    label: 'تاریخ عضویت (شمسی)')))),
                  ]),
                  const SizedBox(height: PersonFormStyle.sectionSpacing),
                  _categoryDropdown(context),
                  const SizedBox(height: PersonFormStyle.sectionSpacing),
                  _typesSection(),
                  const SizedBox(height: PersonFormStyle.sectionSpacing),
                  TextField(
                      controller: _notesCtrl,
                      maxLines: 4,
                      style: PersonFormStyle.textStyle(),
                      decoration: PersonFormStyle.inputDecoration(context,
                          label: 'یادداشت')),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: PersonFormStyle.buttonSized(
                          child: FilledButton.tonal(
                              onPressed: _loading ? null : _save,
                              child: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Text('ذخیره شخص',
                                      style: TextStyle(
                                          fontSize: PersonFormStyle.fontSize))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: PersonFormStyle.buttonHeight,
                        child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('انصراف',
                                style: TextStyle(
                                    fontSize: PersonFormStyle.fontSize))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
