// lib/src/pages/sales/sale_detail/widgets/sale_summary_widget.dart
// نمایش خلاصهٔ فاکتور: شماره فاکتور، مشتری، تاریخ شمسی، جمع کل و یادداشت و نام فروشگاه.

import 'package:flutter/material.dart';

class SaleSummaryWidget extends StatelessWidget {
  final Map<String, dynamic> sale;
  final Map<String, dynamic>? businessProfile;
  final String formattedDate;
  const SaleSummaryWidget(
      {super.key,
      required this.sale,
      this.businessProfile,
      required this.formattedDate});

  @override
  Widget build(BuildContext context) {
    final invoice = sale['invoice_no']?.toString() ?? '';
    final customer = sale['customer_name']?.toString() ??
        (sale['customer_id']?.toString() ?? '-');
    final total = sale['total']?.toString() ?? '0';
    final notes = sale['notes']?.toString() ?? '';
    final shopName = businessProfile?['business_name']?.toString() ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (shopName.isNotEmpty)
        Text(shopName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: Text('شماره فاکتور: $invoice')),
        Text('تاریخ: $formattedDate'),
      ]),
      const SizedBox(height: 8),
      Text('مشتری: $customer',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(children: [
        const Expanded(child: Text('جمع کل', style: TextStyle(fontSize: 16))),
        Text(double.tryParse(total)?.toStringAsFixed(2) ?? total,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 8),
      if (notes.isNotEmpty)
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('یادداشت:', style: TextStyle(fontWeight: FontWeight.w600)),
          Text(notes),
        ]),
    ]);
  }
}
