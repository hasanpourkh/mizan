// lib/src/pages/services/service_form_widget.dart
// ویجت فرم خدمت (قابل استفاده در ایجاد و ویرایش)
// فیلدها: نام، کد، قیمت، واحد، دسته (از دسته‌های محصولات)، توضیحات، فعال/غیرفعال
// خروجی: Map<String,dynamic> به callback onSave ارسال میشود.

import 'package:flutter/material.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../products/category_picker.dart';

typedef OnSaveService = Future<void> Function(Map<String, dynamic> payload);

class ServiceFormWidget extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final OnSaveService onSave;
  final bool saving;

  const ServiceFormWidget(
      {super.key, this.initial, required this.onSave, this.saving = false});

  @override
  State<ServiceFormWidget> createState() => _ServiceFormWidgetState();
}

class _ServiceFormWidgetState extends State<ServiceFormWidget> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  final _unitCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _active = true;
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _nameCtrl.text = init['name']?.toString() ?? '';
      _codeCtrl.text = init['code']?.toString() ?? '';
      _priceCtrl.text =
          (init['price'] != null) ? init['price'].toString() : '0';
      _unitCtrl.text = init['unit']?.toString() ?? '';
      _descCtrl.text = init['description']?.toString() ?? '';
      _active = (init['active'] == 1 || init['active'] == true);
      _categoryId = init['category_id'] is int
          ? init['category_id'] as int
          : (init['category_id'] != null
              ? int.tryParse(init['category_id'].toString())
              : null);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _priceCtrl.dispose();
    _unitCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      NotificationService.showError(context, 'خطا', 'نام خدمت را وارد کنید');
      return;
    }
    final payload = <String, dynamic>{
      if (widget.initial != null) 'id': widget.initial!['id'],
      'name': name,
      'code': _codeCtrl.text.trim(),
      'price': double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0.0,
      'unit': _unitCtrl.text.trim(),
      'category_id': _categoryId,
      'description': _descCtrl.text.trim(),
      'active': _active ? 1 : 0,
    };
    await widget.onSave(payload);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _nameCtrl,
        decoration: const InputDecoration(
            labelText: 'نام خدمت', border: OutlineInputBorder()),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
            child: TextField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                    labelText: 'کد (اختیاری)', border: OutlineInputBorder()))),
        const SizedBox(width: 8),
        SizedBox(
            width: 140,
            child: TextField(
                controller: _priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'قیمت', border: OutlineInputBorder()))),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
            child: TextField(
                controller: _unitCtrl,
                decoration: const InputDecoration(
                    labelText: 'واحد (مثلاً سرویس/ساعت)',
                    border: OutlineInputBorder()))),
        const SizedBox(width: 8),
        Expanded(
            child: CategoryPicker(
                selectedCategoryId: _categoryId,
                onSelected: (v) => setState(() => _categoryId = v),
                allowManage: true)),
      ]),
      const SizedBox(height: 8),
      TextField(
          controller: _descCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
              labelText: 'توضیحات', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      Row(children: [
        const Text('فعال', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Switch(value: _active, onChanged: (v) => setState(() => _active = v)),
        const Spacer(),
        FilledButton.tonal(
            onPressed: widget.saving ? null : _save,
            child: widget.saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('ذخیره')),
      ]),
    ]);
  }
}
