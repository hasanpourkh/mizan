// lib/src/pages/services/new_service_page.dart
// صفحهٔ افزودن / ویرایش خدمت
// - فیلدها: تصویر، عنوان، کد خدمات (خودکار)، بارکدها (جداشده با ;)، دکمه انتخاب دسته‌بندی (popup)
// - تب‌ها: فروش (قیمت فروش، توضیحات فروش، قیمت خرید، توضیحات خرید)
//           عمومی (واحد اصلی، عدد، توضیحات)
//           مالیات (تیک مشمول مالیات فروش: پیشفرض فعال، مالیات فروش/خرید و ...)
// - اصلاح مهم: حذف Directionality اضافی در دیالوگ‌ها تا خطای 'rtl' رفع شود.
// - کامنت‌های فارسی مختصر برای هر بخش قرار گرفته‌اند.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/config/config_manager.dart';
import 'package:intl/intl.dart';

class NewServicePage extends StatefulWidget {
  final Map<String, dynamic>? editing;
  const NewServicePage({super.key, this.editing});

  @override
  State<NewServicePage> createState() => _NewServicePageState();
}

class _NewServicePageState extends State<NewServicePage>
    with SingleTickerProviderStateMixin {
  // کنترلرها و state فرم
  final _titleCtrl = TextEditingController();
  final _serviceCodeCtrl = TextEditingController();
  final _accountCodeCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _salePriceCtrl = TextEditingController(text: '0');
  final _saleDescCtrl = TextEditingController();
  final _purchasePriceCtrl = TextEditingController(text: '0');
  final _purchaseDescCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _unitNumberCtrl = TextEditingController(text: '1');
  final _generalDescCtrl = TextEditingController();

  final _taxSaleCtrl = TextEditingController(text: '9');
  final _taxPurchaseCtrl = TextEditingController(text: '9');
  final _taxTypeCtrl = TextEditingController(text: '12- سایر کالا ها');
  final _taxCodeCtrl = TextEditingController();
  final _taxUnitCtrl = TextEditingController();

  String? _localImagePath;
  int? _selectedCategoryId;
  String? _selectedCategoryName;

  bool _loading = true;
  bool _saving = false;

  // مالیات تیکها (پیشفرض فعال)
  bool _taxableSale = true;
  bool _taxablePurchase = true;

  // TabController برای تبها
  late final TabController _tabController;

  // برای نمایش کد خودکار
  bool _accountAuto = true;
  bool _codeAuto = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initForm();
  }

  Future<void> _initForm() async {
    setState(() => _loading = true);
    try {
      // اگر در حالت ویرایش هستیم مقادیر را پر کن
      final editing = widget.editing;
      if (editing != null) {
        _titleCtrl.text = editing['name']?.toString() ?? '';
        _serviceCodeCtrl.text = editing['code']?.toString() ?? '';
        _accountCodeCtrl.text = editing['account_code']?.toString() ?? '';
        _barcodeCtrl.text = editing['barcode']?.toString() ?? '';
        _salePriceCtrl.text = (editing['price']?.toString() ?? '0');
        _saleDescCtrl.text = editing['sale_description']?.toString() ?? '';
        _purchasePriceCtrl.text =
            (editing['purchase_price']?.toString() ?? '0');
        _purchaseDescCtrl.text =
            editing['purchase_description']?.toString() ?? '';
        _unitCtrl.text = editing['unit']?.toString() ?? '';
        _unitNumberCtrl.text = (editing['unit_number']?.toString() ?? '1');
        _generalDescCtrl.text = editing['description']?.toString() ?? '';
        _taxableSale = editing['taxable_sale'] == 0 ? false : true;
        _taxablePurchase = editing['taxable_purchase'] == 0 ? false : true;
        _taxSaleCtrl.text = editing['tax_sale']?.toString() ?? '9';
        _taxPurchaseCtrl.text = editing['tax_purchase']?.toString() ?? '9';
        _taxTypeCtrl.text =
            editing['tax_type']?.toString() ?? '12- سایر کالا ها';
        _taxCodeCtrl.text = editing['tax_code']?.toString() ?? '';
        _taxUnitCtrl.text = editing['tax_unit']?.toString() ?? '';
        _localImagePath = editing['image_path']?.toString();
        final cid = editing['category_id'];
        _selectedCategoryId = (cid is int)
            ? cid
            : (cid != null ? int.tryParse(cid.toString()) : null);
        _selectedCategoryName = editing['category_name']?.toString();
        _codeAuto = _serviceCodeCtrl.text.trim().isEmpty;
        _accountAuto = _accountCodeCtrl.text.trim().isEmpty;
      } else {
        // تولید پیش‌فرض کد حساب و کد خدمت
        await _generateServiceCodePreview();
        await _generateAccountCodePreview();
      }
    } catch (e) {
      NotificationService.showToast(context, 'بارگذاری فرم انجام نشد: $e',
          backgroundColor: Colors.orange);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // تولید preview برای کد خدمت با استفاده از ConfigManager
  Future<void> _generateServiceCodePreview() async {
    try {
      final prefix = await ConfigManager.get('service_code_prefix') ?? 'SVC';
      final startStr = await ConfigManager.get('service_code_start') ?? '1000';
      final counterStr = await ConfigManager.get('service_code_counter');
      int counter;
      if (counterStr == null || counterStr.trim().isEmpty) {
        counter = int.tryParse(startStr) ??
            DateTime.now().millisecondsSinceEpoch % 100000;
      } else {
        counter = int.tryParse(counterStr) ??
            int.tryParse(startStr) ??
            DateTime.now().millisecondsSinceEpoch % 100000;
      }
      final code = '$prefix$counter';
      if (!mounted) return;
      setState(() {
        if (_codeAuto) _serviceCodeCtrl.text = code;
      });
    } catch (_) {}
  }

  // تولید preview برای کد حساب (ساده) — از AppDatabase.getNextAccountCode استفاده میشود
  Future<void> _generateAccountCodePreview() async {
    try {
      final acc = await AppDatabase.getNextAccountCode();
      if (!mounted) return;
      setState(() {
        if (_accountAuto) _accountCodeCtrl.text = acc;
      });
    } catch (_) {}
  }

  // انتخاب تصویر با FilePicker و کپی به پوشه برنامه
  Future<void> _pickAndSaveImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty) return;
      final src = result.files.single.path;
      if (src == null) return;

      String storagePath;
      try {
        final bp = await AppDatabase.getBusinessProfile();
        storagePath = bp?['storage_path']?.toString() ?? '';
      } catch (_) {
        storagePath = '';
      }
      if (storagePath.isEmpty) {
        final doc = await getApplicationDocumentsDirectory();
        storagePath = p.join(doc.path, 'mizan_assets');
      }
      final destDir = Directory(p.join(storagePath, 'pictures_db', 'services'));
      if (!await destDir.exists()) await destDir.create(recursive: true);
      final ext = p.extension(src);
      final fileName = 'service_${DateTime.now().millisecondsSinceEpoch}$ext';
      final destPath = p.join(destDir.path, fileName);
      await File(src).copy(destPath);
      if (!mounted) return;
      setState(() {
        _localImagePath = destPath;
      });
      NotificationService.showToast(context, 'تصویر ذخیره شد');
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'انتخاب تصویر انجام نشد: $e');
    }
  }

  // باز کردن popup انتخاب دسته‌بندی و انتخاب یک دسته (خواندن از AppDatabase)
  Future<void> _chooseCategoryPopup() async {
    try {
      final cats = await AppDatabase.getProductCategories();
      if (!mounted) return;
      final selected = await showDialog<int?>(
        context: context,
        builder: (c) {
          // توجه: Directionality حذف شد (باعث خطای rtl می‌شد)
          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 480, maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Expanded(
                            child: Text('انتخاب دسته‌بندی',
                                style: TextStyle(fontWeight: FontWeight.w700))),
                        IconButton(
                            onPressed: () => Navigator.of(c).pop(null),
                            icon: const Icon(Icons.close))
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: cats.isEmpty
                        ? const Center(
                            child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text('هیچ دسته‌ای تعریف نشده است')))
                        : ListView.separated(
                            itemCount: cats.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final it = cats[idx];
                              final id = (it['id'] is int)
                                  ? it['id'] as int
                                  : int.tryParse(it['id']?.toString() ?? '') ??
                                      0;
                              final name = it['name']?.toString() ?? '';
                              return ListTile(
                                title: Text(name),
                                onTap: () => Navigator.of(c).pop(id),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () => Navigator.of(c).pop(null),
                                child: const Text('انصراف'))),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                            onPressed: () => Navigator.of(c).pop(0),
                            child: const Text('بدون دسته')),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      );

      if (selected != null) {
        if (selected == 0) {
          setState(() {
            _selectedCategoryId = null;
            _selectedCategoryName = 'بدون دسته';
          });
        } else {
          final found = cats.firstWhere((c) {
            final id = (c['id'] is int)
                ? c['id'] as int
                : int.tryParse(c['id']?.toString() ?? '') ?? 0;
            return id == selected;
          }, orElse: () => {});
          setState(() {
            _selectedCategoryId = selected;
            _selectedCategoryName = found.isNotEmpty
                ? (found['name']?.toString() ?? '#$selected')
                : '#$selected';
          });
        }
      }
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'بارگذاری دسته‌ها انجام نشد: $e');
    }
  }

  // هنگام ذخیره، ابتدا کد خدمت را قطعی کن (در صورت حالت خودکار) و کانتر را افزایش بده
  Future<String> _finalizeAndIncrementServiceCode() async {
    try {
      final prefix = await ConfigManager.get('service_code_prefix') ?? 'SVC';
      final startStr = await ConfigManager.get('service_code_start') ?? '1000';
      final counterStr = await ConfigManager.get('service_code_counter');
      int counter;
      if (counterStr == null || counterStr.trim().isEmpty) {
        counter = int.tryParse(startStr) ??
            DateTime.now().millisecondsSinceEpoch % 100000;
      } else {
        counter = int.tryParse(counterStr) ??
            int.tryParse(startStr) ??
            DateTime.now().millisecondsSinceEpoch % 100000;
      }
      final code = '$prefix$counter';
      // سپس افزایش و ذخیره کانتر
      final next = counter + 1;
      await ConfigManager.saveConfig({'service_code_counter': next.toString()});
      return code;
    } catch (_) {
      // fallback
      final fallback = 'SVC${DateTime.now().millisecondsSinceEpoch % 100000}';
      return fallback;
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      NotificationService.showError(context, 'خطا', 'عنوان خدمت را وارد کنید');
      return;
    }

    setState(() => _saving = true);

    try {
      String serviceCode = _serviceCodeCtrl.text.trim();
      if (serviceCode.isEmpty || _codeAuto) {
        serviceCode = await _finalizeAndIncrementServiceCode();
      }

      String accountCode = _accountCodeCtrl.text.trim();
      if (accountCode.isEmpty && _accountAuto) {
        try {
          accountCode = await AppDatabase.getNextAccountCode();
        } catch (_) {
          accountCode = 'A${DateTime.now().millisecondsSinceEpoch % 100000}';
        }
      }

      final barcodes = _barcodeCtrl.text.trim();

      final item = <String, dynamic>{
        'name': title,
        'code': serviceCode,
        'account_code': accountCode,
        'barcode': barcodes,
        'category_id': _selectedCategoryId,
        'category_name': _selectedCategoryName,
        'image_path': _localImagePath ?? '',
        'price':
            double.tryParse(_salePriceCtrl.text.replaceAll(',', '.')) ?? 0.0,
        'sale_description': _saleDescCtrl.text.trim(),
        'purchase_price':
            double.tryParse(_purchasePriceCtrl.text.replaceAll(',', '.')) ??
                0.0,
        'purchase_description': _purchaseDescCtrl.text.trim(),
        'unit': _unitCtrl.text.trim(),
        'unit_number':
            double.tryParse(_unitNumberCtrl.text.replaceAll(',', '.')) ?? 1.0,
        'description': _generalDescCtrl.text.trim(),
        'taxable_sale': _taxableSale ? 1 : 0,
        'tax_sale':
            double.tryParse(_taxSaleCtrl.text.replaceAll(',', '.')) ?? 0.0,
        'taxable_purchase': _taxablePurchase ? 1 : 0,
        'tax_purchase':
            double.tryParse(_taxPurchaseCtrl.text.replaceAll(',', '.')) ?? 0.0,
        'tax_type': _taxTypeCtrl.text.trim(),
        'tax_code': _taxCodeCtrl.text.trim(),
        'tax_unit': _taxUnitCtrl.text.trim(),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

      // اگر در حالت ویرایش، id را به item اضافه کن
      if (widget.editing != null && widget.editing!['id'] != null) {
        item['id'] = widget.editing!['id'];
      }

      final id = await AppDatabase.saveService(item);
      NotificationService.showSuccess(
          context, 'ذخیره شد', 'خدمت با موفقیت ذخیره شد', onOk: () {
        Navigator.of(context).pushReplacementNamed('/services/list');
      });
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'ذخیره انجام نشد: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _serviceCodeCtrl.dispose();
    _accountCodeCtrl.dispose();
    _barcodeCtrl.dispose();
    _salePriceCtrl.dispose();
    _saleDescCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _purchaseDescCtrl.dispose();
    _unitCtrl.dispose();
    _unitNumberCtrl.dispose();
    _generalDescCtrl.dispose();
    _taxSaleCtrl.dispose();
    _taxPurchaseCtrl.dispose();
    _taxTypeCtrl.dispose();
    _taxCodeCtrl.dispose();
    _taxUnitCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing == null ? 'افزودن خدمت' : 'ویرایش خدمت'),
        actions: [
          IconButton(
              tooltip: 'بارگذاری مجدد پیش‌نمایش کد',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _generateServiceCodePreview();
                _generateAccountCodePreview();
              })
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.save),
        label: Text('ذخیره'),
        onPressed: _saving ? null : _save,
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
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(children: [
                            Row(children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundImage: (_localImagePath != null &&
                                        _localImagePath!.isNotEmpty)
                                    ? FileImage(File(_localImagePath!))
                                    : null,
                                child: (_localImagePath == null)
                                    ? const Icon(Icons.image, size: 32)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _titleCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'عنوان خدمت',
                                      border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(children: [
                                SizedBox(
                                  width: 120,
                                  child: FilledButton.tonal(
                                      onPressed: _pickAndSaveImage,
                                      child: const Text('انتخاب تصویر')),
                                ),
                              ]),
                            ]),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                  child: TextField(
                                controller: _serviceCodeCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'کد خدمات',
                                    border: OutlineInputBorder()),
                                enabled: !_codeAuto,
                              )),
                              const SizedBox(width: 8),
                              Column(children: [
                                const Text('خودکار'),
                                Switch(
                                    value: _codeAuto,
                                    onChanged: (v) async {
                                      setState(() => _codeAuto = v);
                                      if (v)
                                        await _generateServiceCodePreview();
                                    })
                              ]),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: TextField(
                                controller: _accountCodeCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'کد حسابداری',
                                    border: OutlineInputBorder()),
                                enabled: !_accountAuto,
                              )),
                              const SizedBox(width: 8),
                              Column(children: [
                                const Text('خودکار'),
                                Switch(
                                    value: _accountAuto,
                                    onChanged: (v) async {
                                      setState(() => _accountAuto = v);
                                      if (v)
                                        await _generateAccountCodePreview();
                                    })
                              ]),
                            ]),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                  child: TextField(
                                controller: _barcodeCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'بارکدها (با ; جدا کنید)',
                                    border: OutlineInputBorder()),
                              )),
                              const SizedBox(width: 8),
                              SizedBox(
                                  width: 160,
                                  child: FilledButton.tonal(
                                      onPressed: _chooseCategoryPopup,
                                      child: Text(_selectedCategoryName ??
                                          'انتخاب دسته‌بندی'))),
                            ]),
                          ]),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // تبها: فروش / عمومی / مالیات
                      Card(
                        child: Column(children: [
                          TabBar(
                            controller: _tabController,
                            labelColor: Theme.of(context).colorScheme.onPrimary,
                            indicatorColor:
                                Theme.of(context).colorScheme.primary,
                            tabs: const [
                              Tab(text: 'فروش'),
                              Tab(text: 'عمومی'),
                              Tab(text: 'مالیات'),
                            ],
                          ),
                          SizedBox(
                            height: 360,
                            child: TabBarView(
                                controller: _tabController,
                                children: [
                                  // Tab فروش
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(children: [
                                            Expanded(
                                                child: TextField(
                                              controller: _salePriceCtrl,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                              decoration: const InputDecoration(
                                                  labelText: 'قیمت فروش (ریال)',
                                                  border: OutlineInputBorder()),
                                            )),
                                            const SizedBox(width: 8),
                                            Expanded(
                                                child: TextField(
                                              controller: _saleDescCtrl,
                                              decoration: const InputDecoration(
                                                  labelText: 'توضیحات فروش',
                                                  border: OutlineInputBorder()),
                                            )),
                                          ]),
                                          const SizedBox(height: 12),
                                          Row(children: [
                                            Expanded(
                                                child: TextField(
                                              controller: _purchasePriceCtrl,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                              decoration: const InputDecoration(
                                                  labelText: 'قیمت خرید (ریال)',
                                                  border: OutlineInputBorder()),
                                            )),
                                            const SizedBox(width: 8),
                                            Expanded(
                                                child: TextField(
                                              controller: _purchaseDescCtrl,
                                              decoration: const InputDecoration(
                                                  labelText: 'توضیحات خرید',
                                                  border: OutlineInputBorder()),
                                            )),
                                          ]),
                                          const SizedBox(height: 12),
                                          const Text(
                                              'نکته: قیمت‌ها به ریال وارد شوند.'),
                                        ]),
                                  ),

                                  // Tab عمومی
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(children: [
                                            Expanded(
                                                child: TextField(
                                              controller: _unitCtrl,
                                              decoration: const InputDecoration(
                                                  labelText: 'واحد اصلی',
                                                  border: OutlineInputBorder()),
                                            )),
                                            const SizedBox(width: 8),
                                            Expanded(
                                                child: TextField(
                                              controller: _unitNumberCtrl,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                              decoration: const InputDecoration(
                                                  labelText: 'عدد',
                                                  border: OutlineInputBorder()),
                                            )),
                                          ]),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller: _generalDescCtrl,
                                            maxLines: 4,
                                            decoration: const InputDecoration(
                                                labelText: 'توضیحات عمومی',
                                                border: OutlineInputBorder()),
                                          ),
                                        ]),
                                  ),

                                  // Tab مالیات
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: SingleChildScrollView(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Row(children: [
                                              Expanded(
                                                  child: CheckboxListTile(
                                                title: const Text(
                                                    'مشمول مالیات فروش'),
                                                value: _taxableSale,
                                                onChanged: (v) {
                                                  if (v == null) return;
                                                  setState(() {
                                                    _taxableSale = v;
                                                  });
                                                },
                                              )),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                  child: TextField(
                                                controller: _taxSaleCtrl,
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: true),
                                                decoration: const InputDecoration(
                                                    labelText:
                                                        'مالیات فروش (%)',
                                                    border:
                                                        OutlineInputBorder()),
                                                enabled: _taxableSale,
                                              )),
                                            ]),
                                            const SizedBox(height: 8),
                                            Row(children: [
                                              Expanded(
                                                  child: CheckboxListTile(
                                                title: const Text(
                                                    'مشمول مالیات خرید'),
                                                value: _taxablePurchase,
                                                onChanged: (v) {
                                                  if (v == null) return;
                                                  setState(() {
                                                    _taxablePurchase = v;
                                                  });
                                                },
                                              )),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                  child: TextField(
                                                controller: _taxPurchaseCtrl,
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: true),
                                                decoration: const InputDecoration(
                                                    labelText:
                                                        'مالیات خرید (%)',
                                                    border:
                                                        OutlineInputBorder()),
                                                enabled: _taxablePurchase,
                                              )),
                                            ]),
                                            const SizedBox(height: 12),
                                            TextField(
                                              controller: _taxTypeCtrl,
                                              decoration: const InputDecoration(
                                                  labelText: 'نوع مالیات',
                                                  border: OutlineInputBorder()),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(children: [
                                              Expanded(
                                                  child: TextField(
                                                      controller: _taxCodeCtrl,
                                                      decoration:
                                                          const InputDecoration(
                                                              labelText:
                                                                  'کد مالیاتی',
                                                              border:
                                                                  OutlineInputBorder()))),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                  child: TextField(
                                                      controller: _taxUnitCtrl,
                                                      decoration:
                                                          const InputDecoration(
                                                              labelText:
                                                                  'واحد مالیاتی',
                                                              border:
                                                                  OutlineInputBorder()))),
                                            ]),
                                          ]),
                                    ),
                                  ),
                                ]),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 16),

                      // دکمه های ذخیره / انصراف
                      Row(children: [
                        Expanded(
                            child: FilledButton.tonal(
                                onPressed: _saving ? null : _save,
                                child: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Text('ذخیره'))),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 40,
                          child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('انصراف')),
                        ),
                      ]),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
