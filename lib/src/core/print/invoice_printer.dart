// lib/src/core/print/invoice_printer.dart
// تولید PDF فاکتور — اصلاح برای نمایش صحیح اطلاعات مشتری (نام + نام‌خانوادگی) در یک خط، راست‌چین
// و افزودن فیلد "توضیح خریدار" و "مقصد/برای کجا" در چاپ فاکتور.
// نکات اصلی:
// - اگر sale فقط customer_id داشت، از AppDatabase.getPersonById اطلاعات مشتری را میگیریم و فیلدهای sale را تکمیل میکنیم.
// - نام مشتری: اگر display_name موجود باشد استفاده میشود، در غیر اینصورت first_name + last_name.
// - نمایش یک خطی: "مشتری: <نام>    تلفن: <شماره>    توضیح خریدار: <متن>" (همه راست‌چین و در یک خط)
// - اگر sale دارای فیلدهای 'customer_note' یا 'customer_location' یا 'purchase_for' یا 'invoice_for' باشد آنها را نمایش میدهیم.
// - سایر بخش‌های فاکتور (هدر، جدول، جمع‌ها، پرداخت‌ها، شبکه‌های اجتماعی) بدون تغییر منطقی اصلی حفظ شده‌اند.
// - حتماً فونت فارسی (مثل Vazir-Regular.ttf یا IRANSansXFaNum-Regular.ttf) را در assets/fonts قرار بده و اپ را ری‌استارت کن.
//
// توضیح خیلی خیلی کوتاه:
// فایل را جایگزین کن: lib/src/core/print/invoice_printer.dart — سپس flutter pub get و اپ را کامل ری‌استارت کن.
// اگر هنوز مشکل داشتی یک نمونه JSON از sale که به buildInvoicePdf میدی بفرست.

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;
import 'package:shamsi_date/shamsi_date.dart';
import 'package:intl/intl.dart';
import '../db/app_database.dart';
import '../db/daos/sales_dao.dart' as sales_dao;
import 'package:sqflite/sqlite_api.dart';

/// تبدیل عدد به حروف فارسی (نسخهٔ ساده)
String _numberToPersianWords(int number) {
  if (number == 0) return 'صفر';
  const units = ['', 'یک', 'دو', 'سه', 'چهار', 'پنج', 'شش', 'هفت', 'هشت', 'نه'];
  const teens = [
    'ده',
    'یازده',
    'دوازده',
    'سیزده',
    'چهارده',
    'پانزده',
    'شانزده',
    'هجده',
    'نوزده'
  ];
  const tens = [
    '',
    '',
    'بیست',
    'سی',
    'چهل',
    'پنجاه',
    'شصت',
    'هفتاد',
    'هشتاد',
    'نود'
  ];
  const hundreds = [
    '',
    'یکصد',
    'دویست',
    'سیصد',
    'چهارصد',
    'پانصد',
    'ششصد',
    'هفتصد',
    'هشتصد',
    'نهصد'
  ];

  String threeDigitsToWords(int n) {
    final h = n ~/ 100;
    final rem = n % 100;
    final t = rem ~/ 10;
    final u = rem % 10;
    final parts = <String>[];
    if (h > 0) parts.add(hundreds[h]);
    if (rem >= 10 && rem < 20) {
      parts.add(teens[rem - 10]);
    } else {
      if (t > 0) parts.add(tens[t]);
      if (u > 0) parts.add(units[u]);
    }
    return parts.join(' و ');
  }

  final parts = <String>[];
  final scales = [
    [1000000000, 'میلیارد'],
    [1000000, 'میلیون'],
    [1000, 'هزار'],
    [1, '']
  ];

  int rest = number;
  for (final s in scales) {
    final val = s[0] as int;
    final name = s[1] as String;
    if (rest >= val) {
      final cnt = rest ~/ val;
      rest = rest % val;
      if (val >= 1000) {
        parts.add('${threeDigitsToWords(cnt)} $name'.trim());
      } else {
        parts.add(threeDigitsToWords(cnt));
      }
    }
  }

  return '${parts.where((p) => p.isNotEmpty).join(' و ')} ریال';
}

