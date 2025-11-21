//github.com/nimshakiba/mizan/blob/main/lib/src/pages/sales/new_sale_page.dart
// lib/src/pages/sales/new_sale_page.dart
// صفحهٔ ثبت فاکتور — نسخهٔ اصلاح‌شده تا از SaleProductList جدید (محصول+خدمت) پشتیبانی کند.
// - تغییر مهم: _addProductToCart اکنون ورودی Map<String,dynamic> item می‌گیرد (محصول یا خدمت)
// - اگر آیتم یک خدمت باشد (is_service==true)، بررسی موجودی انجام نمی‌شود و purchasePrice=0.0 قرار می‌گیرد.
// - کامنت فارسی مختصر جهت راهنمایی در بخش‌های تغییر یافته وجود دارد.

import 'package:flutter/material.dart';
import 'sale_models.dart';
import 'sale_utils.dart';
import 'sale_product_list.dart';
import 'sale_cart.dart';
import 'sale_customer_picker.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';
import 'package:shamsi_date/shamsi_date.dart';

class NewSalePage extends StatefulWidget {
  const NewSalePage({super.key});

  @override
  State<NewSalePage> createState() => _NewSalePageState();
}

class _NewSalePageState extends State<NewSalePage> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _actors = [];

  final List<SaleLine> _cart = [];

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

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      final prods = await AppDatabase.getProducts();
      final persons = await AppDatabase.getPersons();

      // customers
      final hasType = persons.any((p) => p.containsKey('type_customer'));
      final customers = hasType
          ? persons.where((p) {
              final v = p['type_customer'];
              if (v == null) return false;
              if (v is int) return v == 1;
              if (v is bool) return v;
              if (v is String) return v == '1' || v.toLowerCase() == 'true';
              return false;
            }).toList()
          : List<Map<String, dynamic>>.from(persons);

      // actors: فروشندگان/کارمندان/سهامداران
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

      setState(() {
        _products = prods;
        _customers = customers;
        _actors = actors;
      });

      _invoiceNo = await generateInvoiceNo();
      final invTitle = await AppDatabase.getBusinessProfile()
          .then((bp) => bp?['business_name']?.toString() ?? '')
          .catchError((_) => '');
      setState(() => _invoiceTitle = invTitle);
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'بارگذاری انجام نشد: $e');
      setState(() {
        _products = [];
        _customers = [];
        _actors = [];
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  double get _subtotal {
    double s = 0.0;
    for (final l in _cart) s += (l.unitPrice * l.qty) - l.discount;
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

  Future<double> _getAvailableForProduct(int productId) async {
    try {
      return await AppDatabase.getQtyForItemInWarehouse(productId, 0);
    } catch (_) {
      return 0.0;
    }
  }

  // تغییر مهم: ورودی item می‌گیرد (ممکن است محصول یا خدمت باشد)
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
        // برای محصولات: بررسی موجودی
        final avail = await _getAvailableForProduct(productId);
        if (avail <= 0.0) {
          NotificationService.showError(context, 'موجودی محدود',
              'این محصول در انبار موجودی ندارد و قابل اضافه شدن به فاکتور نیست.');
          return;
        }

        final existing = _cart
            .where((c) => c.productId == productId && c.warehouseId == 0)
            .toList();
        if (existing.isNotEmpty) {
          final ex = existing.first;
          final wouldBe = ex.qty + 1.0;
          if (wouldBe > avail) {
            NotificationService.showError(context, 'محدودیت موجودی',
                'امکان افزایش مقدار وجود ندارد. موجودی در انبار: ${avail.toStringAsFixed(2)}');
            return;
          }
          ex.qty = wouldBe;
          ex.recalc();
          setState(() {});
          return;
        }
      } else {
        // خدمت: اگر قبلاً در سبد هست فقط مقدار را افزایش بده
        final existing = _cart
            .where((c) => c.productId == productId && c.isService == true)
            .toList();
        if (existing.isNotEmpty) {
          final ex = existing.first;
          ex.qty += 1;
          ex.recalc();
          setState(() {});
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
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'افزودن به سبد انجام نشد: $e');
    }
  }

  void _onCartChanged(List<SaleLine> lines) {
    setState(() {});
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

  // بقیهٔ متدها و UI بدون تغییر (save invoice و غیره) — برای اختصار همان کد قبلی را نگه دارید.
  // اما در بخش UI جایی که SaleProductList ساخته می‌شود باید آن را به فرم جدید صدا بزنیم:
  @override
  Widget build(BuildContext context) {
    // در عرض کوچک ترتیب عمودی است تا overflow ندهد
    return Scaffold(
      appBar: AppBar(
        title: const Text('فروش جدید / فاکتور'),
        actions: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Center(
                  child: Text('شماره فاکتور: $_invoiceNo',
                      style: const TextStyle(fontWeight: FontWeight.w600)))),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              if (wide) {
                // دو ستون کنار هم
                return Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 420,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SaleProductList(
                                onAddProduct: (item) => _addProductToCart(item),
                                onFocusProduct: (item) {}),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _buildRightColumn(context)),
                    ],
                  ),
                );
              } else {
                // حالت ستونی برای موبایل/پنجره کوچک
                return Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SaleProductList(
                              onAddProduct: (item) => _addProductToCart(item),
                              onFocusProduct: (item) {}),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(child: _buildRightColumn(context)),
                    ],
                  ),
                );
              }
            }),
    );
  }

  // متد _buildRightColumn و بقیه بدون تغییر عملکردی — برای خلاصه‌نویسی آنها را دست نزن
  Widget _buildRightColumn(BuildContext context) {
    // همان rendering قدیمیِ فرم سفارش / سبد / محاسبات به همان شکل قبلی کار میکند.
    // کد کامل را به دلیل طول بالا اینجا نیاوردم؛ فایل کامل اصلی را جایگزین کن و فقط تغییرات افزودن محصول را اعمال کن.
    return Column(children: [
      // اینجا محتوای قبلی _buildRightColumn را قرار بده (همان کد قبلی پروژه).
      // در صورت نیاز من آن را کامل برایت ارسال میکنم.
      const SizedBox(height: 20),
      const Center(child: Text('بخش راست فاکتور (unchanged)')),
    ]);
  }
}
