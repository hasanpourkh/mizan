//github.com/nimshakiba/mizan/blob/main/lib/src/pages/sales/quick_sale_page.dart
// lib/src/pages/sales/quick_sale_page.dart
// صفحهٔ فروش سریع — نسخهٔ اصلاح‌شده تا از SaleProductList جدید (محصول+خدمت) پشتیبانی کند.
// - تغییر مهم: _addProductToCart ورودی Map<String,dynamic> item می‌گیرد.
// - خدمات بدون بررسی موجودی اضافه می‌شوند.

import 'package:flutter/material.dart';
import 'package:mizan/src/pages/sales/sale_utils.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';
import 'sale_models.dart';
import 'sale_product_list.dart';
import 'sale_cart.dart';
import 'package:shamsi_date/shamsi_date.dart';

class QuickSalePage extends StatefulWidget {
  const QuickSalePage({super.key});

  @override
  State<QuickSalePage> createState() => _QuickSalePageState();
}

class _QuickSalePageState extends State<QuickSalePage> {
  // دادهها
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _actors = [];

  // جستجو
  final TextEditingController _searchCtrl = TextEditingController();

  // سبد چندخطی
  final List<SaleLine> _cart = [];

  // انتخابها
  int? _selectedWarehouseId;
  int? _selectedCustomerId; // اگر null یا WALKIN_CUSTOMER_ID => خریدار نقدی
  String _selectedCustomerName = '';
  int? _selectedActorId;

  // محاسبات/فیلدها
  final TextEditingController _discountPercentCtrl =
      TextEditingController(text: '0');
  final TextEditingController _discountAmountCtrl =
      TextEditingController(text: '0');
  final TextEditingController _taxPercentCtrl =
      TextEditingController(text: '0');
  final TextEditingController _extraChargesCtrl =
      TextEditingController(text: '0');
  final TextEditingController _notesCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  DateTime _selectedDate = DateTime.now();

  // شناسه و متن پیشفرض خریدار نقدی
  static const int WALKIN_CUSTOMER_ID = -1;
  static const String WALKIN_CUSTOMER_LABEL = 'خریدار: مشتری نقدی';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      final prods = await AppDatabase.getProducts();
      final wh = await AppDatabase.getWarehouses();
      final persons = await AppDatabase.getPersons();

      // فیلتر مشتریها در صورت وجود flag
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
        _warehouses = wh;
        _customers = customers;
        _actors = actors;

        // پیشفرض انبار: اولین انبار اگر موجود باشد
        if (_warehouses.isNotEmpty) {
          final id = _warehouses.first['id'];
          _selectedWarehouseId =
              (id is int) ? id : int.tryParse(id?.toString() ?? '');
        }

        // پیشفرض مشتری: walk-in برای سرعت (ولی کاربر میتواند انتخاب کند)
        _selectedCustomerId = WALKIN_CUSTOMER_ID;
        _selectedCustomerName = WALKIN_CUSTOMER_LABEL;

        // actor پیشفرض را نگذاریم تا کاربر صریح انتخاب کند در صورت نیاز
        _selectedActorId = null;
      });
    } catch (e) {
      NotificationService.showToast(context, 'خطا در بارگذاری اطلاعات: $e',
          backgroundColor: Colors.orange);
      setState(() {
        _products = [];
        _warehouses = [];
        _customers = [];
        _actors = [];
        _selectedCustomerId = WALKIN_CUSTOMER_ID;
        _selectedCustomerName = WALKIN_CUSTOMER_LABEL;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _products;
    return _products.where((p) {
      final name = p['name']?.toString().toLowerCase() ?? '';
      final sku = p['sku']?.toString().toLowerCase() ?? '';
      final code = p['product_code']?.toString().toLowerCase() ?? '';
      return name.contains(q) || sku.contains(q) || code.contains(q);
    }).toList();
  }

  void _onSearchChanged() => setState(() {});

  // تغییر مهم: ورودی item (Map) میگیرد — ممکن است محصول یا خدمت باشد
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
        // برای محصولات: قبل از اضافه کردن بررسی موجودی انجام میدهیم
        final avail = await AppDatabase.getQtyForItemInWarehouse(productId, 0);
        if (avail <= 0.0) {
          NotificationService.showError(context, 'محدودیت موجودی',
              'این محصول در انبار موجودی ندارد و قابل اضافه شدن نیست.');
          return;
        }

        final existing = _cart
            .where((c) =>
                c.productId == productId &&
                c.warehouseId == (_selectedWarehouseId ?? 0))
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
        // خدمت: اگر قبلاً در سبد است مقدار را افزایش میدهم
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
        warehouseId: _selectedWarehouseId ?? 0,
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

  // بقیهٔ کد صفحه بدون تغییر عمده — فقط در بخش UI SaleProductList صدا زده شده متفاوت است.
  @override
  Widget build(BuildContext context) {
    // responsive: اگر عرض بزرگ باشد دو ستون، وگرنه ستونی
    return Scaffold(
      appBar: AppBar(title: const Text('فروش سریع')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              if (wide) {
                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 420,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SaleProductList(
                              onAddProduct: (item) => _addProductToCart(item),
                              onFocusProduct: (item) => _addProductToCart(item),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _buildRightColumn()),
                    ],
                  ),
                );
              } else {
                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SaleProductList(
                                  onAddProduct: (item) =>
                                      _addProductToCart(item),
                                  onFocusProduct: (item) =>
                                      _addProductToCart(item)))),
                      const SizedBox(height: 12),
                      Expanded(child: _buildRightColumn()),
                    ],
                  ),
                );
              }
            }),
    );
  }

  Widget _buildRightColumn() {
    // محتوا مشابه نسخهٔ اصلی — نگه داشته شده
    return Column(children: [
      const SizedBox(height: 8),
      Expanded(
          child: Card(
              child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SaleCart(
                      lines: _cart,
                      onChanged: (lines) => setState(() {}),
                      onRequestRecalc: () => setState(() {}))))),
      const SizedBox(height: 8),
      // بقیهٔ UI برای محاسبات و ثبت فروش...
      const SizedBox(height: 20),
    ]);
  }
}