/// تلاش برای بارگذاری فونت فارسی از assets/fonts
Future<pw.Font> _loadPreferredFont() async {
  final candidates = <String>[
    'assets/fonts/IRANSansXFaNum-Regular.ttf',
    'assets/fonts/Vazir-Regular.ttf',
    'assets/fonts/Vazir.ttf',
    'assets/fonts/NotoSansArabic-Regular.ttf',
  ];

  for (final c in candidates) {
    try {
      final bd = await rootBundle.load(c);
      return pw.Font.ttf(bd);
    } catch (_) {}
  }
  // ignore: avoid_print
  print(
      'WARNING: No Persian TTF found in assets/fonts. Please add Vazir or IRANSans.');
  return pw.Font.helvetica();
}

String _fmtNum(num v) {
  final dv = v.toDouble();
  if (dv == dv.roundToDouble()) {
    return NumberFormat('#,###', 'en_US').format(dv.toInt());
  } else {
    return NumberFormat('#,##0.00', 'en_US').format(dv);
  }
}

String _typeLabel(String t) {
  switch (t) {
    case 'cash':
      return 'نقد';
    case 'card':
      return 'کارت';
    case 'installment':
      return 'اقساط';
    default:
      return t;
  }
}

/// نگاشت نام پلتفرم به فارسی (پیشفرض‌ها)
String _platformToPersian(String platform, String? display) {
  const map = {
    'instagram': 'اینستاگرام',
    'telegram': 'تلگرام',
    'whatsapp': 'واتساپ',
    'facebook': 'فیسبوک',
    'twitter': 'توییتر',
    'linkedin': 'لینکداین',
    'aparat': 'آپارات',
    'youtube': 'یوتیوب',
    'tiktok': 'تیک‌تاک',
  };
  if (platform == 'other') {
    return (display?.isNotEmpty ?? false) ? display! : 'شبکه';
  }
  return map[platform] ?? (display?.isNotEmpty ?? false ? display! : platform);
}

