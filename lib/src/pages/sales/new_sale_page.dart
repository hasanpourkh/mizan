//github.com/hasanpourkh/mizan/blob/main/lib/src/pages/sales/new_sale_page.dart
// lib/src/pages/sales/new_sale_page.dart
// صفحهٔ ثبت فاکتور — کامل و سازگار با منطق موجودی/خدمت و پر کردن خودکار مبلغ پرداخت.
// - اگر آیتم محصول باشد تعداد در انبار بررسی میشود و اگر کافی نباشد پیام خنده‌دار نمایش داده و اضافه نمیشود.
// - خدمات نامحدود هستند و هر تعداد قابل اضافه شدن‌اند.
// - وقتی سبد تغییر کند و کاربر مبلغ پرداخت را دستی تغییر نداده، فیلد پرداخت خودکار با جمع کل پر میشود.
// - توضیح خیلی خیلی کوتاه: فایل کامل صفحه است با کامنت فارسی مختصر.

import 'package:flutter/material.dart';
import 'sale_models.dart';
import 'sale_product_list.dart';
import 'sale_customer_picker.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';
import 'package:intl/intl.dart';

class NewSalePage extends StatefulWidget {
  const NewSalePage({super.key});

  @override
  State<NewSalePage> createState() => _NewSalePageState();
}

class _NewSalePageState extends State<NewSalePage> {
  final List<SaleLine> _cart = [];
  List<Map<String, dynamic>> _actors = [];
  bool _loading = true;
  bool _saving = false;

  int? _selectedCustomerId;
  String _selectedCustomerName = '';
  int? _selectedActorId;
  String _invoiceNo = '';
  String _invoiceTitle = '';

  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _discountPercentCtrl =
      TextEditingController(text: '0');
  final TextEditingController _discountAmountCtrl =
      TextEditingController(text: '0');
  final TextEditingController _taxPercentCtrl =
      TextEditingController(text: '0');
  final TextEditingController _extraChargesCtrl =
      TextEditingController(text: '0');

  // پرداخت
  String _paymentMethod = 'cash';
  final TextEditingController _paidAmountCtrl =
      TextEditingController(text: '0');

  // اگر کاربر پرداخت را دستی ویرایش کند این flag true میشود تا auto-fill غیرفعال شود
  bool _paidManuallyEdited = false;

