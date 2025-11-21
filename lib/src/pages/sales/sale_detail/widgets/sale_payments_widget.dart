// lib/src/pages/sales/sale_detail/widgets/sale_payments_widget.dart
// ویجت مدیریت پرداختهای فاکتور — نسخهٔ ارتقا یافته:
// - از payment_helpers.dart برای منطق/مدل پرداخت استفاده میکند.
// - اضافه شدن انواع پرداخت card_transfer و shaba با فیلدهای اختصاصی.
// - جلوگیری از ثبت پرداخت‌هایی که جمعشان از مبلغ فاکتور بیشتر شود.
// - وقتی جمع پرداختها به مبلغ فاکتور رسید، is_paid=true در payload قرار میگیرد.
// - تاریخ‌ها در نمایش به صورت شمسی (Jalali) نشان داده میشوند.
// - تمامی داده‌ها به صورت Map به onSave فرستاده می‌شوند تا Page/DAO آنها را ذخیره کند.
// - کامنت‌های فارسی مختصر برای هر بخش وجود دارد.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../sale_models.dart';
import '../payment_helpers.dart';

typedef OnSavePaymentInfo = Future<void> Function(Map<String, dynamic> info);

class SalePaymentsWidget extends StatefulWidget {
  final Map<String, dynamic>? initialPaymentInfo;
  final double grandTotal;
  final OnSavePaymentInfo onSave;

  const SalePaymentsWidget({
    super.key,
    required this.initialPaymentInfo,
    required this.grandTotal,
    required this.onSave,
  });

  @override
  State<SalePaymentsWidget> createState() => _SalePaymentsWidgetState();
}

class _SalePaymentsWidgetState extends State<SalePaymentsWidget> {
  String _selectedType = 'cash';
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  // فیلدهای اقساط
  int _installments = 1;
  double _downPercent = 0.0;

  // فیلدهای کارت به کارت (card_transfer)
  final TextEditingController _cardSrcCtrl = TextEditingController();
  final TextEditingController _cardDstCtrl = TextEditingController();
  final TextEditingController _cardTrackingCtrl = TextEditingController();
  int _cardDateMillis = DateTime.now().millisecondsSinceEpoch;

  // فیلدهای شبا (shaba)
  final TextEditingController _shabaSrcCtrl = TextEditingController();
  final TextEditingController _shabaDstCtrl = TextEditingController();
  final TextEditingController _shabaTrackingCtrl = TextEditingController();
  int _shabaDateMillis = DateTime.now().millisecondsSinceEpoch;

  final List<PaymentEntry> _payments = [];

  @override
  void initState() {
    super.initState();
    // مقداردهی اولیه از initialPaymentInfo (در صورت وجود)
    if (widget.initialPaymentInfo != null) {
      final raw = widget.initialPaymentInfo!;
      final listRaw = raw['payments'];
      if (listRaw is List) {
        for (final p in listRaw) {
          if (p is Map) {
            _payments.add(PaymentEntry.fromMap(Map<String, dynamic>.from(p)));
          }
        }
      }
    }
    // مقدار اولیه مقدار پیشنهادی برای ورود
    _amountCtrl.text = widget.grandTotal.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _cardSrcCtrl.dispose();
    _cardDstCtrl.dispose();
    _cardTrackingCtrl.dispose();
    _shabaSrcCtrl.dispose();
    _shabaDstCtrl.dispose();
    _shabaTrackingCtrl.dispose();
    super.dispose();
  }

  double get _paidTotal => totalPaidFrom(_payments);

  double get _remaining =>
      (widget.grandTotal - _paidTotal).clamp(0.0, double.infinity);

  String _typeLabel(String t) {
    switch (t) {
      case 'cash':
        return 'نقد';
      case 'card':
        return 'کارت (POS)';
      case 'installment':
        return 'اقساط';
      case 'card_transfer':
        return 'کارت به کارت';
      case 'shaba':
        return 'شبا';
      default:
        return t;
    }
  }

