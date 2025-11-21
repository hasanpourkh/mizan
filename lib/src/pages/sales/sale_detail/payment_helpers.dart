// lib/src/pages/sales/sale_detail/payment_helpers.dart
// مدل‌ها و توابع کمکی مرتبط با پرداخت‌ها (جدا از UI)
// - تعریف ساختار پرداخت، اعتبارسنجی اضافه کردن پرداخت و فرمت تاریخ شمسی
// - این فایل برای جدا کردن منطق از ویجت UI ساخته شده است.

import 'package:shamsi_date/shamsi_date.dart';

class PaymentEntry {
  String type; // cash, card, installment, card_transfer, shaba
  double amount;
  int dateMillis; // ذخیره به صورت millis (UTC)
  String note;
  Map<String, dynamic> extra; // فیلدهای اختصاصی هر نوع پرداخت

  PaymentEntry({
    required this.type,
    required this.amount,
    required this.dateMillis,
    this.note = '',
    Map<String, dynamic>? extra,
  }) : extra = extra ?? {};

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'amount': amount,
      'date': dateMillis,
      'note': note,
      'extra': extra,
    };
  }

  static PaymentEntry fromMap(Map<String, dynamic> m) {
    final rawExtra = m['extra'];
    Map<String, dynamic> extraMap = {};
    if (rawExtra is Map) extraMap = Map<String, dynamic>.from(rawExtra);
    return PaymentEntry(
      type: m['type']?.toString() ?? 'unknown',
      amount: (m['amount'] is num)
          ? (m['amount'] as num).toDouble()
          : double.tryParse(m['amount']?.toString() ?? '0') ?? 0.0,
      dateMillis: (m['date'] is int)
          ? m['date'] as int
          : int.tryParse(m['date']?.toString() ?? '') ?? 0,
      note: m['note']?.toString() ?? '',
      extra: extraMap,
    );
  }

  // برچسب فارسی نوع پرداخت
  String label() {
    switch (type) {
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
        return type;
    }
  }

  // نمایش تاریخ به فرمت شمسی خوانا
  String jalaliDateString() {
    try {
      if (dateMillis == 0) return '-';
      final dt = DateTime.fromMillisecondsSinceEpoch(dateMillis);
      final j = Jalali.fromDateTime(dt);
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')} $hh:$mm';
    } catch (_) {
      return '-';
    }
  }
}

/// محاسبهٔ جمع پرداخت‌شده از لیستی از Map یا PaymentEntry
double totalPaidFrom(dynamic paymentsRaw) {
  try {
    if (paymentsRaw == null) return 0.0;
    double s = 0.0;
    if (paymentsRaw is List) {
      for (final p in paymentsRaw) {
        if (p is PaymentEntry) {
          s += p.amount;
        } else if (p is Map) {
          final a = p['amount'];
          if (a is num) {
            s += a.toDouble();
          } else {
            s += double.tryParse(a?.toString() ?? '') ?? 0.0;
          }
        }
      }
    }
    return s;
  } catch (_) {
    return 0.0;
  }
}

/// اعتبارسنجی اضافه کردن پرداخت جدید:
/// - جمع پرداخت‌ها پس از اضافه نباید از grandTotal بیشتر شود.
/// - اگر نوع installment است، می‌توان مقدار اقساط/پیش‌پرداخت را بررسی کرد (اینجا حداقلی اعمال شده)
///
/// برگرداندن null یعنی معتبر است؛ در غیر این صورت رشتهٔ خطا.
String? validateAddPayment({
  required double grandTotal,
  required List<PaymentEntry> existing,
  required PaymentEntry toAdd,
}) {
  final current = totalPaidFrom(existing);
  final after = current + toAdd.amount;
  if (toAdd.amount <= 0) return 'مقدار پرداخت باید بزرگتر از صفر باشد.';
  // بررسی سر ریز
  if (after > grandTotal + 0.0001) {
    return 'مجموع پرداخت‌ها نمیتواند بیشتر از مبلغ فاکتور (${grandTotal.toStringAsFixed(2)}) باشد. باقیمانده: ${(grandTotal - current).clamp(0.0, grandTotal).toStringAsFixed(2)}';
  }
  // در صورت اقساط حداقل مقداری بررسی میکنیم (مثلاً تعداد قسط >=1)
  if (toAdd.type == 'installment') {
    final inst = (toAdd.extra['installments'] is int)
        ? toAdd.extra['installments'] as int
        : int.tryParse(toAdd.extra['installments']?.toString() ?? '') ?? 1;
    if (inst <= 0) return 'تعداد اقساط نامعتبر است.';
  }
  return null;
}

/// ساخت آبجکت نهایی payment_info که به DB نوشته میشود
Map<String, dynamic> buildPaymentInfoPayload({
  required double grandTotal,
  required List<PaymentEntry> payments,
}) {
  final paid = totalPaidFrom(payments);
  final isPaid = (paid >= (grandTotal - 0.0001));
  return {
    'grand_total': grandTotal,
    'payments': payments.map((p) => p.toMap()).toList(),
    'updated_at': DateTime.now().millisecondsSinceEpoch,
    'is_paid': isPaid,
    // یک برچسب جهت استفادهٔ حسابداری/صورت‌حساب سود و زیان
    'accounting_tag': 'sale_payment',
  };
}
