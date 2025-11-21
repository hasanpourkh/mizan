// lib/src/pages/sales/profit_shares_page.dart
// صفحهٔ گزارش سود سهامداران: فیلتر بازهٔ زمانی، جدول جزئیات و نمودار توزیع.
// - با ReportRepository.getProfitSharesSummary کار میکند.
// - کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/reports/report_repository.dart';
import '../../widgets/charts/chart_widgets.dart';

class ProfitSharesPage extends StatefulWidget {
  const ProfitSharesPage({super.key});

  @override
  State<ProfitSharesPage> createState() => _ProfitSharesPageState();
}

class _ProfitSharesPageState extends State<ProfitSharesPage> {
  DateTime? _from;
  DateTime? _to;
  bool _loading = true;
  List<Map<String, dynamic>> _shares = [];

  @override
  void initState() {
    super.initState();
    _from = DateTime.now().subtract(const Duration(days: 30));
    _to = DateTime.now();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final fromMillis = _from?.millisecondsSinceEpoch;
    final toMillis = _to?.millisecondsSinceEpoch;
    final rows = await ReportRepository.getProfitSharesSummary(
        fromMillis: fromMillis, toMillis: toMillis);
    if (!mounted) return;
    setState(() {
      _shares = rows;
      _loading = false;
    });
  }

  Future<void> _pickFrom() async {
    final r = await showDatePicker(
        context: context,
        initialDate: _from ?? DateTime.now().subtract(const Duration(days: 30)),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (r != null) setState(() => _from = r);
  }

  Future<void> _pickTo() async {
    final r = await showDatePicker(
        context: context,
        initialDate: _to ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (r != null) setState(() => _to = r);
  }

  String _fmtJalali(DateTime? d) {
    if (d == null) return '';
    final j = Jalali.fromDateTime(d);
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سود سهامداران'),
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
                    padding: const EdgeInsets.all(8.0),
                    child: Row(children: [
                      Expanded(
                          child: Row(children: [
                        const Text('از: '),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                            onPressed: _pickFrom,
                            child: Text(_fmtJalali(_from))),
                      ])),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Row(children: [
                        const Text('تا: '),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                            onPressed: _pickTo, child: Text(_fmtJalali(_to))),
                      ])),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                          onPressed: _load, child: const Text('فیلتر')),
                      const SizedBox(width: 8),
                      OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _from = DateTime.now()
                                  .subtract(const Duration(days: 30));
                              _to = DateTime.now();
                            });
                            _load();
                          },
                          child: const Text('30 روز')),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                    child: Row(children: [
                  Expanded(
                      flex: 1,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(children: [
                            const Text('توزیع سهامداران',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Expanded(child: profitSharesPieChart(_shares)),
                          ]),
                        ),
                      )),
                  const SizedBox(width: 12),
                  Expanded(
                      flex: 1,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('جزئیات',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _shares.isEmpty
                                      ? const Center(
                                          child: Text('اطلاعاتی وجود ندارد'))
                                      : ListView.separated(
                                          itemCount: _shares.length,
                                          separatorBuilder: (_, __) =>
                                              const Divider(height: 6),
                                          itemBuilder: (ctx, idx) {
                                            final s = _shares[idx];
                                            final name =
                                                s['display_name']?.toString() ??
                                                    '-';
                                            final amt = (s['amount'] is num)
                                                ? (s['amount'] as num)
                                                    .toDouble()
                                                : double.tryParse(s['amount']
                                                            ?.toString() ??
                                                        '0') ??
                                                    0.0;
                                            return ListTile(
                                              title: Text(name),
                                              trailing:
                                                  Text(amt.toStringAsFixed(2)),
                                            );
                                          }),
                                )
                              ]),
                        ),
                      )),
                ])),
              ]),
            ),
    );
  }
}
