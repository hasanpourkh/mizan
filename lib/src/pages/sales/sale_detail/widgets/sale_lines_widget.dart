// lib/src/pages/sales/sale_detail/widgets/sale_lines_widget.dart
// نمایش ردیف‌های فاکتور: نام محصول، تعداد، قیمت واحد، تخفیف خط و جمع خط.
// اصلاحات: مسیر import AppDatabase اصلاح شد (relative صحیح) تا خطاهای build رفع شوند.

import 'package:flutter/material.dart';
import '../../../../core/db/app_database.dart';

class SaleLinesWidget extends StatelessWidget {
  final List<Map<String, dynamic>> lines;
  const SaleLinesWidget({super.key, required this.lines});

  Future<String> _productName(dynamic pid) async {
    try {
      final id = (pid is int) ? pid : int.tryParse(pid?.toString() ?? '') ?? 0;
      final p = await AppDatabase.getProductById(id);
      if (p != null) return p['name']?.toString() ?? 'محصول#$id';
      return 'محصول#$id';
    } catch (_) {
      return pid?.toString() ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const Center(child: Text('هیچ ردیفی ندارد'));
    }
    return ListView.separated(
      itemCount: lines.length,
      separatorBuilder: (_, __) => const Divider(height: 6),
      itemBuilder: (ctx, idx) {
        final ln = lines[idx];
        final qty = (ln['quantity'] ?? ln['qty'])?.toString() ?? '0';
        final price = (ln['unit_price'] ?? ln['price'])?.toString() ?? '0';
        final discount = (ln['discount'] ?? 0).toString();
        final total = ln['line_total']?.toString() ??
            ((double.tryParse(qty.replaceAll(',', '.')) ?? 0.0) *
                    (double.tryParse(price.replaceAll(',', '.')) ?? 0.0))
                .toString();
        final soldBy = ln['sold_by']?.toString() ?? '';
        return FutureBuilder<String>(
            future: _productName(ln['product_id']),
            builder: (c, s) {
              final pname = s.hasData ? s.data! : '...';
              return Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(pname,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                        Text(
                            'جمع: ${double.tryParse(total)?.toStringAsFixed(2) ?? total}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text('تعداد: $qty'),
                        const SizedBox(width: 12),
                        Text('قیمت واحد: $price'),
                        const SizedBox(width: 12),
                        Text('تخفیف: $discount'),
                        const SizedBox(width: 12),
                        if (soldBy.isNotEmpty)
                          Text('فروشنده خط: $soldBy',
                              style: const TextStyle(color: Colors.black54)),
                      ]),
                    ]),
              );
            });
      },
    );
  }
}