  final NumberFormat _nf = NumberFormat.decimalPattern();

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      final persons = await AppDatabase.getPersons();
      final actors = persons.where((p) {
        final isSeller = p.containsKey('type_seller') &&
            (p['type_seller'] == 1 ||
                p['type_seller'] == true ||
                (p['type_seller'] is String &&
                    p['type_seller'].toString() == '1'));
        final isEmployee = p.containsKey('type_employee') &&
            (p['type_employee'] == 1 ||
                p['type_employee'] == true ||
                (p['type_employee'] is String &&
                    p['type_employee'].toString() == '1'));
        final isShareholder = p.containsKey('type_shareholder') &&
            (p['type_shareholder'] == 1 ||
                p['type_shareholder'] == true ||
                (p['type_shareholder'] is String &&
                    p['type_shareholder'].toString() == '1'));
        return isSeller || isEmployee || isShareholder;
      }).toList();
      _actors = actors;
      _invoiceNo = await _generateInvoiceNo();
      final bp = await AppDatabase.getBusinessProfile();
      _invoiceTitle = bp?['business_name']?.toString() ?? '';
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'بارگذاری اولیه انجام نشد: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String> _generateInvoiceNo() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      return 'INV$now';
    } catch (_) {
      return 'INV${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // محاسبات سبد
  double get _subtotal {
    double s = 0.0;
    for (final l in _cart) s += (l.unitPrice * l.qty) - (l.discount ?? 0.0);
    return s;
  }

  double get _discountAmount {
    final perc =
        double.tryParse(_discountPercentCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final amt =
        double.tryParse(_discountAmountCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final percAmt = (_subtotal * perc / 100.0);
    return percAmt + amt;
  }

  double get _taxAmount {
    final taxPerc =
        double.tryParse(_taxPercentCtrl.text.replaceAll(',', '.')) ?? 0.0;
    return ((_subtotal - _discountAmount) * taxPerc / 100.0);
  }

  double get _extraCharges {
    return double.tryParse(_extraChargesCtrl.text.replaceAll(',', '.')) ?? 0.0;
  }

  double get _grandTotal {
    return (_subtotal - _discountAmount) + _taxAmount + _extraCharges;
  }

  // وقتی سبد تغییر میکند مقدار فیلد پرداخت خودکار تنظیم میشود مگر کاربر دستی ویرایش کرده باشد
  void _onCartChanged() {
    if (!_paidManuallyEdited) {
      final val = _grandTotal;
      _paidAmountCtrl.text = val.toStringAsFixed(0);
    }
    setState(() {});
  }

  // افزودن آیتم به سبد — از SaleProductList صدا زده می‌شود (قبلا چک موجودی انجام شده است اما دوباره مطمئن میشیم)
  Future<void> _addProductToCart(Map<String, dynamic> item) async {
    try {
      final isService = item['is_service'] == true;
      final productId = (item['id'] is int)
          ? item['id'] as int
          : int.tryParse(item['id']?.toString() ?? '') ?? 0;
      final salePrice = (item['price'] is num)
          ? (item['price'] as num).toDouble()
          : double.tryParse(item['price']?.toString() ?? '') ?? 0.0;
      final purchasePrice = isService
          ? 0.0
          : (item['purchase_price'] is num
              ? (item['purchase_price'] as num).toDouble()
              : double.tryParse(item['purchase_price']?.toString() ?? '') ??
                  0.0);
      final name = item['name']?.toString() ?? '';

      if (!isService) {
        final avail = await AppDatabase.getQtyForItemInWarehouse(productId, 0);
        if (avail <= 0) {
          NotificationService.showToast(
              context, 'موجودی صفره — این کالا انگار تو تعطیلات رفته 😅',
              backgroundColor: Colors.orange);
          return;
        }
        final existing = _cart
            .where((c) =>
                c.productId == productId &&
                c.warehouseId == 0 &&
                c.isService == false)
            .toList();
        if (existing.isNotEmpty) {
          final ex = existing.first;
          final wouldBe = ex.qty + 1.0;
          if (wouldBe > avail) {
            NotificationService.showToast(context,
                'ننه‌جان، بیشتر از موجودی نمیشه اضافه کرد! موجودی: ${_nf.format(avail)}',
                backgroundColor: Colors.orange);
            return;
          }
          ex.qty = wouldBe;
          ex.recalc();
          _onCartChanged();
          return;
        }
      } else {
        final existing = _cart
            .where((c) => c.productId == productId && c.isService == true)
            .toList();
        if (existing.isNotEmpty) {
          final ex = existing.first;
          ex.qty += 1.0;
          ex.recalc();
          _onCartChanged();
          return;
        }
      }

      final line = SaleLine(
        productId: productId,
        productName: name,
        warehouseId: 0,
        qty: 1.0,
        unitPrice: salePrice,
        purchasePrice: purchasePrice,
        isService: isService,
      );
      setState(() => _cart.add(line));
      _onCartChanged();
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'افزودن به سبد انجام نشد: $e');
    }
  }

  // ویرایش یک سطر
  void _updateLine(int idx,
      {double? qty, double? unitPrice, double? discount, String? note}) async {
    final l = _cart[idx];
    if (qty != null) {
      if (!l.isService) {
        final avail =
            await AppDatabase.getQtyForItemInWarehouse(l.productId, 0);
        if (qty > avail) {
          NotificationService.showToast(context,
              'هیجان نکن! موجودی کافی نیست (موجودی: ${_nf.format(avail)})',
              backgroundColor: Colors.orange);
          return;
        }
      }
      l.qty = qty;
    }
    if (unitPrice != null) l.unitPrice = unitPrice;
    if (discount != null) l.discount = discount;
    if (note != null) l.note = note;
    l.recalc();
    _onCartChanged();
  }

  Future<void> _pickCustomer() async {
    final selected = await showCustomerPickerDialog(context);
    if (selected != null) {
      final idRaw = selected['id'];
      final id =
          (idRaw is int) ? idRaw : int.tryParse(idRaw?.toString() ?? '') ?? 0;
      final name = selected['display_name']?.toString() ??
          '${selected['first_name'] ?? ''} ${selected['last_name'] ?? ''}';
      setState(() {
        _selectedCustomerId = id;
        _selectedCustomerName = name;
      });
    }
  }

  // ذخیره فاکتور + ثبت پرداخت (پرداخت به صورت نوشته شده در paidAmount)
  Future<void> _saveInvoice() async {
    if (_cart.isEmpty) {
      NotificationService.showError(context, 'خطا', 'سبد خالی است');
      return;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final saleMap = <String, dynamic>{
        'invoice_no': _invoiceNo,
        'title': _invoiceTitle,
        'customer_id': _selectedCustomerId,
        'actor': _selectedActorId,
        'total': double.parse(_grandTotal.toStringAsFixed(4)),
        'subtotal': double.parse(_subtotal.toStringAsFixed(4)),
        'discount': double.parse(_discountAmount.toStringAsFixed(4)),
        'tax': double.parse(_taxAmount.toStringAsFixed(4)),
        'extra_charges': double.parse(_extraCharges.toStringAsFixed(4)),
        'notes': _notesCtrl.text.trim(),
        'created_at': now,
      };

      final lines = _cart.map((l) => l.toMapForDb()).toList();

      final saleId = await AppDatabase.saveSale(saleMap, lines);

      double paid =
          double.tryParse(_paidAmountCtrl.text.replaceAll(',', '.')) ?? 0.0;
      if (paid <= 0) paid = _grandTotal;

      final paymentInfo = <String, dynamic>{
        'method': _paymentMethod,
        'amount': double.parse(paid.toStringAsFixed(4)),
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'note':
            'پرداخت از طریق ${_paymentMethod == 'cash' ? 'نقد' : _paymentMethod}',
      };

      try {
        await AppDatabase.setSalePaymentInfo(saleId, paymentInfo);
      } catch (_) {}

      NotificationService.showSuccess(
          context, 'ثبت شد', 'فاکتور با موفقیت ثبت شد', onOk: () {
        Navigator.of(context).pushReplacementNamed('/sales/list');
      });
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'ثبت فاکتور انجام نشد: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _discountPercentCtrl.dispose();
    _discountAmountCtrl.dispose();
    _taxPercentCtrl.dispose();
    _extraChargesCtrl.dispose();
    _paidAmountCtrl.dispose();
    super.dispose();
  }

  Widget _buildLeftColumn() {
    return SaleProductList(
      onAddProduct: (item) async {
        await _addProductToCart(item);
      },
      onFocusProduct: (item) {
        // نمایش جزئیات یا کاری که لازم است — در حال حاضر noop
      },
    );
  }

  Widget _buildRightColumn() {
    return SingleChildScrollView(
      child: Column(children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text('شماره فاکتور: $_invoiceNo',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700))),
                    IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () async {
                          final no = await _generateInvoiceNo();
                          setState(() => _invoiceNo = no);
                        })
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: FilledButton.tonal(
                            onPressed: _pickCustomer,
                            child: Text(_selectedCustomerName.isEmpty
                                ? 'انتخاب مشتری'
                                : _selectedCustomerName))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        initialValue: _selectedActorId,
                        decoration: const InputDecoration(
                            labelText: 'عامل (فروشنده)', isDense: true),
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('- انتخاب -')),
                          ..._actors.map((p) {
                            final id = (p['id'] is int)
                                ? p['id'] as int
                                : int.tryParse(p['id']?.toString() ?? '') ?? 0;
                            final name = p['display_name']?.toString() ??
                                '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}';
                            return DropdownMenuItem<int?>(
                                value: id, child: Text(name));
                          }).toList()
                        ],
                        onChanged: (v) => setState(() => _selectedActorId = v),
                      ),
                    ),
                  ]),
                ]),
          ),
        ),

        const SizedBox(height: 12),

        // سبد (هر سطر قابل ویرایش)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('سبد خرید',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (_cart.isEmpty) const Center(child: Text('سبد خالی است')),
                  ...List.generate(_cart.length, (idx) {
                    final l = _cart[idx];
                    return Column(children: [
                      ListTile(
                        title: Text(l.productName),
                        subtitle: Text(
                            'قیمت واحد: ${_nf.format(l.unitPrice)} — خرید: ${_nf.format(l.purchasePrice)}'),
                        trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _cart.removeAt(idx);
                                _onCartChanged();
                              });
                            }),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Row(children: [
                          SizedBox(
                            width: 90,
                            child: TextField(
                              decoration: const InputDecoration(
                                  labelText: 'تعداد', isDense: true),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              controller:
                                  TextEditingController(text: l.qty.toString()),
                              onSubmitted: (v) {
                                final parsed =
                                    double.tryParse(v.replaceAll(',', '.')) ??
                                        l.qty;
                                _updateLine(idx, qty: parsed);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              decoration: const InputDecoration(
                                  labelText: 'قیمت واحد', isDense: true),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              controller: TextEditingController(
                                  text: l.unitPrice.toString()),
                              onSubmitted: (v) {
                                final parsed =
                                    double.tryParse(v.replaceAll(',', '.')) ??
                                        l.unitPrice;
                                _updateLine(idx, unitPrice: parsed);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              decoration: const InputDecoration(
                                  labelText: 'تخفیف', isDense: true),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              controller: TextEditingController(
                                  text: (l.discount ?? 0.0).toString()),
                              onSubmitted: (v) {
                                final parsed =
                                    double.tryParse(v.replaceAll(',', '.')) ??
                                        0.0;
                                _updateLine(idx, discount: parsed);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                  labelText: 'توضیح', isDense: true),
                              controller: TextEditingController(
                                  text: (l.note ?? '').toString()),
                              onSubmitted: (v) => _updateLine(idx, note: v),
                            ),
                          ),
                        ]),
                      ),
                      const Divider(),
                    ]);
                  })
                ]),
          ),
        ),

        const SizedBox(height: 12),

        // تنظیمات تخفیف/مالیات و پرداخت
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('تخفیف و مالیات (کل)',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: _discountPercentCtrl,
                            decoration: const InputDecoration(
                                labelText: 'تخفیف درصدی %', isDense: true),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (_) => _onCartChanged())),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: _discountAmountCtrl,
                            decoration: const InputDecoration(
                                labelText: 'تخفیف مبلغی (ریال)', isDense: true),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (_) => _onCartChanged())),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: _taxPercentCtrl,
                            decoration: const InputDecoration(
                                labelText: 'مالیات %', isDense: true),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (_) => _onCartChanged())),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: _extraChargesCtrl,
                            decoration: const InputDecoration(
                                labelText: 'هزینهٔ اضافی (ریال)',
                                isDense: true),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (_) => _onCartChanged())),
                  ]),
                ]),
          ),
        ),

        const SizedBox(height: 12),

        // پرداخت
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('پرداخت',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: DropdownButtonFormField<String>(
                            value: _paymentMethod,
                            decoration: const InputDecoration(
                                labelText: 'روش پرداخت', isDense: true),
                            items: const [
                              DropdownMenuItem(
                                  value: 'cash', child: Text('نقد')),
                              DropdownMenuItem(
                                  value: 'card', child: Text('کارت')),
                              DropdownMenuItem(
                                  value: 'other', child: Text('سایر')),
                            ],
                            onChanged: (v) =>
                                setState(() => _paymentMethod = v ?? 'cash'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: _paidAmountCtrl,
                            decoration: InputDecoration(
                                labelText:
                                    'مبلغ پرداختی (پیشفرض ${_nf.format(_grandTotal)})',
                                isDense: true),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (v) {
                              setState(() {
                                _paidManuallyEdited = true;
                              });
                            })),
                  ]),
                ]),
          ),
        ),

        const SizedBox(height: 12),

        // خلاصه و دکمه ثبت
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(child: Text('جمع جزء: ${_nf.format(_subtotal)}')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('تخفیف: ${_nf.format(_discountAmount)}')),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: Text('مالیات: ${_nf.format(_taxAmount)}')),
                    const SizedBox(width: 8),
                    Expanded(child: Text('سایر: ${_nf.format(_extraCharges)}')),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: Text('جمع کل: ${_nf.format(_grandTotal)}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: FilledButton.tonal(
                            onPressed: _saving ? null : _saveInvoice,
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Text('ثبت فاکتور و دریافت پرداخت'))),
                    const SizedBox(width: 8),
                    OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _cart.clear();
                            _onCartChanged();
                          });
                        },
                        child: const Text('خالی کردن سبد')),
                  ])
                ]),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('فروش جدید / فاکتور')),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(children: [
              SizedBox(width: 420, child: _buildLeftColumn()),
              const SizedBox(width: 12),
              Expanded(child: _buildRightColumn()),
            ]),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(children: [
              Expanded(child: _buildLeftColumn()),
              const SizedBox(height: 8),
              Expanded(child: _buildRightColumn()),
            ]),
          );
        }
      }),
    );
  }
}
