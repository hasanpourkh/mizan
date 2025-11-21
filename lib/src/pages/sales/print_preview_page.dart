// lib/src/pages/sales/print_preview_page.dart
// صفحهٔ پیش‌نمایش PDF فاکتور قبل از ارسال به چاپ
// - این فایل از buildInvoicePdf در core/print/invoice_printer.dart استفاده میکند.
// - کاربر میتواند از این صفحه، فایل را چاپ یا ذخیره کند.
// - کامنت فارسی مختصر برای هر بخش اضافه شده است.

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart' as pdf;
import '../../core/print/invoice_printer.dart'; // حتماً این import وجود داشته باشد

class PrintPreviewPage extends StatelessWidget {
  final Map<String, dynamic> sale;
  final Map<String, dynamic>? business;
  final pdf.PdfPageFormat pageFormat;

  const PrintPreviewPage({
    super.key,
    required this.sale,
    this.business,
    required this.pageFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('پیش‌نمایش فاکتور'),
        actions: [
          IconButton(
            tooltip: 'ارسال به چاپ',
            icon: const Icon(Icons.print),
            onPressed: () async {
              try {
                final bytes = await buildInvoicePdf(
                    sale: sale, business: business, pageFormat: pageFormat);
                await Printing.layoutPdf(onLayout: (_) async => bytes);
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('خطا در چاپ: $e')));
              }
            },
          ),
        ],
      ),
      body: PdfPreview(
        // محدود کردن حداکثر عرض صفحه به عرض فرمت انتخاب شده
        maxPageWidth: pageFormat.width,
        canChangePageFormat: false,
        allowPrinting: true,
        allowSharing: true,
        build: (format) async {
          // تولید فایل PDF با pageFormat که به سازنده فرستاده شده است
          final bytes = await buildInvoicePdf(
              sale: sale, business: business, pageFormat: pageFormat);
          return bytes;
        },
      ),
    );
  }
}
