// lib/src/pages/products/price_update/price_update_page.dart
// صفحهٔ بروزرسانی جمعی قیمت‌ها
// ویژگی‌ها: فهرست محصولات، جستجو، انتخاب چندتایی/انتخاب همه، درصد/مبلغ، افزایش/کاهش، گرد کردن، ذخیره در DB.
// کامنت فارسی مختصر: UI و کنترل‌ها جدا و منطقی پیاده شده‌اند؛ منطقِ update در سرویس جدا قرار دارد.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mizan/src/core/db/app_database.dart';
import 'package:mizan/src/core/notifications/notification_service.dart';
import 'price_update_service.dart';
import 'widgets/product_row.dart';

class PriceUpdatePage extends StatefulWidget {
  const PriceUpdatePage({super.key});

  @override
  State<PriceUpdatePage> createState() => _PriceUpdatePageState();
}

class _PriceUpdatePageState extends State<PriceUpdatePage> {
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  final Set<int> _selected = {};
  bool _loading = true;
  String _q = '';

  // تنظیمات عملیات
  String _targetField = 'price'; // 'price' یا 'purchase_price'
  bool _isPercent = true;
  final TextEditingController _percentCtrl = TextEditingController(text: '0');
  final TextEditingController _amountCtrl = TextEditingController(text: '0');
  bool _increase = true;
  int _rounding = 0; // 0..5

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final prods = await AppDatabase.getProducts();
      setState(() {
        _all = prods.map((e) => Map<String, dynamic>.from(e)).toList();
        _applyFilter();
      });
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'بارگذاری محصولات انجام نشد: $e');
      setState(() {
        _all = [];
        _filtered = [];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = List<Map<String, dynamic>>.from(_all);
    } else {
      _filtered = _all.where((p) {
        final name = p['name']?.toString().toLowerCase() ?? '';
        final sku = p['sku']?.toString().toLowerCase() ?? '';
        final code = p['product_code']?.toString().toLowerCase() ?? '';
        return name.contains(q) || sku.contains(q) || code.contains(q);
      }).toList();
    }
  }

  void _toggleSelectAllVisible() {
    final ids = _filtered
        .map((p) => (p['id'] is int)
            ? p['id'] as int
            : int.tryParse(p['id']?.toString() ?? '') ?? 0)
        .where((id) => id > 0)
        .toList();
    final allSelected =
        ids.isNotEmpty && ids.every((id) => _selected.contains(id));
    setState(() {
      if (allSelected) {
        for (var id in ids) {
          _selected.remove(id);
        }
      } else {
        for (var id in ids) {
          _selected.add(id);
        }
      }
    });
  }

  Future<void> _applyUpdates() async {
    if (_selected.isEmpty) {
      NotificationService.showToast(context, 'هیچ محصولی انتخاب نشده است');
      return;
    }

    final p = PriceUpdateParams(
      targetField: _targetField,
      isPercent: _isPercent,
      value: _isPercent
          ? (double.tryParse(_percentCtrl.text.replaceAll(',', '.')) ?? 0.0)
          : (double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0),
      increase: _increase,
      roundingZeros: _rounding,
    );

    final count = _selected.length;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تایید بروزرسانی قیمت‌ها'),
        content: Text(
            'در حال اعمال تغییر روی $count محصول هستید.\nآیا ادامه می‌دهید؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('لغو')),
          FilledButton.tonal(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('ادامه')),
        ],
      ),
    );

    if (proceed != true) return;

    setState(() => _loading = true);
    try {
      final ids = List<int>.from(_selected);
      for (final id in ids) {
        await applyPriceUpdateToProduct(id, p);
      }
      NotificationService.showSuccess(
          context, 'پایان', 'قیمت $count محصول با موفقیت بروزرسانی شد');
      await _load();
      setState(() => _selected.clear());
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'اعمال تغییرات انجام نشد: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _percentCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selected.length;
    return Scaffold(
      appBar: AppBar(title: const Text('بروزرسانی قیمت‌ها')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.save),
        label: Text('اعمال ($selectedCount)'),
        onPressed: _loading ? null : _applyUpdates,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(children: [
                      Row(children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: 'جستجو (نام / SKU / کد)'),
                            onChanged: (v) {
                              setState(() {
                                _q = v;
                                _applyFilter();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                            onPressed: _load,
                            child: const Text('بارگذاری مجدد')),
                        const SizedBox(width: 8),
                        OutlinedButton(
                            onPressed: _toggleSelectAllVisible,
                            child: const Text('انتخاب/لغو انتخاب همه')),
                      ]),
                      const Divider(),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _targetField,
                            decoration: const InputDecoration(
                                labelText: 'عملیات (هدف)', isDense: true),
                            items: const [
                              DropdownMenuItem(
                                  value: 'price', child: Text('قیمت فروش')),
                              DropdownMenuItem(
                                  value: 'purchase_price',
                                  child: Text('قیمت خرید')),
                            ],
                            onChanged: (v) =>
                                setState(() => _targetField = v ?? 'price'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<bool>(
                            initialValue: _increase,
                            decoration: const InputDecoration(
                                labelText: 'نوع', isDense: true),
                            items: const [
                              DropdownMenuItem(
                                  value: true, child: Text('افزایش')),
                              DropdownMenuItem(
                                  value: false, child: Text('کاهش')),
                            ],
                            onChanged: (v) =>
                                setState(() => _increase = v ?? true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(children: [
                            Expanded(
                              child: ListTile(
                                title: const Text('درصد'),
                                leading: Radio<bool>(
                                    value: true,
                                    groupValue: _isPercent,
                                    onChanged: (v) =>
                                        setState(() => _isPercent = v ?? true)),
                              ),
                            ),
                            Expanded(
                              child: ListTile(
                                title: const Text('مبلغ (ریال)'),
                                leading: Radio<bool>(
                                    value: false,
                                    groupValue: _isPercent,
                                    onChanged: (v) =>
                                        setState(() => _isPercent = v ?? true)),
                              ),
                            ),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _percentCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'درصد (مثلاً ۱۰ برای ۱۰٪)',
                                isDense: true),
                            enabled: _isPercent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'مبلغ (ریال)', isDense: true),
                            enabled: !_isPercent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _rounding,
                            decoration: const InputDecoration(
                                labelText: 'گرد کردن (تعداد صفر)',
                                isDense: true),
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('خیر')),
                              DropdownMenuItem(value: 1, child: Text('1')),
                              DropdownMenuItem(value: 2, child: Text('2')),
                              DropdownMenuItem(value: 3, child: Text('3')),
                              DropdownMenuItem(value: 4, child: Text('4')),
                              DropdownMenuItem(value: 5, child: Text('5')),
                            ],
                            onChanged: (v) =>
                                setState(() => _rounding = v ?? 0),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Card(
                    child: _filtered.isEmpty
                        ? const Center(child: Text('هیچ محصولی یافت نشد'))
                        : ListView.separated(
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final p = _filtered[idx];
                              final id = (p['id'] is int)
                                  ? p['id'] as int
                                  : int.tryParse(p['id']?.toString() ?? '') ??
                                      0;
                              final sel = _selected.contains(id);
                              return PriceProductRow(
                                product: p,
                                selected: sel,
                                onToggle: (v) {
                                  setState(() {
                                    if (v) {
                                      _selected.add(id);
                                    } else {
                                      _selected.remove(id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ),
              ]),
            ),
    );
  }
}
