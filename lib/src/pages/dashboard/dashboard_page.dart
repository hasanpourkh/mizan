// lib/src/pages/dashboard/dashboard_page.dart
// صفحهٔ داشبورد: نمایش کارت‌های خلاصه و نمودارهای فروش روزانه/هفتگی، نمودار توزیع سود سهامداران و ارزش موجودی.
// - از ReportRepository برای گرفتن داده‌ها استفاده میکند.
// - از chart_widgets برای رسم نمودارها استفاده میکند.
// - کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'package:flutter/material.dart';
import '../../core/reports/report_repository.dart';
import '../../widgets/charts/chart_widgets.dart';
import '../../core/notifications/notification_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _dailySales = [];
  List<Map<String, dynamic>> _weeklySales = [];
  Map<String, dynamic> _inventoryValue = {'inventory_value': 0.0};
  List<Map<String, dynamic>> _profitShares = [];
  int _daysWindow = 14;
  int _weeksWindow = 8;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      _dailySales = await ReportRepository.getDailySales(days: _daysWindow);
      _weeklySales = await ReportRepository.getWeeklySales(weeks: _weeksWindow);
      _inventoryValue = await ReportRepository.getInventoryValue();
      _profitShares = await ReportRepository.getProfitSharesSummary();
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'بارگذاری داشبورد انجام نشد: $e');
      _dailySales = [];
      _weeklySales = [];
      _inventoryValue = {'inventory_value': 0.0};
      _profitShares = [];
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _summaryCards() {
    final invVal = (_inventoryValue['inventory_value'] is num)
        ? (_inventoryValue['inventory_value'] as num).toDouble()
        : double.tryParse(
                _inventoryValue['inventory_value']?.toString() ?? '0') ??
            0.0;
    final recentSales = _dailySales.fold<double>(0.0, (p, e) {
      final v = e['total'];
      return p +
          ((v is num)
              ? v.toDouble()
              : double.tryParse(v?.toString() ?? '0') ?? 0.0);
    });
    final totalShares = _profitShares.fold<double>(0.0, (p, e) {
      final v = e['amount'];
      return p +
          ((v is num)
              ? v.toDouble()
              : double.tryParse(v?.toString() ?? '0') ?? 0.0);
    });

    return Row(children: [
      Expanded(
          child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ارزش موجودی',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(invVal.toStringAsFixed(2),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
        ),
      )),
      const SizedBox(width: 8),
      Expanded(
          child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('فروش ({} روز اخیر)',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(recentSales.toStringAsFixed(2),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
        ),
      )),
      const SizedBox(width: 8),
      Expanded(
          child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('جمع تعدیلات سهامداران',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(totalShares.toStringAsFixed(2),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
        ),
      )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('داشبورد'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'بارگذاری مجدد',
              onPressed: _loadAll)
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(children: [
                _summaryCards(),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(children: [
                    // ستون سمت چپ: نمودار خطی فروش روزانه و نمودار ستونی هفتگی
                    Expanded(
                      flex: 2,
                      child: Column(children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(children: [
                                    const Expanded(
                                        child: Text('فروش روزانه',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700))),
                                    DropdownButton<int>(
                                        value: _daysWindow,
                                        items: const [
                                          DropdownMenuItem(
                                              value: 7, child: Text('7 روز')),
                                          DropdownMenuItem(
                                              value: 14, child: Text('14 روز')),
                                          DropdownMenuItem(
                                              value: 30, child: Text('30 روز')),
                                        ],
                                        onChanged: (v) {
                                          if (v == null) return;
                                          setState(() => _daysWindow = v);
                                          ReportRepository.getDailySales(
                                                  days: v)
                                              .then((d) {
                                            if (mounted) {
                                              setState(() => _dailySales = d);
                                            }
                                          });
                                        })
                                  ]),
                                  const SizedBox(height: 8),
                                  dailySalesLineChart(_dailySales),
                                ]),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(children: [
                                    const Expanded(
                                        child: Text('فروش هفتگی',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700))),
                                    DropdownButton<int>(
                                        value: _weeksWindow,
                                        items: const [
                                          DropdownMenuItem(
                                              value: 6, child: Text('6 هفته')),
                                          DropdownMenuItem(
                                              value: 8, child: Text('8 هفته')),
                                          DropdownMenuItem(
                                              value: 12,
                                              child: Text('12 هفته')),
                                        ],
                                        onChanged: (v) {
                                          if (v == null) return;
                                          setState(() => _weeksWindow = v);
                                          ReportRepository.getWeeklySales(
                                                  weeks: v)
                                              .then((d) {
                                            if (mounted) {
                                              setState(() => _weeklySales = d);
                                            }
                                          });
                                        })
                                  ]),
                                  const SizedBox(height: 8),
                                  weeklySalesBarChart(_weeklySales),
                                ]),
                          ),
                        ),
                      ]),
                    ),

                    const SizedBox(width: 12),

                    // ستون سمت راست: نمودار توزیع سهامداران و چند کارت خلاصه
                    Expanded(
                      flex: 1,
                      child: Column(children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(children: [
                              const Text('توزیع تعدیلات سود سهامداران',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              profitSharesPieChart(_profitShares, height: 220),
                              const SizedBox(height: 8),
                              // لیست کوتاه سهامداران
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxHeight: 160),
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: _profitShares.map((p) {
                                      final name =
                                          p['display_name']?.toString() ?? '-';
                                      final amt = (p['amount'] is num)
                                          ? (p['amount'] as num).toDouble()
                                          : double.tryParse(
                                                  p['amount']?.toString() ??
                                                      '0') ??
                                              0.0;
                                      return ListTile(
                                        dense: true,
                                        title: Text(name),
                                        trailing: Text(amt.toStringAsFixed(2)),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              )
                            ]),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text('ابزارها / گزارش‌ها',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 8),
                                    FilledButton.tonal(
                                        onPressed: () => Navigator.of(context)
                                            .pushNamed('/sales/profit-shares'),
                                        child:
                                            const Text('گزارش سود سهامداران')),
                                    const SizedBox(height: 8),
                                    FilledButton.tonal(
                                        onPressed: () => Navigator.of(context)
                                            .pushNamed('/reports/pnl'),
                                        child: const Text('گزارش P&L')),
                                    const SizedBox(height: 8),
                                    FilledButton.tonal(
                                        onPressed: () => Navigator.of(context)
                                            .pushNamed('/sales/profit-adjust'),
                                        child: const Text('ثبت تعدیل سود')),
                                  ]),
                            ),
                          ),
                        )
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
    );
  }
}
