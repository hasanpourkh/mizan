// lib/src/pages/persons/persons_list_page.dart
// لیست اشخاص — اضافه شدن اسکرول افقی کنترل‌شدنی و دکمه حذف برای هر ردیف
// - یک ScrollController افقی اضافه شد تا با دکمه‌ها جدول را بدون تغییر سایز پنجره جابه‌جا کنید.
// - _PersonsDataSource اکنون یک callback onDelete دارد و حذف شخص را به والد تحویل میدهد.
// - کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';

class PersonsListPage extends StatefulWidget {
  const PersonsListPage({super.key});

  @override
  State<PersonsListPage> createState() => _PersonsListPageState();
}

enum PersonTab { all, customers, employees, suppliers, withoutTransactions }

class _PersonsListPageState extends State<PersonsListPage> {
  List<Map<String, dynamic>> _allPersons = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _search = '';
  PersonTab _activeTab = PersonTab.all;

  // اسکرول افقی کنترلر
  final ScrollController _hController = ScrollController();

  // انتخاب چندتایی ردیفها
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final list = await AppDatabase.getPersons();
      if (!mounted) return;
      _allPersons = list.map((e) => Map<String, dynamic>.from(e)).toList();
      _applyFilters();
    } catch (e) {
      _allPersons = [];
      _filtered = [];
      NotificationService.showError(
          context, 'خطا', 'بارگذاری اشخاص ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    final q = _search.trim().toLowerCase();
    List<Map<String, dynamic>> cur = List.from(_allPersons);

    switch (_activeTab) {
      case PersonTab.customers:
        cur = cur.where((p) => _flagIsTrue(p['type_customer'])).toList();
        break;
      case PersonTab.employees:
        cur = cur.where((p) => _flagIsTrue(p['type_employee'])).toList();
        break;
      case PersonTab.suppliers:
        cur = cur.where((p) => _flagIsTrue(p['type_supplier'])).toList();
        break;
      case PersonTab.withoutTransactions:
        cur = cur.where((p) {
          final b = (p['balance'] is num)
              ? (p['balance'] as num).toDouble()
              : double.tryParse(p['balance']?.toString() ?? '') ?? 0.0;
          final c = (p['credit_limit'] is num)
              ? (p['credit_limit'] as num).toDouble()
              : double.tryParse(p['credit_limit']?.toString() ?? '') ?? 0.0;
          return b == 0.0 && c == 0.0;
        }).toList();
        break;
      case PersonTab.all:
      default:
        break;
    }

    if (q.isNotEmpty) {
      cur = cur.where((p) {
        final first = (p['first_name'] ?? '').toString().toLowerCase();
        final last = (p['last_name'] ?? '').toString().toLowerCase();
        final display = (p['display_name'] ?? '').toString().toLowerCase();
        final phone = (p['phone'] ?? '').toString().toLowerCase();
        final email = (p['email'] ?? '').toString().toLowerCase();
        final acc = (p['account_code'] ?? '').toString().toLowerCase();
        return first.contains(q) ||
            last.contains(q) ||
            display.contains(q) ||
            phone.contains(q) ||
            email.contains(q) ||
            acc.contains(q);
      }).toList();
    }

    cur.sort((a, b) {
      final aa = a['created_at'];
      final bb = b['created_at'];
      final ai = (aa is int) ? aa : int.tryParse(aa?.toString() ?? '') ?? 0;
      final bi = (bb is int) ? bb : int.tryParse(bb?.toString() ?? '') ?? 0;
      return bi.compareTo(ai);
    });

    _filtered = cur;
  }

  bool _flagIsTrue(dynamic v) {
    if (v == null) return false;
    if (v is int) return v == 1;
    if (v is bool) return v;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  void _setTab(PersonTab t) {
    if (!mounted) return;
    setState(() {
      _activeTab = t;
      _applyFilters();
      _selectedIds.clear();
    });
  }

  void _onSearchChanged(String v) {
    if (!mounted) return;
    setState(() {
      _search = v;
      _applyFilters();
    });
  }

  void _onPrintSelected() {
    if (_selectedIds.isEmpty) {
      NotificationService.showToast(context, 'هیچ رکوردی انتخاب نشده');
      return;
    }
    NotificationService.showToast(
        context, 'چاپ انتخاب‌شده: ${_selectedIds.join(', ')}');
  }

  Future<void> _deletePerson(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف شخص'),
        content: const Text('آیا از حذف این شخص مطمئن هستید؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('لغو')),
          FilledButton.tonal(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await AppDatabase.deletePerson(id);
        NotificationService.showToast(context, 'شخص حذف شد');
        await _load();
      } catch (e) {
        NotificationService.showError(context, 'خطا', 'حذف انجام نشد: $e');
      }
    }
  }

  // اسکرول برنامه‌ای برای جابه‌جایی چپ/راست
  Future<void> _scrollBy(double offset) async {
    try {
      final target = (_hController.offset + offset).clamp(
          _hController.position.minScrollExtent,
          _hController.position.maxScrollExtent);
      await _hController.animateTo(target,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final columns = <DataColumn>[
      const DataColumn(label: Text('انتخاب')),
      const DataColumn(label: Text('کد حساب')),
      const DataColumn(label: Text('نام نمایشی')),
      const DataColumn(label: Text('نام')),
      const DataColumn(label: Text('نام خانوادگی')),
      const DataColumn(label: Text('تلفن')),
      const DataColumn(label: Text('ایمیل')),
      const DataColumn(label: Text('شناسه ملی')),
      const DataColumn(label: Text('کد اقتصادی')),
      const DataColumn(label: Text('آدرس')),
      const DataColumn(label: Text('شهر')),
      const DataColumn(label: Text('استان')),
      const DataColumn(label: Text('کشور')),
      const DataColumn(label: Text('کد پستی')),
      const DataColumn(label: Text('تاریخ تولد')),
      const DataColumn(label: Text('تاریخ عضویت')),
      const DataColumn(label: Text('دسته')),
      const DataColumn(label: Text('حد اعتبار')),
      const DataColumn(label: Text('مانده')),
      const DataColumn(label: Text('نوعها')),
      const DataColumn(label: Text('درصد سهام')),
      const DataColumn(label: Text('ایجاد شده')),
      const DataColumn(label: Text('عملیات')),
    ];

    const estimatedColumnWidth = 140;
    final estimatedWidth = columns.length * estimatedColumnWidth;

    return Scaffold(
      appBar: AppBar(title: const Text('لیست اشخاص')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'افزودن شخص جدید',
        onPressed: () => Navigator.of(context).pushNamed('/persons/new'),
        child: const Icon(Icons.person_add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        ChoiceChip(
                            label: const Text('همه'),
                            selected: _activeTab == PersonTab.all,
                            onSelected: (_) => _setTab(PersonTab.all)),
                        const SizedBox(width: 8),
                        ChoiceChip(
                            label: const Text('مشتریان'),
                            selected: _activeTab == PersonTab.customers,
                            onSelected: (_) => _setTab(PersonTab.customers)),
                        const SizedBox(width: 8),
                        ChoiceChip(
                            label: const Text('کارمندان'),
                            selected: _activeTab == PersonTab.employees,
                            onSelected: (_) => _setTab(PersonTab.employees)),
                        const SizedBox(width: 8),
                        ChoiceChip(
                            label: const Text('تأمین‌کنندگان'),
                            selected: _activeTab == PersonTab.suppliers,
                            onSelected: (_) => _setTab(PersonTab.suppliers)),
                        const SizedBox(width: 8),
                        ChoiceChip(
                            label: const Text('بدون تراکنش'),
                            selected:
                                _activeTab == PersonTab.withoutTransactions,
                            onSelected: (_) =>
                                _setTab(PersonTab.withoutTransactions)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: SizedBox(
                          width: 320,
                          child: TextField(
                              decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  hintText:
                                      'جستجو (نام، ایمیل، تلفن, کد حساب)'),
                              onChanged: _onSearchChanged))),
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                      onPressed: _onPrintSelected,
                      child: const Text('پرینت انتخابها')),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                      onPressed: _load, child: const Text('بارگذاری مجدد')),
                ]),
                const SizedBox(height: 12),
                Expanded(
                  child: Card(
                    child: LayoutBuilder(builder: (ctx, constraints) {
                      final viewportWidth = constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : MediaQuery.of(context).size.width;
                      final tableWidth =
                          math.max(viewportWidth, estimatedWidth.toDouble());
                      final tableHeight = constraints.maxHeight;
                      return Column(children: [
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _hController,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: tableWidth,
                              child: SizedBox(
                                height: tableHeight,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    columns: columns,
                                    rows: List.generate(_filtered.length,
                                        (index) {
                                      final r = _filtered[index];
                                      final idRaw = r['id'];
                                      final id = (idRaw is int)
                                          ? idRaw
                                          : int.tryParse(
                                                  idRaw?.toString() ?? '0') ??
                                              0;
                                      final account =
                                          r['account_code']?.toString() ?? '';
                                      final display =
                                          r['display_name']?.toString() ?? '';
                                      final first =
                                          r['first_name']?.toString() ?? '';
                                      final last =
                                          r['last_name']?.toString() ?? '';
                                      final phone =
                                          r['phone']?.toString() ?? '';
                                      final email =
                                          r['email']?.toString() ?? '';
                                      final national =
                                          r['national_id']?.toString() ?? '';
                                      final economic =
                                          r['economic_code']?.toString() ?? '';
                                      final address =
                                          r['address']?.toString() ?? '';
                                      final city = r['city']?.toString() ?? '';
                                      final province =
                                          r['province']?.toString() ?? '';
                                      final country =
                                          r['country']?.toString() ?? '';
                                      final postal =
                                          r['postal_code']?.toString() ?? '';
                                      final birth =
                                          r['birth_date']?.toString() ?? '';
                                      final membership =
                                          r['membership_date']?.toString() ??
                                              '';
                                      final category =
                                          r['category_id']?.toString() ?? '';
                                      final credit =
                                          r['credit_limit']?.toString() ?? '0';
                                      final balance =
                                          r['balance']?.toString() ?? '0';
                                      final created =
                                          r['created_at']?.toString() ?? '';

                                      final isCustomer =
                                          _flagIsTrue(r['type_customer']);
                                      final isSupplier =
                                          _flagIsTrue(r['type_supplier']);
                                      final isEmployee =
                                          _flagIsTrue(r['type_employee']);
                                      final isShareholder =
                                          _flagIsTrue(r['type_shareholder']);
                                      final sharePercent =
                                          (r['shareholder_percentage'] is num)
                                              ? (r['shareholder_percentage']
                                                      as num)
                                                  .toDouble()
                                                  .toStringAsFixed(2)
                                              : (r['shareholder_percentage']
                                                      ?.toString() ??
                                                  '0');

                                      return DataRow(cells: [
                                        DataCell(Checkbox(
                                            value: _selectedIds.contains(id),
                                            onChanged: (v) {
                                              setState(() {
                                                if (v == true) {
                                                  _selectedIds.add(id);
                                                } else {
                                                  _selectedIds.remove(id);
                                                }
                                              });
                                            })),
                                        DataCell(Text(account)),
                                        DataCell(Text(display)),
                                        DataCell(Text(first)),
                                        DataCell(Text(last)),
                                        DataCell(Text(phone)),
                                        DataCell(Text(email)),
                                        DataCell(Text(national)),
                                        DataCell(Text(economic)),
                                        DataCell(Text(address)),
                                        DataCell(Text(city)),
                                        DataCell(Text(province)),
                                        DataCell(Text(country)),
                                        DataCell(Text(postal)),
                                        DataCell(Text(birth)),
                                        DataCell(Text(membership)),
                                        DataCell(Text(category)),
                                        DataCell(Text(credit)),
                                        DataCell(Text(balance)),
                                        DataCell(Row(children: [
                                          GestureDetector(
                                              onTap: () {
                                                _setTab(PersonTab.customers);
                                              },
                                              child: Chip(
                                                  label: const Text('مشتری'),
                                                  backgroundColor: isCustomer
                                                      ? Colors.green.shade100
                                                      : Colors.grey.shade200,
                                                  avatar: isCustomer
                                                      ? const Icon(Icons.check,
                                                          size: 16)
                                                      : null)),
                                          const SizedBox(width: 6),
                                          GestureDetector(
                                              onTap: () {
                                                _setTab(PersonTab.suppliers);
                                              },
                                              child: Chip(
                                                  label:
                                                      const Text('تأمین‌کننده'),
                                                  backgroundColor: isSupplier
                                                      ? Colors.blue.shade100
                                                      : Colors.grey.shade200,
                                                  avatar: isSupplier
                                                      ? const Icon(Icons.check,
                                                          size: 16)
                                                      : null)),
                                          const SizedBox(width: 6),
                                          GestureDetector(
                                              onTap: () {
                                                _setTab(PersonTab.employees);
                                              },
                                              child: Chip(
                                                  label: const Text('کارمند'),
                                                  backgroundColor: isEmployee
                                                      ? Colors.orange.shade100
                                                      : Colors.grey.shade200,
                                                  avatar: isEmployee
                                                      ? const Icon(Icons.check,
                                                          size: 16)
                                                      : null)),
                                          const SizedBox(width: 6),
                                          GestureDetector(
                                              onTap: () {
                                                _setTab(PersonTab.all);
                                              },
                                              child: Chip(
                                                  label: const Text('سهامدار'),
                                                  backgroundColor: isShareholder
                                                      ? Colors.purple.shade100
                                                      : Colors.grey.shade200,
                                                  avatar: isShareholder
                                                      ? const Icon(Icons.check,
                                                          size: 16)
                                                      : null)),
                                        ])),
                                        DataCell(Text('$sharePercent %')),
                                        DataCell(Text(created)),
                                        DataCell(Row(children: [
                                          IconButton(
                                              icon: const Icon(Icons.edit),
                                              tooltip: 'ویرایش',
                                              onPressed: () {
                                                NotificationService.showToast(
                                                    context,
                                                    'باز کردن ویرایش: $id'); /* TODO: navigate to edit */
                                              }),
                                          IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.red),
                                              tooltip: 'حذف',
                                              onPressed: () =>
                                                  _deletePerson(id)),
                                        ])),
                                      ]);
                                    }),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // کنترل های اسکرول افقی
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed: () => _scrollBy(-300)),
                              const SizedBox(width: 8),
                              IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: () => _scrollBy(300)),
                              const SizedBox(width: 16),
                              Text('با دکمه‌ها جدول را افقی حرکت دهید',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[700])),
                            ],
                          ),
                        ),
                      ]);
                    }),
                  ),
                ),
              ]),
            ),
    );
  }
}