/// ساخت PDF فاکتور
Future<Uint8List> buildInvoicePdf({
  required Map<String, dynamic> sale,
  Map<String, dynamic>? business,
  pdf.PdfPageFormat? pageFormat,
}) async {
  final pdfDoc = pw.Document();
  final format = pageFormat ?? pdf.PdfPageFormat.a4;
  final font = await _loadPreferredFont();

  // اطلاعات کسب‌وکار
  final shopName = business?['business_name']?.toString() ?? '';
  final shopAddress = business?['address']?.toString() ?? '';
  final shopPhone = business?['phone']?.toString() ?? '';
  final shopWebsite = business?['website']?.toString() ?? '';
  final adText = business?['print_ad_text']?.toString() ?? '';

  // لوگو
  pw.ImageProvider? logoImage;
  final logoPath = business?['logo_path']?.toString() ?? '';
  if (logoPath.isNotEmpty) {
    try {
      final f = File(logoPath);
      if (await f.exists()) {
        logoImage = pw.MemoryImage(await f.readAsBytes());
      }
    } catch (_) {}
  }

  // social_links decode
  List<Map<String, dynamic>> socialLinks = [];
  try {
    final slRaw = business?['social_links'];
    if (slRaw != null) {
      if (slRaw is String && slRaw.isNotEmpty) {
        final dec = json.decode(slRaw);
        if (dec is List) {
          for (final e in dec) {
            if (e is Map) socialLinks.add(Map<String, dynamic>.from(e));
          }
        }
      } else if (slRaw is List) {
        for (final e in slRaw) {
          if (e is Map) socialLinks.add(Map<String, dynamic>.from(e));
        }
      }
    }
  } catch (_) {}

  // ---- تکمیل اطلاعات مشتری اگر لازم است ----
  try {
    // اگر sale['customer_name'] خالی است ولی customer_id موجود است، از DB بخوان
    final custNameRaw = sale['customer_name']?.toString() ?? '';
    if ((custNameRaw.isEmpty || custNameRaw == 'null') &&
        sale.containsKey('customer_id')) {
      final idRaw = sale['customer_id'];
      final cid =
          (idRaw is int) ? idRaw : int.tryParse(idRaw?.toString() ?? '') ?? 0;
      if (cid > 0) {
        final p = await AppDatabase.getPersonById(cid);
        if (p != null) {
          // نام: display_name یا first + last
          final disp = p['display_name']?.toString() ?? '';
          final fname = p['first_name']?.toString() ?? '';
          final lname = p['last_name']?.toString() ?? '';
          sale['customer_name'] =
              disp.isNotEmpty ? disp : ('$fname ${lname ?? ''}').trim();
          // جدا کردن first/last در صورت نیاز
          sale['customer_first_name'] = p['first_name']?.toString() ?? '';
          sale['customer_last_name'] = p['last_name']?.toString() ?? '';
          if (p['phone'] != null &&
              (sale['customer_phone'] == null ||
                  sale['customer_phone'].toString().isEmpty)) {
            sale['customer_phone'] = p['phone']?.toString();
          }
          if (p['address'] != null &&
              (sale['customer_location'] == null ||
                  sale['customer_location'].toString().isEmpty)) {
            sale['customer_location'] = p['address']?.toString();
          }
          if (sale['customer_note'] == null && p['notes'] != null) {
            sale['customer_note'] = p['notes']?.toString();
          }
        }
      }
    } else {
      // اگر customer_name موجود ولی فقط عدد id نمایش داده میشود (مثلاً "1")، تلاش کن باز هم person را بخوانی
      final nameVal = sale['customer_name']?.toString() ?? '';
      if (RegExp(r'^\d+$').hasMatch(nameVal) &&
          sale.containsKey('customer_id')) {
        final idRaw = sale['customer_id'];
        final cid = (idRaw is int)
            ? idRaw
            : int.tryParse(idRaw?.toString() ?? '') ??
                int.tryParse(nameVal) ??
                0;
        if (cid > 0) {
          final p = await AppDatabase.getPersonById(cid);
          if (p != null) {
            final disp = p['display_name']?.toString() ?? '';
            final fname = p['first_name']?.toString() ?? '';
            final lname = p['last_name']?.toString() ?? '';
            sale['customer_name'] =
                disp.isNotEmpty ? disp : ('$fname ${lname ?? ''}').trim();
            sale['customer_first_name'] = p['first_name']?.toString() ?? '';
            sale['customer_last_name'] = p['last_name']?.toString() ?? '';
            if (p['phone'] != null &&
                (sale['customer_phone'] == null ||
                    sale['customer_phone'].toString().isEmpty)) {
              sale['customer_phone'] = p['phone']?.toString();
            }
            if (p['address'] != null &&
                (sale['customer_location'] == null ||
                    sale['customer_location'].toString().isEmpty)) {
              sale['customer_location'] = p['address']?.toString();
            }
          }
        }
      }
    }
  } catch (_) {}

  // اگر payment_info در sale نیست، تلاش کن از DAO بخوانی (sales_dao.getSalePaymentInfo)
  Map<String, dynamic>? paymentInfo;
  try {
    if (sale.containsKey('payment_info') && sale['payment_info'] != null) {
      final raw = sale['payment_info'];
      if (raw is String && raw.isNotEmpty) {
        try {
          final dec = json.decode(raw);
          if (dec is Map) paymentInfo = Map<String, dynamic>.from(dec);
        } catch (_) {}
      } else if (raw is Map) {
        paymentInfo = Map<String, dynamic>.from(raw);
      }
    }
    if (paymentInfo == null && sale.containsKey('id')) {
      final idRaw = sale['id'];
      final sid =
          (idRaw is int) ? idRaw : int.tryParse(idRaw?.toString() ?? '') ?? 0;
      if (sid > 0) {
        try {
          final Database db = await AppDatabase.db;
          final pi = await sales_dao
              .getSalePaymentInfo(db, sid)
              .catchError((_) => null);
          if (pi != null) paymentInfo = pi;
        } catch (_) {}
      }
    }
  } catch (_) {}

  // خطوط فاکتور: و تکمیل نام/کد از DB در صورت نیاز
  final rawLines = <Map<String, dynamic>>[];
  if (sale.containsKey('lines') && sale['lines'] is List) {
    for (final l in List.from(sale['lines'])) {
      rawLines.add(Map<String, dynamic>.from(l));
    }
  }
  for (var i = 0; i < rawLines.length; i++) {
    final r = rawLines[i];
    try {
      final pidRaw = r['product_id'];
      final pid = (pidRaw is int)
          ? pidRaw
          : int.tryParse(pidRaw?.toString() ?? '') ?? 0;
      if (pid > 0) {
        if ((r['product_name'] == null ||
            r['product_name'].toString().trim().isEmpty)) {
          final prod = await AppDatabase.getProductById(pid);
          if (prod != null) r['product_name'] = prod['name']?.toString() ?? '';
        }
        if ((r['product_code'] == null ||
            r['product_code'].toString().trim().isEmpty)) {
          final prod = await AppDatabase.getProductById(pid);
          if (prod != null) {
            r['product_code'] = prod['product_code']?.toString() ??
                prod['sku']?.toString() ??
                '';
          }
        }
      }
    } catch (_) {}
  }

  // جمع‌ها
  final totalVal = (sale['total'] is num)
      ? (sale['total'] as num).toDouble()
      : double.tryParse(sale['total']?.toString() ?? '') ?? 0.0;
  final discount = (sale['discount'] is num)
      ? (sale['discount'] as num).toDouble()
      : double.tryParse(sale['discount']?.toString() ?? '') ?? 0.0;
  final tax = (sale['tax'] is num)
      ? (sale['tax'] as num).toDouble()
      : double.tryParse(sale['tax']?.toString() ?? '') ?? 0.0;
  final extra = (sale['extra_charges'] is num)
      ? (sale['extra_charges'] as num).toDouble()
      : double.tryParse(sale['extra_charges']?.toString() ?? '') ?? 0.0;

  // تاریخ شمسی
  String formattedDate = '';
  try {
    final millis = sale['created_at'] is int
        ? sale['created_at'] as int
        : int.tryParse(sale['created_at']?.toString() ?? '') ?? 0;
    if (millis > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(millis);
      final j = Jalali.fromDateTime(dt);
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      formattedDate =
          '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')} $hh:$mm';
    }
  } catch (_) {}

  // آماده‌سازی سطرهای جدول: هر ردیف [ردیف, کد, نام, تعداد, بهای واحد, مبلغ کل, شرح]
  final tableRows = <List<String>>[];
  for (var i = 0; i < rawLines.length; i++) {
    final r = rawLines[i];
    final code = r['product_code']?.toString() ?? '';
    final pname = r['product_name']?.toString() ?? '';
    final desc = r['description']?.toString() ?? r['remark']?.toString() ?? '';
    final qty = (r['quantity'] is num)
        ? (r['quantity'] as num).toDouble()
        : double.tryParse(r['quantity']?.toString() ?? '') ?? 0.0;
    final unitPrice = (r['unit_price'] is num)
        ? (r['unit_price'] as num).toDouble()
        : double.tryParse(r['unit_price']?.toString() ?? '') ?? 0.0;
    final lineTotal = (r['line_total'] is num)
        ? (r['line_total'] as num).toDouble()
        : (qty * unitPrice);
    tableRows.add([
      (i + 1).toString(),
      code,
      pname,
      NumberFormat('#,##0.###', 'en_US').format(qty),
      _fmtNum(unitPrice),
      _fmtNum(lineTotal),
      desc,
    ]);
  }

  final totalInWords = _numberToPersianWords(totalVal.round());

  // آماده کردن ویجت شبکه‌های اجتماعی — هر آیتم "نام: آیدی" با آیکون 14px
  Future<pw.Widget> buildSocialInline() async {
    final children = <pw.Widget>[];
    for (final s in socialLinks) {
      final handle = s['handle']?.toString() ?? '';
      if (handle.isEmpty) continue;
      final platform = s['platform']?.toString() ?? 'other';
      final display = s['display_name']?.toString() ?? '';
      final iconPath = s['icon_path']?.toString() ?? '';
      pw.Widget iconW = pw.SizedBox(width: 0, height: 0);
      if (iconPath.isNotEmpty) {
        try {
          final f = File(iconPath);
          if (await f.exists()) {
            final bytes = await f.readAsBytes();
            iconW = pw.Image(pw.MemoryImage(bytes), width: 14, height: 14);
          }
        } catch (_) {}
      }
      final label = _platformToPersian(platform, display);
      children.add(pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: pdf.PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
          iconW,
          if (iconW is! pw.SizedBox) pw.SizedBox(width: 4),
          pw.Text('$label: ', style: pw.TextStyle(font: font, fontSize: 8)),
          pw.Text(handle, style: pw.TextStyle(font: font, fontSize: 8)),
        ]),
      ));
      children.add(pw.SizedBox(width: 6));
    }
    if (children.isEmpty) return pw.SizedBox(height: 1);
    return pw.Wrap(children: children);
  }

  final socialInlineWidget = await buildSocialInline();

  // استایل‌ها
  final headerStyle =
      pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold);
  final cellStyle = pw.TextStyle(font: font, fontSize: 9);
  const headerBg = pdf.PdfColor.fromInt(0xfff3f3f3);

  // آماده‌سازی متن‌های اطلاعات مشتری برای نمایش
  final customerName = sale['customer_name']?.toString() ??
      (sale['customer_first_name']?.toString() ??
          (sale['customer_id']?.toString() ?? '-'));
  final customerPhone = sale['customer_phone']?.toString() ?? '';
  final customerNote =
      sale['customer_note']?.toString() ?? sale['notes']?.toString() ?? '';
  final customerLocation = sale['customer_location']?.toString() ?? '';
  // فیلد مخصوص "برای کجا" / "مقصد" در صورت وجود در sale بررسی میشود
  final purchaseFor = sale['purchase_for']?.toString() ??
      sale['invoice_for']?.toString() ??
      sale['for']?.toString() ??
      '';

  // صفحه PDF
  pdfDoc.addPage(pw.MultiPage(
    pageFormat: format,
    margin: const pw.EdgeInsets.all(14),
    build: (ctx) {
      return [
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // HEADER: سه بخشی (راست: تبلیغ، مرکز: لوگو+نام، چپ: تاریخ/شماره)
                pw.Row(children: [
                  pw.Expanded(
                      child: pw.Container(
                          alignment: pw.Alignment.topRight,
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                if (adText.isNotEmpty)
                                  pw.Text(adText,
                                      style: pw.TextStyle(
                                          font: font, fontSize: 10))
                              ]))),
                  pw.Container(
                      width: 150,
                      child: pw.Center(
                          child: pw.Column(
                              mainAxisSize: pw.MainAxisSize.min,
                              children: [
                            if (logoImage != null)
                              pw.Container(
                                  width: 100,
                                  height: 100,
                                  child: pw.Image(logoImage))
                            else
                              pw.Container(
                                  width: 100,
                                  height: 100,
                                  decoration: pw.BoxDecoration(
                                      border: pw.Border.all(
                                          color: pdf.PdfColors.grey))),
                            pw.SizedBox(height: 6),
                            pw.Text(shopName,
                                style: pw.TextStyle(
                                    font: font,
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold)),
                          ]))),
                  pw.Expanded(
                      child: pw.Container(
                          alignment: pw.Alignment.topLeft,
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('تاریخ: $formattedDate',
                                    style:
                                        pw.TextStyle(font: font, fontSize: 10)),
                                pw.SizedBox(height: 6),
                                pw.Text(
                                    'شماره فاکتور: ${sale['invoice_no'] ?? ''}',
                                    style: pw.TextStyle(
                                        font: font,
                                        fontSize: 12,
                                        fontWeight: pw.FontWeight.bold)),
                              ]))),
                ]),
                pw.SizedBox(height: 8),
                pw.Center(
                    child: pw.Column(children: [
                  if (shopPhone.isNotEmpty)
                    pw.Text('تلفن: $shopPhone',
                        style: pw.TextStyle(font: font, fontSize: 9)),
                  if (shopAddress.isNotEmpty)
                    pw.Text('آدرس: $shopAddress',
                        style: pw.TextStyle(font: font, fontSize: 9)),
                  if (shopWebsite.isNotEmpty)
                    pw.Text('وب: $shopWebsite',
                        style: pw.TextStyle(font: font, fontSize: 9)),
                ])),
                pw.SizedBox(height: 8),
                pw.Divider(),

                // اطلاعات مشتری — یک خط راست‌چین: نام مشتری — تلفن — توضیح خریدار
                pw.SizedBox(height: 6),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                    if (customerPhone.isNotEmpty)
                      pw.Text('تلفن: $customerPhone',
                          style: pw.TextStyle(font: font, fontSize: 10)),
                    if (customerPhone.isNotEmpty) pw.SizedBox(width: 12),
                    pw.Text('مشتری: $customerName',
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold)),
                    if ((customerNote ?? '').isNotEmpty) pw.SizedBox(width: 12),
                    if ((customerNote ?? '').isNotEmpty)
                      pw.Text('توضیح خریدار: $customerNote',
                          style: pw.TextStyle(font: font, fontSize: 9)),
                  ]),
                ),

                // خط دوم اطلاعات مشتری/محل/مقصد (در صورت وجود) — راست‌چین
                if (customerLocation.isNotEmpty || purchaseFor.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 6, bottom: 6),
                    child: pw.Container(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            if (customerLocation.isNotEmpty)
                              pw.Text('محل خرید/آدرس مشتری: $customerLocation',
                                  style: pw.TextStyle(font: font, fontSize: 9)),
                            if (purchaseFor.isNotEmpty)
                              pw.Text('مقصد / برای: $purchaseFor',
                                  style: pw.TextStyle(font: font, fontSize: 9)),
                          ]),
                    ),
                  ),

                pw.SizedBox(height: 6),
                pw.Divider(),

                pw.SizedBox(height: 8),

                // جدول فاکتور (ستونها معکوس برای نمایش RTL صحیح)
                pw.Table(
                  border: pw.TableBorder.all(
                      color: pdf.PdfColors.grey800, width: 0.6),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FixedColumnWidth(90),
                    2: const pw.FixedColumnWidth(80),
                    3: const pw.FixedColumnWidth(60),
                    4: const pw.FlexColumnWidth(4),
                    5: const pw.FixedColumnWidth(70),
                    6: const pw.FixedColumnWidth(36),
                  },
                  children: [
                    pw.TableRow(
                        decoration: pw.BoxDecoration(color: headerBg),
                        children: [
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Center(
                                  child:
                                      pw.Text('شرح کالا', style: headerStyle))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Center(
                                  child:
                                      pw.Text('مبلغ کل', style: headerStyle))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Center(
                                  child: pw.Text('بهای واحد',
                                      style: headerStyle))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Center(
                                  child: pw.Text('تعداد', style: headerStyle))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Center(
                                  child:
                                      pw.Text('نام کالا', style: headerStyle))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Center(
                                  child:
                                      pw.Text('کد کالا', style: headerStyle))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Center(
                                  child: pw.Text('ردیف', style: headerStyle))),
                        ]),
                    for (final row in tableRows)
                      pw.TableRow(children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                vertical: 6, horizontal: 8),
                            child: pw.Center(
                                child: pw.Text(row[6], style: cellStyle))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                vertical: 6, horizontal: 8),
                            child: pw.Center(
                                child: pw.Text(row[5], style: cellStyle))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                vertical: 6, horizontal: 8),
                            child: pw.Center(
                                child: pw.Text(row[4], style: cellStyle))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                vertical: 6, horizontal: 8),
                            child: pw.Center(
                                child: pw.Text(row[3], style: cellStyle))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                vertical: 6, horizontal: 8),
                            child: pw.Center(
                                child: pw.Text(row[2], style: cellStyle))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                vertical: 6, horizontal: 8),
                            child: pw.Center(
                                child: pw.Text(row[1], style: cellStyle))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                vertical: 6, horizontal: 6),
                            child: pw.Center(
                                child: pw.Text(row[0], style: cellStyle))),
                      ]),
                  ],
                ),

                pw.SizedBox(height: 12),

                // SUMMARY
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                  pw.Container(
                      width: 320,
                      child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            pw.Row(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('مجموع',
                                      style: pw.TextStyle(
                                          font: font, fontSize: 10)),
                                  pw.Text(_fmtNum(totalVal),
                                      style: pw.TextStyle(
                                          font: font, fontSize: 10))
                                ]),
                            pw.SizedBox(height: 4),
                            pw.Row(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('تخفیف',
                                      style: pw.TextStyle(
                                          font: font, fontSize: 10)),
                                  pw.Text(_fmtNum(discount),
                                      style: pw.TextStyle(
                                          font: font, fontSize: 10))
                                ]),
                            pw.SizedBox(height: 4),
                            pw.Row(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('مالیات',
                                      style: pw.TextStyle(
                                          font: font, fontSize: 10)),
                                  pw.Text(_fmtNum(tax),
                                      style: pw.TextStyle(
                                          font: font, fontSize: 10))
                                ]),
                            pw.SizedBox(height: 4),
                            pw.Row(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('هزینه اضافه',
                                      style: pw.TextStyle(
                                          font: font, fontSize: 10)),
                                  pw.Text(_fmtNum(extra),
                                      style: pw.TextStyle(
                                          font: font, fontSize: 10))
                                ]),
                            pw.Divider(),
                            pw.Row(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('جمع قابل پرداخت',
                                      style: pw.TextStyle(
                                          font: font,
                                          fontSize: 12,
                                          fontWeight: pw.FontWeight.bold)),
                                  pw.Text(_fmtNum(totalVal),
                                      style: pw.TextStyle(
                                          font: font,
                                          fontSize: 12,
                                          fontWeight: pw.FontWeight.bold))
                                ]),
                            pw.SizedBox(height: 6),
                            pw.Text('جمع به حروف: $totalInWords',
                                style: pw.TextStyle(font: font, fontSize: 9)),
                          ])),
                ]),

                pw.SizedBox(height: 18),

                // PAYMENTS
                if (paymentInfo != null &&
                    paymentInfo['payments'] is List &&
                    (paymentInfo['payments'] as List).isNotEmpty)
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Text('پرداخت‌ها',
                            style: pw.TextStyle(
                                font: font,
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 8),
                        pw.Table(
                          border: pw.TableBorder.symmetric(
                              inside: const pw.BorderSide(
                                  color: pdf.PdfColors.grey300, width: 0.5)),
                          columnWidths: {
                            0: const pw.FlexColumnWidth(3),
                            1: const pw.FixedColumnWidth(90),
                            2: const pw.FixedColumnWidth(120)
                          },
                          children: [
                            pw.TableRow(
                                decoration: pw.BoxDecoration(color: headerBg),
                                children: [
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(6),
                                      child: pw.Text('توضیحات',
                                          style: headerStyle,
                                          textAlign: pw.TextAlign.center)),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(6),
                                      child: pw.Text('تاریخ',
                                          style: headerStyle,
                                          textAlign: pw.TextAlign.center)),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(6),
                                      child: pw.Text('نوع و مبلغ',
                                          style: headerStyle,
                                          textAlign: pw.TextAlign.center)),
                                ]),
                            for (final p in List<Map<String, dynamic>>.from(
                                paymentInfo['payments']))
                              pw.TableRow(children: [
                                pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                        vertical: 6, horizontal: 8),
                                    child: pw.Text(p['note']?.toString() ?? '-',
                                        style: cellStyle,
                                        textAlign: pw.TextAlign.center)),
                                pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                        vertical: 6, horizontal: 8),
                                    child: pw.Text(() {
                                      final dateRaw = p['date'];
                                      final millis = (dateRaw is int)
                                          ? dateRaw
                                          : int.tryParse(
                                                  dateRaw?.toString() ?? '') ??
                                              0;
                                      if (millis <= 0) return '-';
                                      final dt =
                                          DateTime.fromMillisecondsSinceEpoch(
                                              millis);
                                      final j = Jalali.fromDateTime(dt);
                                      return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                    }(),
                                        style: cellStyle,
                                        textAlign: pw.TextAlign.center)),
                                pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                        vertical: 6, horizontal: 8),
                                    child: pw.Column(
                                        crossAxisAlignment:
                                            pw.CrossAxisAlignment.end,
                                        children: [
                                          pw.Text(
                                              '${_typeLabel(p['type']?.toString() ?? '')} • ${_fmtNum((p['amount'] is num) ? (p['amount'] as num).toDouble() : double.tryParse(p['amount']?.toString() ?? '') ?? 0)}',
                                              style: cellStyle),
                                          if (p['type'] == 'installment')
                                            pw.Text(
                                                'اقساط: ${p['installments'] ?? '-'} • پیش‌پرداخت: ${p['down_percent'] ?? '-'}%',
                                                style: pw.TextStyle(
                                                    font: font, fontSize: 8)),
                                        ])),
                              ]),
                          ],
                        ),
                        pw.SizedBox(height: 12),
                      ]),

                pw.SizedBox(height: 18),

                // SELLER & SIGNATURE
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                                'نام فروشنده: ${sale['seller_name'] ?? sale['actor_name'] ?? ''}',
                                style: pw.TextStyle(font: font, fontSize: 10)),
                            pw.SizedBox(height: 8),
                            pw.Text('امضاء:',
                                style: pw.TextStyle(font: font, fontSize: 10)),
                            pw.Container(
                                width: 160,
                                height: 40,
                                decoration: pw.BoxDecoration(
                                    border: pw.Border.all(
                                        color: pdf.PdfColors.grey))),
                          ]),
                      pw.Expanded(
                          child: pw.Container(
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text(shopName,
                                  style: pw.TextStyle(
                                      font: font,
                                      fontSize: 12,
                                      fontWeight: pw.FontWeight.bold)))),
                    ]),

                pw.SizedBox(height: 12),

                // شبکه‌های اجتماعی
                if (socialLinks.isNotEmpty)
                  pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: pdf.PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(6)),
                      child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            pw.Text('شبکه‌های اجتماعی:',
                                style: pw.TextStyle(
                                    font: font,
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 6),
                            socialInlineWidget
                          ])),
              ]),
        ),
      ];
    },
  ));

  return pdfDoc.save();
}
