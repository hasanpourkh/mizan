// lib/src/pages/settings/business_settings_page.dart
// صفحهٔ تنظیمات اطلاعات فروشگاه (نام، آدرس، تلفن، لوگو) — ذخیره در AppDatabase
// - این صفحه در routes برنامه با کلید '/settings/business' آماده است.
// - هنگام ذخیره از AppDatabase.saveBusinessProfile استفاده میشود.
// - لوگو با FilePicker انتخاب شده و مسیر آن در رکورد ذخیره می‌شود.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';

class BusinessSettingsPage extends StatefulWidget {
  const BusinessSettingsPage({super.key});

  @override
  State<BusinessSettingsPage> createState() => _BusinessSettingsPageState();
}

class _BusinessSettingsPageState extends State<BusinessSettingsPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  String? _logoPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final bp = await AppDatabase.getBusinessProfile();
      if (bp != null) {
        _nameCtrl.text = bp['business_name']?.toString() ?? '';
        _addressCtrl.text = bp['address']?.toString() ?? '';
        _phoneCtrl.text = bp['phone']?.toString() ?? '';
        _logoPath = bp['logo_path']?.toString() ?? bp['logo']?.toString();
      }
    } catch (e) {
      NotificationService.showToast(context, 'بارگذاری انجام نشد: $e',
          backgroundColor: Colors.orange);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickLogo() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.image);
      if (res == null || res.files.isEmpty) return;
      final p = res.files.single.path;
      if (p == null) return;
      // میتوانید اینجا فایل را کپی کنید؛ این نسخه فقط مسیر را ذخیره میکند
      setState(() => _logoPath = p);
      NotificationService.showToast(context, 'لوگو انتخاب شد');
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'انتخاب لوگو انجام نشد: $e');
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final data = <String, dynamic>{
        'business_name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'logo_path': _logoPath ?? '',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };
      await AppDatabase.saveBusinessProfile(data);
      NotificationService.showSuccess(
          context, 'ذخیره شد', 'پروفایل فروشگاه ذخیره شد');
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'ذخیره انجام نشد: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات فروشگاه'),
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
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _nameCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'نام فروشگاه',
                                    border: OutlineInputBorder()),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _addressCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'آدرس',
                                    border: OutlineInputBorder()),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _phoneCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'تلفن',
                                    border: OutlineInputBorder()),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (_logoPath != null &&
                                      _logoPath!.isNotEmpty)
                                    CircleAvatar(
                                      radius: 32,
                                      backgroundImage:
                                          FileImage(File(_logoPath!)),
                                    )
                                  else
                                    const CircleAvatar(
                                        radius: 32, child: Icon(Icons.store)),
                                  const SizedBox(width: 12),
                                  FilledButton.tonal(
                                      onPressed: _pickLogo,
                                      child: const Text('انتخاب لوگو')),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                      onPressed: () =>
                                          setState(() => _logoPath = null),
                                      child: const Text('حذف لوگو')),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(children: [
                                Expanded(
                                    child: FilledButton.tonal(
                                        onPressed: _save,
                                        child: const Text('ذخیره'))),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                    onPressed: _loadProfile,
                                    child: const Text('بارگذاری مجدد')),
                              ])
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