  String _fmtDate(int millis) {
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(millis);
      final j = Jalali.fromDateTime(dt);
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')} $hh:$mm';
    } catch (_) {
      return '';
    }
  }

  Future<void> _pickCardDate(BuildContext ctx) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: ctx,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final time = await showTimePicker(
        context: ctx, initialTime: TimeOfDay.fromDateTime(now));
    final dt = DateTime(picked.year, picked.month, picked.day, time?.hour ?? 0,
        time?.minute ?? 0);
    setState(() => _cardDateMillis = dt.millisecondsSinceEpoch);
  }

  Future<void> _pickShabaDate(BuildContext ctx) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: ctx,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final time = await showTimePicker(
        context: ctx, initialTime: TimeOfDay.fromDateTime(now));
    final dt = DateTime(picked.year, picked.month, picked.day, time?.hour ?? 0,
        time?.minute ?? 0);
    setState(() => _shabaDateMillis = dt.millisecondsSinceEpoch);
  }

  // افزودن پرداخت جدید با اعتبارسنجی
  Future<void> _addPayment() async {
    final raw = _amountCtrl.text.trim();
    final amount = double.tryParse(raw.replaceAll(',', '.')) ?? 0.0;
    if (amount <= 0) {
      NotificationService.showError(
          context, 'خطا', 'مقدار پرداخت باید بزرگتر از صفر باشد.');
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final baseExtra = <String, dynamic>{};

    // مقداردهی extra براساس نوع
    if (_selectedType == 'installment') {
      baseExtra['installments'] = _installments;
      baseExtra['down_percent'] = _downPercent;
      final down = amount * _downPercent / 100.0;
      baseExtra['down_amount'] = double.parse(down.toStringAsFixed(2));
      final remainder = (amount - down).clamp(0.0, double.infinity);
      final per = (_installments > 0) ? (remainder / _installments) : 0.0;
      baseExtra['per_installment'] = double.parse(per.toStringAsFixed(2));
    } else if (_selectedType == 'card_transfer') {
      baseExtra['card_src'] = _cardSrcCtrl.text.trim();
      baseExtra['card_dst'] = _cardDstCtrl.text.trim();
      baseExtra['tracking_no'] = _cardTrackingCtrl.text.trim();
      baseExtra['date'] = _cardDateMillis;
    } else if (_selectedType == 'shaba') {
      baseExtra['shaba_src'] = _shabaSrcCtrl.text.trim();
      baseExtra['shaba_dst'] = _shabaDstCtrl.text.trim();
      baseExtra['tracking_no'] = _shabaTrackingCtrl.text.trim();
      baseExtra['date'] = _shabaDateMillis;
    }

    final entry = PaymentEntry(
      type: _selectedType,
      amount: double.parse(amount.toStringAsFixed(2)),
      dateMillis: now,
      note: _noteCtrl.text.trim(),
      extra: baseExtra,
    );

    // اعتبارسنجی با استفاده از helper
    final err = validateAddPayment(
        grandTotal: widget.grandTotal, existing: _payments, toAdd: entry);
    if (err != null) {
      NotificationService.showError(context, 'خطا', err);
      return;
    }

    setState(() {
      _payments.add(entry);
    });

    // ساخت payload و ارسال به والد برای ذخیره (onSave)
    final payload = buildPaymentInfoPayload(
        grandTotal: widget.grandTotal, payments: _payments);
    try {
      await widget.onSave(payload);
      NotificationService.showSuccess(
          context, 'ذخیره شد', 'پرداخت ثبت و ذخیره شد');
      // پاکسازی فیلدهای ورودی (در صورت نیاز)
      _noteCtrl.clear();
      // اگر پرداخت تکمیل شد می‌توان فیلد مقدار را صفر یا disabled کرد (اینجا مقدار به باقیمانده تغییر می‌یابد)
      if (payload['is_paid'] == true) {
        _amountCtrl.text = '0.00';
      } else {
        _amountCtrl.text = (_remaining).toStringAsFixed(2);
      }
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'ذخیرهٔ پرداخت انجام نشد: $e');
    }
  }

  Future<void> _removePayment(int idx) async {
    if (idx < 0 || idx >= _payments.length) return;
    setState(() => _payments.removeAt(idx));
    final payload = buildPaymentInfoPayload(
        grandTotal: widget.grandTotal, payments: _payments);
    try {
      await widget.onSave(payload);
      NotificationService.showSuccess(
          context, 'بروزرسانی شد', 'پرداخت حذف و ذخیره شد');
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'بروزرسانی پرداخت‌ها انجام نشد: $e');
    }
  }

  Future<void> _onSaveManual() async {
    final payload = buildPaymentInfoPayload(
        grandTotal: widget.grandTotal, payments: _payments);
    try {
      await widget.onSave(payload);
      NotificationService.showSuccess(
          context, 'ذخیره شد', 'اطلاعات پرداخت ذخیره شد');
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'ذخیره انجام نشد: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('وضعیت پرداخت', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),

      // نمایش جمع پرداخت‌شده و باقیمانده
      Text('جمع فاکتور: ${widget.grandTotal.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      Text(
          'جمع پرداخت شده: ${_paidTotal.toStringAsFixed(2)} — باقیمانده: ${remaining.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),

      // انتخاب نوع پرداخت و مقدار
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _selectedType,
            decoration: const InputDecoration(
                labelText: 'نوع پرداخت',
                border: OutlineInputBorder(),
                isDense: true),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('نقد')),
              DropdownMenuItem(value: 'card', child: Text('کارت (POS)')),
              DropdownMenuItem(value: 'installment', child: Text('اقساط')),
              DropdownMenuItem(
                  value: 'card_transfer', child: Text('کارت به کارت')),
              DropdownMenuItem(value: 'shaba', child: Text('شبا')),
            ],
            onChanged: (v) => setState(() {
              _selectedType = v ?? 'cash';
            }),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 150,
          child: TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'مقدار',
              border: const OutlineInputBorder(),
              helperText: 'باقیمانده: ${remaining.toStringAsFixed(2)}',
            ),
          ),
        ),
      ]),
      const SizedBox(height: 8),

      // گزینه‌های اختصاصی برای هر نوع
      if (_selectedType == 'installment')
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Row(children: [
              const Text('تعداد قسط: '),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _installments,
                items: List.generate(
                    12,
                    (i) => DropdownMenuItem(
                        value: i + 1, child: Text('${i + 1}'))),
                onChanged: (v) => setState(() => _installments = v ?? 1),
              ),
            ])),
            const SizedBox(width: 12),
            SizedBox(
              width: 180,
              child: TextField(
                decoration: const InputDecoration(
                    labelText: 'درصد پیشپرداخت %',
                    border: OutlineInputBorder()),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) => setState(() => _downPercent =
                    double.tryParse(v.replaceAll(',', '.')) ?? 0.0),
                controller:
                    TextEditingController(text: _downPercent.toString()),
              ),
            ),
          ]),
          const SizedBox(height: 8),
        ]),

      if (_selectedType == 'card_transfer')
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('مشخصات کارت به کارت',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _cardSrcCtrl,
                    decoration: const InputDecoration(
                        labelText: 'شماره کارت مبدا',
                        border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: _cardDstCtrl,
                    decoration: const InputDecoration(
                        labelText: 'شماره کارت مقصد',
                        border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _cardTrackingCtrl,
                    decoration: const InputDecoration(
                        labelText: 'شماره پیگیری',
                        border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            SizedBox(
                width: 160,
                child: FilledButton.tonal(
                    onPressed: () => _pickCardDate(context),
                    child: Text('تاریخ انتقال: ${_fmtDate(_cardDateMillis)}'))),
          ]),
          const SizedBox(height: 8),
        ]),

      if (_selectedType == 'shaba')
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('مشخصات شبا',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _shabaSrcCtrl,
                    decoration: const InputDecoration(
                        labelText: 'شماره شبا مبدا',
                        border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: _shabaDstCtrl,
                    decoration: const InputDecoration(
                        labelText: 'شماره شبا مقصد',
                        border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _shabaTrackingCtrl,
                    decoration: const InputDecoration(
                        labelText: 'شماره پیگیری',
                        border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            SizedBox(
                width: 160,
                child: FilledButton.tonal(
                    onPressed: () => _pickShabaDate(context),
                    child:
                        Text('تاریخ انتقال: ${_fmtDate(_shabaDateMillis)}'))),
          ]),
          const SizedBox(height: 8),
        ]),

      // یادداشت پرداخت (اختیاری)
      TextField(
          controller: _noteCtrl,
          decoration: const InputDecoration(
              labelText: 'توضیح (اختیاری)', border: OutlineInputBorder())),
      const SizedBox(height: 8),

      // دکمه‌ها
      Row(children: [
        FilledButton.tonal(
            onPressed: _addPayment, child: const Text('افزودن پرداخت')),
        const SizedBox(width: 8),
        OutlinedButton(
            onPressed: _onSaveManual, child: const Text('ذخیره پرداختها')),
      ]),

      const SizedBox(height: 12),
      const Divider(),
      const SizedBox(height: 8),
      const Text('لیست پرداختها',
          style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),

      // لیست پرداخت‌ها
      Expanded(
        child: _payments.isEmpty
            ? const Center(child: Text('پرداختی ثبت نشده'))
            : ListView.separated(
                itemCount: _payments.length,
                separatorBuilder: (_, __) => const Divider(height: 6),
                itemBuilder: (ctx, idx) {
                  final p = _payments[idx];
                  final subtitleSb = StringBuffer();
                  subtitleSb
                      .write('${p.label()} • ${p.amount.toStringAsFixed(2)}');
                  if (p.type == 'installment') {
                    subtitleSb.write(
                        ' • اقساط: ${p.extra['installments'] ?? '-'} • پیش%: ${p.extra['down_percent'] ?? '-'}');
                  }
                  final detail = <Widget>[
                    Text(subtitleSb.toString()),
                    Text(
                        'تاریخ: ${p.jalaliDateString()}${p.note.isNotEmpty ? ' • ${p.note}' : ''}',
                        style: const TextStyle(fontSize: 12)),
                  ];
                  // در صورت کارت به کارت یا شبا، نمایش فیلدهای اختصاصی
                  if (p.type == 'card_transfer') {
                    detail.add(Text(
                        'از کارت: ${p.extra['card_src'] ?? '-'} → به کارت: ${p.extra['card_dst'] ?? '-'}'));
                    detail.add(Text(
                        'شماره پیگیری: ${p.extra['tracking_no'] ?? '-'} • تاریخ انتقال: ${_fmtDate((p.extra['date'] is int) ? p.extra['date'] : 0)}',
                        style: const TextStyle(fontSize: 11)));
                  } else if (p.type == 'shaba') {
                    detail.add(Text(
                        'از شبا: ${p.extra['shaba_src'] ?? '-'} → به شبا: ${p.extra['shaba_dst'] ?? '-'}'));
                    detail.add(Text(
                        'شماره پیگیری: ${p.extra['tracking_no'] ?? '-'} • تاریخ انتقال: ${_fmtDate((p.extra['date'] is int) ? p.extra['date'] : 0)}',
                        style: const TextStyle(fontSize: 11)));
                  }

                  return ListTile(
                    dense: true,
                    title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: detail),
                    trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removePayment(idx)),
                  );
                },
              ),
      ),
    ]);
  }
}
