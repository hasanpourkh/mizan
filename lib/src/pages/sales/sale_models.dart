// lib/src/pages/sales/sale_models.dart
// مدل‌های سادهٔ مورد نیاز صفحات فروش (SaleLine و کمکی‌ها).
// توضیح خیلی خیلی کوتاه: این فایل فقط یکبار کلاس SaleLine را تعریف می‌کند.
// - فیلدها: productId, productName, warehouseId, qty, unitPrice, purchasePrice,
//   isService, discount (مقداری)، taxPercent، note، lineTotal
// - متدها: recalc() برای محاسبهٔ lineTotal و toMapForDb() برای ذخیره در DB.
// کامنت‌های فارسی مختصر در سراسر فایل قرار دارند.

class SaleLine {
  // شناسه آیتم (product id یا service id)
  int productId;

  // نام محصول/خدمت برای نمایش در UI و ذخیره در سطر فاکتور
  String productName;

  // شناسه انبار (در صورت استفاده)
  int? warehouseId;

  // مقدار (تعداد)
  double qty;

  // قیمت واحد (فروش) — واحد پولی (مثلاً ریال)
  double unitPrice;

  // قیمت خرید (برای محاسبه سود)
  double purchasePrice;

  // آیا این آیتم یک خدمت است یا محصول (برای مدیریت موجودی)
  bool isService;

  // مقدار تخفیف روی کل خط (مقداری) — عدد (ریال)
  double discount;

  // درصد مالیات روی کل خط (یا درصد کلی که روی خط اعمال میشود)
  double taxPercent;

  // توضیحات/یادداشت برای هر سطر
  String note;

  // مقدار محاسبه‌شدهٔ مجموع خط (unitPrice * qty - discount)
  double lineTotal = 0.0;

  // سازندهٔ کلاس
  SaleLine({
    required this.productId,
    required this.productName,
    this.warehouseId,
    this.qty = 1.0,
    this.unitPrice = 0.0,
    this.purchasePrice = 0.0,
    this.isService = false,
    double? discount,
    double? taxPercent,
    String? note,
  })  : discount = discount ?? 0.0,
        taxPercent = taxPercent ?? 0.0,
        note = note ?? '' {
    // محاسبه مقدار مشتق‌شده هنگام ساخت شیء
    recalc();
  }

  // بازمحاسبهٔ مقادیر مشتق‌شده (مثل lineTotal)
  void recalc() {
    final raw = (unitPrice * qty);
    final withDiscount = raw - (discount);
    // اگر نیاز بود مالیات هم جدا ذخیره شود می‌توان آن را اینجا محاسبه کرد.
    lineTotal = double.parse(withDiscount.toStringAsFixed(4));
  }

  // تبدیل خط به Map مناسب برای درج در دیتابیس (ساختار مورد نیاز saveSale)
  Map<String, dynamic> toMapForDb({int? saleId}) {
    return {
      if (saleId != null) 'sale_id': saleId,
      'product_id': productId,
      'name': productName,
      'quantity': qty,
      'unit_price': unitPrice,
      'purchase_price': purchasePrice,
      'discount': discount,
      'tax_percent': taxPercent,
      'line_total': double.parse(lineTotal.toStringAsFixed(4)),
      'is_service': isService ? 1 : 0,
      'note': note,
      'warehouse_id': warehouseId ?? 0,
    };
  }

  // تولید نسخهٔ کپی‌شده با تغییرات دلخواه (کمک برای به‌روزرسانی در UI)
  SaleLine copyWith({
    int? productId,
    String? productName,
    int? warehouseId,
    double? qty,
    double? unitPrice,
    double? purchasePrice,
    bool? isService,
    double? discount,
    double? taxPercent,
    String? note,
  }) {
    return SaleLine(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      warehouseId: warehouseId ?? this.warehouseId,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      isService: isService ?? this.isService,
      discount: discount ?? this.discount,
      taxPercent: taxPercent ?? this.taxPercent,
      note: note ?? this.note,
    );
  }

  @override
  String toString() {
    return 'SaleLine(productId:$productId, name:$productName, qty:$qty, unitPrice:$unitPrice, discount:$discount, tax:$taxPercent, total:$lineTotal)';
  }
}
