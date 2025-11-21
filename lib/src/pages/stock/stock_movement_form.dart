// lib/src/pages/stock/stock_movement_form.dart
// ویجت فرم کوچکِ ثبت حرکت (Stock Movement) — قابل استفاده در دیالوگ یا صفحهٔ جزئیات.
// - این فایل یک ویجت جداست تا ساختار پروژه منظم بماند.
// - طراحی فشرده (compact) با ورودی‌های کوچک برای سازگاری در صفحات با فضای کم.
// - استفاده مستقیم از AppDatabase.registerStockMovement برای ثبت.
// - کامنت فارسی مختصر برای هر بخش وجود دارد.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';

class StockMovementForm extends StatefulWidget {
  final int itemId;
  final VoidCallback? onSaved; // کال‌بک بعد از ثبت موفق

  const StockMovementForm({super.key, required this.itemId, this.onSaved});

  @override
  State<StockMovementForm> createState() => _StockMovementFormState();
}

class _StockMovementFormState extends State<StockMovementForm> {
  String _type = 'out';
  int? _warehouseId;
  List<Map<String, dynamic>> _warehouses = [];
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  final TextEditingController _refCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _actorCtrl = TextEditingController(text: 'user');
  DateTime _when = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    try {
      final wh = await AppDatabase.getWarehouses();
      setState(() {
        _warehouses = wh;
        if (_warehouses.isNotEmpty) {
          _warehouseId = (_warehouses.first['id'] is int)
              ? _warehouses.first['id'] as int
              : int.tryParse(_warehouses.first['id']?.toString() ?? '');
        }
      });
    } catch (_) {}
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _when,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (d == null) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (t == null) return;
    setState(() {
      _when = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _save() async {
    final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (qty <= 0) {
      NotificationService.showError(context, 'خطا', 'مقدار صحیح وارد کنید');
      return;
    }
    if (_warehouseId == null || _warehouseId == 0) {
      NotificationService.showError(context, 'خطا', 'یک انبار انتخاب کنید');
      return;
    }
    setState(() => _saving = true);
    try {
      await AppDatabase.registerStockMovement(
        itemId: widget.itemId,
        warehouseId: _warehouseId!,
        type: _type,
        qty: qty,
        reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        actor: _actorCtrl.text.trim().isEmpty ? 'user' : _actorCtrl.text.trim(),
      );
      NotificationService.showSuccess(context, 'ثبت شد', 'حرکت ذخیره شد');
      widget.onSaved?.call();
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'ثبت انجام نشد: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    _actorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(
            child: DropdownButtonFormField<String>(
                initialValue: _type,
                decoration:
                    const InputDecoration(labelText: 'نوع', isDense: true),
                items: const [
                  DropdownMenuItem(value: 'in', child: Text('ورود')),
                  DropdownMenuItem(value: 'out', child: Text('خروج')),
                  DropdownMenuItem(value: 'adjust', child: Text('تنظیم')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'out'))),
        const SizedBox(width: 8),
        SizedBox(
            width: 120,
            child: TextField(
                controller: _qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'تعداد', isDense: true))),
        const SizedBox(width: 8),
        Expanded(
            child: DropdownButtonFormField<int?>(
                initialValue: _warehouseId,
                decoration:
                    const InputDecoration(labelText: 'انبار', isDense: true),
                items: _warehouses.isEmpty
                    ? [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('فاقد انبار'))
                      ]
                    : _warehouses.map((w) {
                        final id = (w['id'] is int)
                            ? w['id'] as int
                            : int.tryParse(w['id']?.toString() ?? '') ?? 0;
                        return DropdownMenuItem<int?>(
                            value: id,
                            child: Text(w['name']?.toString() ?? ''));
                      }).toList(),
                onChanged: (v) => setState(() => _warehouseId = v))),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
            child: TextField(
                controller: _refCtrl,
                decoration:
                    const InputDecoration(labelText: 'مرجع', isDense: true))),
        const SizedBox(width: 8),
        SizedBox(
            width: 160,
            child: FilledButton.tonal(
                onPressed: _pickDateTime,
                child: Text(DateFormat('yyyy-MM-dd HH:mm').format(_when),
                    style: const TextStyle(fontSize: 12)))),
        const SizedBox(width: 8),
        SizedBox(
            width: 120,
            child: TextField(
                controller: _actorCtrl,
                decoration:
                    const InputDecoration(labelText: 'عامل', isDense: true))),
      ]),
      const SizedBox(height: 8),
      TextField(
          controller: _notesCtrl,
          decoration:
              const InputDecoration(labelText: 'یادداشت', isDense: true)),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        OutlinedButton(
            onPressed: () {
              _qtyCtrl.text = '1';
              _refCtrl.clear();
              _notesCtrl.clear();
            },
            child: const Text('پاکسازی')),
        const SizedBox(width: 8),
        FilledButton.tonal(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('ثبت')),
      ]),
    ]);
  }
}
