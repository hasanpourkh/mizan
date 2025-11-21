// lib/src/pages/settings/app_settings_page.dart
// صفحهٔ تنظیمات برنامه — نسخهٔ کامل‌شده با فیلدهای جدید برای "قالب تولید کد خدمات"
// - فیلدهای اضافه شده:
//    service_code_prefix, service_code_start, service_code_counter
// - این فایل تمام امکانات قبلی (مسیر ذخیره، مسیر دیتابیس، بارکد seed/counter، شماره فاکتور) را حفظ کرده
// - کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../core/config/config_manager.dart';
import '../../core/db/database.dart';
import '../../core/notifications/notification_service.dart';
import 'package:path_provider/path_provider.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  final TextEditingController _storageCtrl = TextEditingController();
  final TextEditingController _dbCtrl = TextEditingController();

  // تنظیمات بارکد فروشگاهی
  final TextEditingController _barcodeSeedCtrl = TextEditingController();
  final TextEditingController _barcodeCounterCtrl = TextEditingController();

  // تنظیمات شماره فاکتور
  final TextEditingController _invoicePrefixCtrl =
      TextEditingController(text: 'INV');
  final TextEditingController _invoiceStartCtrl =
      TextEditingController(text: '1000');
  final TextEditingController _invoiceCounterCtrl = TextEditingController();
  final TextEditingController _invoiceTitleCtrl = TextEditingController();

  // تنظیمات کد خدمات (جدید)
  final TextEditingController _servicePrefixCtrl =
      TextEditingController(text: 'SVC');
  final TextEditingController _serviceStartCtrl =
      TextEditingController(text: '1000');
  final TextEditingController _serviceCounterCtrl = TextEditingController();

  bool _loading = true;
  String? _initialDbPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cfgStorage = await ConfigManager.getStoragePath();
    final cfgDb = await ConfigManager.getDbFilePath();

    String? bpStorage;
    try {
      final bp = await AppDatabase.getBusinessProfile();
      bpStorage = bp?['storage_path']?.toString();
    } catch (_) {
      bpStorage = null;
    }

    final storage = cfgStorage ?? bpStorage ?? '';
    _storageCtrl.text = storage;

    final dbp = cfgDb ?? '';
    _dbCtrl.text = dbp;
    _initialDbPath = dbp;

    // load barcode settings (from config)
    final seed = await ConfigManager.get('barcode_store_seed') ?? '';
    final counter = await ConfigManager.get('barcode_store_counter') ?? '1';
    _barcodeSeedCtrl.text = seed;
    _barcodeCounterCtrl.text = counter;

    // load invoice settings
    final invPrefix = await ConfigManager.get('invoice_prefix') ?? 'INV';
    final invStart = await ConfigManager.get('invoice_start') ?? '1000';
    final invCounter = await ConfigManager.get('invoice_counter') ?? '';
    final invTitle = await ConfigManager.get('invoice_title') ?? '';
    _invoicePrefixCtrl.text = invPrefix;
    _invoiceStartCtrl.text = invStart;
    _invoiceCounterCtrl.text = invCounter;
    _invoiceTitleCtrl.text = invTitle;

    // load service code settings (new)
    final svcPrefix = await ConfigManager.get('service_code_prefix') ?? 'SVC';
    final svcStart = await ConfigManager.get('service_code_start') ?? '1000';
    final svcCounter = await ConfigManager.get('service_code_counter') ?? '';
    _servicePrefixCtrl.text = svcPrefix;
    _serviceStartCtrl.text = svcStart;
    _serviceCounterCtrl.text = svcCounter;

    setState(() => _loading = false);
  }

  Future<void> _pickStorageFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result == null) return;
      _storageCtrl.text = result;
      setState(() {});
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'انتخاب پوشه انجام نشد: $e');
    }
  }

  Future<void> _pickDbFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result == null) return;
      final dbFull = p.join(result, 'mizan_app.db');
      _dbCtrl.text = dbFull;
      setState(() {});
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'انتخاب پوشه دیتابیس انجام نشد: $e');
    }
  }

  Future<void> _setDefaultToDocuments() async {
    final doc = await getApplicationDocumentsDirectory();
    final defaultPath = p.join(doc.path, 'mizan_assets');
    _storageCtrl.text = defaultPath;
    setState(() {});
  }

  Future<void> _setDrivePath(String driveLetter) async {
    final candidate = '$driveLetter:\\Mizan';
    _storageCtrl.text = candidate;
    setState(() {});
  }

  // ذخیرهٔ تنظیمات (شامل تنظیمات service code جدید)
  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final storagePath = _storageCtrl.text.trim();
      final dbPath = _dbCtrl.text.trim();
      final barcodeSeed = _barcodeSeedCtrl.text.trim();
      final barcodeCounter = _barcodeCounterCtrl.text.trim();

      final invoicePrefix = _invoicePrefixCtrl.text.trim();
      final invoiceStart = _invoiceStartCtrl.text.trim();
      final invoiceCounter = _invoiceCounterCtrl.text.trim();
      final invoiceTitle = _invoiceTitleCtrl.text.trim();

      // service code settings
      final servicePrefix = _servicePrefixCtrl.text.trim();
      final serviceStart = _serviceStartCtrl.text.trim();
      final serviceCounter = _serviceCounterCtrl.text.trim();

      final cfg = <String, dynamic>{};
      if (storagePath.isNotEmpty) cfg['storage_path'] = storagePath;
      if (dbPath.isNotEmpty) cfg['db_path'] = dbPath;
      if (barcodeSeed.isNotEmpty) cfg['barcode_store_seed'] = barcodeSeed;
      if (barcodeCounter.isNotEmpty) {
        cfg['barcode_store_counter'] = barcodeCounter;
      }

      // invoice settings
      if (invoicePrefix.isNotEmpty) cfg['invoice_prefix'] = invoicePrefix;
      if (invoiceStart.isNotEmpty) cfg['invoice_start'] = invoiceStart;
      if (invoiceCounter.isNotEmpty) cfg['invoice_counter'] = invoiceCounter;
      if (invoiceTitle.isNotEmpty) cfg['invoice_title'] = invoiceTitle;

      // service code settings (new)
      if (servicePrefix.isNotEmpty) cfg['service_code_prefix'] = servicePrefix;
      if (serviceStart.isNotEmpty) cfg['service_code_start'] = serviceStart;
      if (serviceCounter.isNotEmpty)
        cfg['service_code_counter'] = serviceCounter;

      await ConfigManager.saveConfig(cfg);

      // اگر storage_path را داریم آن را در business_profile هم نمایش دهیم (سازگاری)
      try {
        final bp = await AppDatabase.getBusinessProfile() ?? {};
        bp['storage_path'] = storagePath;
        bp['created_at'] = DateTime.now().millisecondsSinceEpoch;
        await AppDatabase.saveBusinessProfile(bp);
      } catch (_) {}

      if (dbPath.isNotEmpty && dbPath != _initialDbPath) {
        final destFile = File(dbPath);
        final destExists = await destFile.exists();

        if (!destExists) {
          try {
            final current = await AppDatabase.getCurrentDbFilePath();
            if (current != null && current.isNotEmpty) {
              final curFile = File(current);
              if (await curFile.exists()) {
                await destFile.parent.create(recursive: true);
                await curFile.copy(dbPath);
                NotificationService.showToast(
                    context, 'دیتابیس فعلی به مسیر جدید کپی شد');
              } else {
                NotificationService.showToast(context,
                    'فایل دیتابیس فعلی یافت نشد؛ دیتابیس جدید خالی خواهد بود',
                    backgroundColor: Colors.orange);
              }
            }
          } catch (e) {
            NotificationService.showToast(context, 'کپی دیتابیس انجام نشد: $e',
                backgroundColor: Colors.red);
          }
        }

        final restartNow = await showDialog<bool>(
          context: context,
          builder: (c) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Row(children: [
                Icon(Icons.storage, color: Colors.blue),
                SizedBox(width: 8),
                Text('تغییر مسیر دیتابیس')
              ]),
              content: const Text(
                  'مسیر دیتابیس تغییر کرده است. برای اعمال تغییرات کامل میتوانید برنامه را ریاستارت کنید یا همینجا دیتابیس جدید باز شود. (پیشنهاد: ریاستارت برای تضمین سازگاری)'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(c).pop(false),
                    child: const Text('باز کردن همینجا')),
                FilledButton.tonal(
                    onPressed: () => Navigator.of(c).pop(true),
                    child: const Text('ریاستارت حالا')),
              ],
            ),
          ),
        );

        if (restartNow == true) {
          await ConfigManager.saveConfig(cfg);
          NotificationService.showToast(
              context, 'برنامه در حال بسته شدن برای ریاستارت...');
          await Future.delayed(const Duration(milliseconds: 600));
          exit(0);
        } else {
          try {
            await AppDatabase.setDbPath(dbPath);
            _initialDbPath = dbPath;
            NotificationService.showToast(context, 'دیتابیس جدید بارگذاری شد');
            NotificationService.showSuccess(
                context, 'ذخیره شد', 'تنظیمات برنامه ذخیره شد');
          } catch (e) {
            NotificationService.showError(
                context, 'خطا', 'بارگذاری دیتابیس جدید موفق نبود: $e');
          }
        }
      } else {
        NotificationService.showSuccess(
            context, 'ذخیره شد', 'تنظیمات برنامه ذخیره شد');
      }
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'ذخیره تنظیمات انجام نشد: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _storageCtrl.dispose();
    _dbCtrl.dispose();
    _barcodeSeedCtrl.dispose();
    _barcodeCounterCtrl.dispose();
    _invoicePrefixCtrl.dispose();
    _invoiceStartCtrl.dispose();
    _invoiceCounterCtrl.dispose();
    _invoiceTitleCtrl.dispose();
    _servicePrefixCtrl.dispose();
    _serviceStartCtrl.dispose();
    _serviceCounterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات برنامه'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ListView(
                    children: [
                      const Text('تنظیمات عمومی برنامه',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _storageCtrl,
                          decoration: const InputDecoration(
                              labelText: 'مسیر ذخیره فایلها (تصاویر)',
                              border: OutlineInputBorder())),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: [
                        FilledButton.tonal(
                            onPressed: _setDefaultToDocuments,
                            child: const Text('پیشفرض (اسناد برنامه)')),
                        FilledButton.tonal(
                            onPressed: () => _setDrivePath('C'),
                            child: const Text('C:\\Mizan')),
                        FilledButton.tonal(
                            onPressed: () => _setDrivePath('D'),
                            child: const Text('D:\\Mizan')),
                        FilledButton.tonal(
                            onPressed: _pickStorageFolder,
                            child: const Text('انتخاب پوشه...')),
                      ]),
                      const Divider(height: 28),
                      TextField(
                          controller: _dbCtrl,
                          decoration: const InputDecoration(
                              labelText:
                                  'مسیر فایل دیتابیس (full path) — فایل mizan_app.db',
                              border: OutlineInputBorder())),
                      const SizedBox(height: 8),
                      Row(children: [
                        FilledButton.tonal(
                            onPressed: _pickDbFolder,
                            child: const Text('انتخاب پوشه برای دیتابیس')),
                        const SizedBox(width: 12),
                        Expanded(
                            child: OutlinedButton(
                                onPressed: _save,
                                child: const Text('ذخیره تنظیمات'))),
                      ]),
                      const Divider(height: 28),
                      const Text('تنظیمات بارکد فروشگاهی',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                          controller: _barcodeSeedCtrl,
                          decoration: const InputDecoration(
                              labelText:
                                  'متن پایه بارکد (seed) — مثلاً 2000 یا PROD-',
                              border: OutlineInputBorder())),
                      const SizedBox(height: 8),
                      TextField(
                          controller: _barcodeCounterCtrl,
                          decoration: const InputDecoration(
                              labelText: 'مقدار شروع کانتر (عدد صحیح)',
                              border: OutlineInputBorder()),
                          keyboardType: TextInputType.number),
                      const SizedBox(height: 12),
                      const Divider(height: 28),
                      const Text('تنظیمات شماره فاکتور',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: _invoicePrefixCtrl,
                                decoration: const InputDecoration(
                                    labelText:
                                        'پیشوند فاکتور (مثلاً INV یا FV-)',
                                    border: OutlineInputBorder()))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: TextField(
                                controller: _invoiceStartCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'عدد شروع (مثلاً 1000)',
                                    border: OutlineInputBorder()),
                                keyboardType: TextInputType.number)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: _invoiceCounterCtrl,
                                decoration: const InputDecoration(
                                    labelText:
                                        'کانتر فعلی (خالی بگذارید تا از عدد شروع استفاده شود)',
                                    border: OutlineInputBorder()),
                                keyboardType: TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: TextField(
                                controller: _invoiceTitleCtrl,
                                decoration: const InputDecoration(
                                    labelText:
                                        'عنوان پیشفرض فاکتور (مثلاً "فروش نقدی")',
                                    border: OutlineInputBorder()))),
                      ]),
                      const SizedBox(height: 12),

                      // بخش جدید: تنظیمات کد خدمات
                      const Divider(height: 28),
                      const Text('تنظیمات تولید کد خدمات',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: _servicePrefixCtrl,
                                decoration: const InputDecoration(
                                    labelText:
                                        'پیشوند کد خدمت (مثلاً SVC یا S-)',
                                    border: OutlineInputBorder()))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: TextField(
                                controller: _serviceStartCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'عدد شروع (مثلاً 1000)',
                                    border: OutlineInputBorder()),
                                keyboardType: TextInputType.number)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: _serviceCounterCtrl,
                                decoration: const InputDecoration(
                                    labelText:
                                        'کانتر فعلی (خالی بگذارید تا از عدد شروع استفاده شود)',
                                    border: OutlineInputBorder()),
                                keyboardType: TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () {
                                  // بازنشانی کانتر نمونه
                                  setState(() {
                                    _serviceCounterCtrl.text = '';
                                  });
                                },
                                child: const Text('پاکسازی کانتر'))),
                      ]),
                      const SizedBox(height: 12),
                      const Text(
                          'توضیح: کد خدمات بر اساس ترکیب پیشوند + کانتر ساخته می‌شود. کانتر پس از هر ذخیرهٔ خدمت افزایش می‌یابد.',
                          style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                            child: FilledButton.tonal(
                                onPressed: _save,
                                child: const Text('ذخیره تنظیمات'))),
                        const SizedBox(width: 12),
                        OutlinedButton(
                            onPressed: _load,
                            child: const Text('بارگذاری مجدد')),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
