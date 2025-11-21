// lib/src/pages/settings/restore_db_page.dart
// صفحهٔ گرافیکی برای بازگردانی دیتابیس (Restore).
// - نشان میدهد مسیر فعلی دیتابیس چیست.
// - امکان انتخاب فایل مبدا (با FilePicker) برای بازگردانی دارد.
// - پیش از overwrite فایل فعلی، یک بکاپ خودکار با timestamp ایجاد میکند.
// - پس از بازگردانی، دیتابیس جدید باز (setDbPath) یا از کاربر خواسته میشود اپ را ری‌استارت کند.
// کامنت‌های فارسی مختصر برای هر بخش قرار دارد.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../core/config/config_manager.dart';
import '../../core/db/database.dart';
import '../../core/notifications/notification_service.dart';

class RestoreDbPage extends StatefulWidget {
  const RestoreDbPage({super.key});

  @override
  State<RestoreDbPage> createState() => _RestoreDbPageState();
}

class _RestoreDbPageState extends State<RestoreDbPage> {
  String _currentDbPath = '';
  String _selectedSource = '';
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _loadPaths();
  }

  Future<void> _loadPaths() async {
    setState(() => _loading = true);
    final cfg = await ConfigManager.getDbFilePath();
    final cur = await AppDatabase.getCurrentDbFilePath();
    setState(() {
      _currentDbPath = cfg ?? (cur ?? '');
      _loading = false;
    });
  }

  Future<void> _pickSourceFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite', 'sqlite3'],
      );
      if (result == null || result.files.isEmpty) return;
      final pth = result.files.single.path;
      if (pth == null) return;
      setState(() => _selectedSource = pth);
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'انتخاب فایل انجام نشد: $e');
    }
  }

  String _ts() {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}_${n.hour.toString().padLeft(2, '0')}${n.minute.toString().padLeft(2, '0')}${n.second.toString().padLeft(2, '0')}';
  }

  Future<void> _restore() async {
    if (_selectedSource.isEmpty) {
      NotificationService.showError(context, 'خطا', 'یک فایل مبدا انتخاب کن');
      return;
    }
    if (_currentDbPath.isEmpty) {
      NotificationService.showError(
          context, 'خطا', 'مسیر دیتابیس فعلی مشخص نیست');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تایید بازگردانی'),
          content: const Text(
              'آیا از بازگردانی دیتابیس اطمینان دارید؟ عملیات یک بکاپ خودکار از دیتابیس فعلی می‌سازد.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('لغو')),
            FilledButton.tonal(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('تایید و ادامه')),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _working = true);

    final srcFile = File(_selectedSource);
    final destFile = File(_currentDbPath);

    try {
      // چک فایل مبدا
      if (!await srcFile.exists()) {
        NotificationService.showError(context, 'خطا', 'فایل مبدا یافت نشد');
        setState(() => _working = false);
        return;
      }

      // بکاپ از دیتابیس فعلی (در صورت وجود)
      if (await destFile.exists()) {
        final bakName =
            '${p.basenameWithoutExtension(destFile.path)}.bak.${_ts()}${p.extension(destFile.path)}';
        final bakPath = p.join(destFile.parent.path, bakName);
        await destFile.copy(bakPath);
        NotificationService.showToast(context, 'بکاپ ساخته شد: $bakPath');
      } else {
        // اگر فایل هدف وجود ندارد اطمینان از دایرکتوری
        await destFile.parent.create(recursive: true);
      }

      // کپی فایل مبدا به مسیر هدف (overwrite)
      await srcFile.copy(destFile.path);
      NotificationService.showToast(context, 'بازگردانی انجام شد');

      // سعی در بارگذاری دیتابیس جدید (setDbPath)
      try {
        await AppDatabase.setDbPath(destFile.path);
        NotificationService.showSuccess(
            context, 'موفق', 'دیتابیس بازخوانی و فعال شد', onOk: () {
          // بازخوانی صفحه
          _loadPaths();
        });
      } catch (e) {
        NotificationService.showToast(context, 'دیتابیس بازخوانی نشد: $e',
            backgroundColor: Colors.orange);
        NotificationService.showConfirm(context, 'نیاز به ری‌استارت',
            'برای تضمین تغییر مسیر دیتابیس، اپ را می‌توان ری‌استارت کرد. می‌خواهید الان ری‌استارت شود؟',
            onConfirm: () {
          exit(0);
        },
            onCancel: () {},
            icon: Icons.restart_alt,
            confirmLabel: 'ری‌استارت',
            cancelLabel: 'بعداً');
      }
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'بازگردانی انجام نشد: $e');
    } finally {
      setState(() => _working = false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بازگردانی دیتابیس'),
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
                      const Text('بازگردانی (Restore) دیتابیس',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text('مسیر فعلی فایل دیتابیس:'),
                      const SizedBox(height: 6),
                      SelectableText(
                          _currentDbPath.isNotEmpty
                              ? _currentDbPath
                              : 'مشخص نشده',
                          style: const TextStyle(fontFamily: 'monospace')),
                      const SizedBox(height: 12),
                      const Text(
                          'فایل مبدا (مخزن بکاپ یا فایل mizan_app.db که می‌خواهی بازگردانی شود):'),
                      const SizedBox(height: 6),
                      SelectableText(
                          _selectedSource.isNotEmpty
                              ? _selectedSource
                              : 'فایلی انتخاب نشده',
                          style: const TextStyle(fontFamily: 'monospace')),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilledButton.tonal(
                              onPressed: _pickSourceFile,
                              child: const Text('انتخاب فایل بکاپ...')),
                          const SizedBox(width: 12),
                          Expanded(
                              child: OutlinedButton(
                                  onPressed: _restore,
                                  child: _working
                                      ? const CircularProgressIndicator()
                                      : const Text('بازگردانی و فعال‌سازی'))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                          'توضیح: قبل از بازگردانی، از دیتابیس فعلی بکاپ گرفته می‌شود. اگر دیتابیس جدید بدرستی بارگذاری نشود ممکن است نیاز به ری‌استارت برنامه باشد.',
                          style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
