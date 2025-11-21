// lib/src/pages/debug/db_inspector_page.dart
// صفحهٔ دیباگ برای بررسی دیتابیس: مسیر فایل دیتابیس، تعداد رکوردها و نمونهٔ ردیف‌ها را نمایش می‌دهد.
// کد کامل و مستقل است — فقط فایل را ایجاد کن و اجرا کن.

import 'package:flutter/material.dart';
import '../../core/db/app_database.dart';
import '../../layouts/main_layout.dart';

class DebugDbInspectorPage extends StatefulWidget {
  const DebugDbInspectorPage({super.key});

  @override
  State<DebugDbInspectorPage> createState() => _DebugDbInspectorPageState();
}

class _DebugDbInspectorPageState extends State<DebugDbInspectorPage> {
  bool _loading = true;
  String _dbPath = '';
  int _productsCount = 0;
  int _personsCount = 0;
  int _warehousesCount = 0;
  List<Map<String, dynamic>> _productsSample = [];
  List<Map<String, dynamic>> _personsSample = [];
  List<Map<String, dynamic>> _warehousesSample = [];
  String _lastError = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _lastError = '';
    });

    try {
      final path = await AppDatabase.getCurrentDbFilePath();
      final products = await AppDatabase.getProducts();
      final persons = await AppDatabase.getPersons();
      final warehouses = await AppDatabase.getWarehouses();

      setState(() {
        _dbPath = path ?? 'unknown';
        _productsCount = products.length;
        _personsCount = persons.length;
        _warehousesCount = warehouses.length;
        _productsSample = products.take(10).toList();
        _personsSample = persons.take(10).toList();
        _warehousesSample = warehouses.take(10).toList();
      });

      // print برای مشاهده در کنسول
      print('[DB-Inspector] dbPath=$_dbPath');
      print(
          '[DB-Inspector] products=${products.length}, persons=${persons.length}, warehouses=${warehouses.length}');
      if (products.isNotEmpty) {
        print('[DB-Inspector] sample product[0]=${products.first}');
      }
      if (persons.isNotEmpty) {
        print('[DB-Inspector] sample person[0]=${persons.first}');
      }
      if (warehouses.isNotEmpty) {
        print('[DB-Inspector] sample warehouse[0]=${warehouses.first}');
      }
    } catch (e, st) {
      setState(() {
        _lastError = e.toString();
      });
      print('[DB-Inspector] error: $e\n$st');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _buildSection(
      String title, int count, List<Map<String, dynamic>> sample) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('$title — تعداد: $count',
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            IconButton(
              tooltip: 'پرینت در کنسول',
              icon: const Icon(Icons.print),
              onPressed: () {
                print('--- $title (count=$count) ---');
                for (var r in sample) {
                  print(r);
                }
                if (sample.isEmpty) print('نمونه خالی است');
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('اطلاعات به کنسول چاپ شد')));
              },
            ),
          ]),
          const SizedBox(height: 8),
          if (sample.isEmpty)
            const Text('نمونه‌ای وجود ندارد',
                style: TextStyle(color: Colors.black54))
          else
            SizedBox(
              height: 140,
              child: ListView.separated(
                itemCount: sample.length,
                separatorBuilder: (_, __) => const Divider(height: 6),
                itemBuilder: (ctx, i) {
                  final r = sample[i];
                  return ListTile(
                    dense: true,
                    title: Text(r['name']?.toString() ??
                        r['display_name']?.toString() ??
                        'ردیف'),
                    subtitle: Text(r.toString()),
                    isThreeLine: true,
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(12.0),
            child: ListView(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('اطلاعات فایل دیتابیس',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          SelectableText('path: $_dbPath'),
                          const SizedBox(height: 6),
                          if (_lastError.isNotEmpty) ...[
                            const Text('خطاهای آخر:',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600)),
                            Text(_lastError,
                                style: const TextStyle(color: Colors.red)),
                          ],
                          const SizedBox(height: 8),
                          Row(children: [
                            FilledButton.tonal(
                                onPressed: _refresh, child: const Text('رفرش')),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: () {
                                Navigator.of(context)
                                    .pushReplacementNamed('/products/list');
                              },
                              child: const Text('رفتن به صفحهٔ محصولات'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                                onPressed: () {
                                  Navigator.of(context)
                                      .pushReplacementNamed('/persons/list');
                                },
                                child: const Text('رفتن به صفحهٔ اشخاص')),
                          ])
                        ]),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSection('محصولات (inventory_items)', _productsCount,
                    _productsSample),
                const SizedBox(height: 12),
                _buildSection('اشخاص (persons)', _personsCount, _personsSample),
                const SizedBox(height: 12),
                _buildSection('انبارها (warehouses)', _warehousesCount,
                    _warehousesSample),
              ],
            ),
          );

    // نمایش داخل MainLayout تا منوی کناری و هدر هم داشته باشی
    return MainLayout(
        currentRoute: '/debug/db',
        child: Scaffold(
            appBar: AppBar(title: const Text('DB Inspector')), body: body));
  }
}
