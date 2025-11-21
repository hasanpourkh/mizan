// lib/src/pages/reports/pnl_page.dart
// صفحهٔ گزارش P&L (خلاصه): نمایش اعداد کل (فروش، COGS، سود ناخالص) و نمودار فروش روزانه در بازهٔ انتخابی.
// - از ReportRepository.getPnLSummary و getDailySales استفاده میکند.
// - کامنت فارسی مختصر برای هر بخش.

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/reports/report_repository.dart';
import '../../widgets/charts/chart_widgets.dart';

class PnLPage extends StatefulWidget {
  const PnLPage({super.key});

  @override
  State<PnLPage> createState() => _PnLPageState();
}

class _PnLPageState extends State<PnLPage> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  bool _loading = true;
  Map<String, dynamic> _summary = {
    'total_sales': 0.0,
    'cogs': 0.0,
    'gross_profit': 0.0
  };
  List<Map<String, dynamic>> _daily = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final fromMillis = _from.millisecondsSinceEpoch;
    final toMillis = _to.millisecondsSinceEpoch;
    final sum = await ReportRepository.getPnLSummary(
        fromMillis: fromMillis, toMillis: toMillis);
    final daily = await ReportRepository.getDailySales(
        days: (_to.difference(_from).inDays + 1));
    setState(() {
      _summary = sum;
      _daily = daily;
      _loading = false;
    });
  }

  Future<void> _pickFrom() async {
    final r = await showDatePicker(
        context: context,
        initialDate: _from,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (r != null) setState(() => _from = r);
  }

  Future<void> _pickTo() async {
    final r = await showDatePicker(
        context: context,
        initialDate: _to,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (r != null) setState(() => _to = r);
  }

  String _fmtJalali(DateTime d) {
    final j = Jalali.fromDateTime(d);
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('گزارش P&L'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load)
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(children: [
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                const Text('فروش کل',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text(
                                    (_summary['total_sales'] ?? 0.0)
                                        .toStringAsFixed(2),
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)),
                              ])),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                const Text('بهای تمام‌شده (COGS)',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text(
                                    (_summary['cogs'] ?? 0.0)
                                        .toStringAsFixed(2),
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)),
                              ])),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                const Text('سود ناخالص',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text(
                                    (_summary['gross_profit'] ?? 0.0)
                                        .toStringAsFixed(2),
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)),
                              ])),
                        ]))),
                const SizedBox(height: 12),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(children: [
                          Row(children: [
                            Expanded(
                                child: Row(children: [
                              const Text('از: '),
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                  onPressed: _pickFrom,
                                  child: Text(_fmtJalali(_from)))
                            ])),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Row(children: [
                              const Text('تا: '),
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                  onPressed: _pickTo,
                                  child: Text(_fmtJalali(_to)))
                            ])),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                                onPressed: _load,
                                child: const Text('اعمال فیلتر')),
                          ]),
                          const SizedBox(height: 8),
                          dailySalesLineChart(_daily,
                              lineColor: Colors.deepPurple),
                        ]))),
              ]),
            ),
    );
  }
}
