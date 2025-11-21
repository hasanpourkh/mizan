// lib/src/pages/sales/sale_models.dart
// مدل‌های ساده مربوط به صفحهٔ فروش — کلاس SaleLine و محاسبات خطی
// تغییر: افزودن فیلد isService تا یک خط بتواند محصول یا خدمت باشد.
// کامنت فارسی مختصر برای هر بخش قرار دارد.

class SaleLine {
  int? productId;
  String productName;
  int warehouseId; // اگر انبار نداشته باشیم 0
  double qty;
  double unitPrice;
  double purchasePrice;
  double discount; // مبلغ ثابت تخفیف در خط
  double lineTotal;

  // جدید: آیا این آیتم یک خدمت است (بدون موجودی)
  final bool isService;

  // مقادیر برای binding در UI (در صورتی که نیاز به کنترلرهای widget باشد، خود UI آن را می‌سازد)
  SaleLine({
    required this.productId,
    required this.productName,
    this.warehouseId = 0,
    this.qty = 1.0,
    this.unitPrice = 0.0,
    this.purchasePrice = 0.0,
    this.discount = 0.0,
    this.isService = false, // پیشفرض: محصول
  }) : lineTotal = (unitPrice * qty) - discount;

  // convenient getter (برای سازگاری با کدهایی که نام isService را می‌خوانند)
  bool get is_service => isService;

  void recalc() {
    lineTotal = (unitPrice * qty) - discount;
  }

  Map<String, dynamic> toMap({int? overrideWarehouseId}) {
    final wid = overrideWarehouseId ?? warehouseId;
    return {
      'product_id': productId,
      'quantity': qty,
      'unit_price': unitPrice,
      'purchase_price': purchasePrice,
      'discount': discount,
      'line_total': lineTotal,
      'warehouse_id': wid,
      'is_service': isService ? 1 : 0,
    };
  }
}
