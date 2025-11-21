// lib/src/menus/sales_menu.dart
// منوهای مربوط به بخش فروش — بروزرسانی شده:
// - حذف آیتم "مدیریت سهامداران" (چون در منوی اشخاص موجود است).
// - آیتم‌های مرجوعی و صفحات حسابداری همچنان باقی‌اند.
// توضیح خیلی خیلی کوتاه: اکنون سهامداران فقط در منوی اشخاص است.

import 'package:flutter/material.dart';

List<Map<String, dynamic>> salesMenu() {
  return [
    {
      'key': 'sales',
      'icon': Icons.point_of_sale,
      'label': 'فروش و درآمد',
      'children': [
        // صفحات فعلی (بدون حذف ساختار قبلی)
        {
          'label': 'فروش جدید',
          'route': '/sales/new',
          'icon': Icons.shopping_cart
        },
        {'label': 'فروش سریع', 'route': '/sales/quick', 'icon': Icons.flash_on},
        {
          'label': 'لیست فروش',
          'route': '/sales/list',
          'icon': Icons.receipt_long
        },

        // صفحات مرتبط با مرجوعی (returns)
        {
          'label': 'برگشت / مرجوعی‌ها',
          'route': '/sales/returns',
          'icon': Icons.undo,
          'hint': 'لیست تمام مرجوعی‌ها و سابقهٔ تعدیل فاکتورها'
        },
        {
          'label': 'ثبت مرجوعی جدید',
          'route': '/sales/returns/new',
          'icon': Icons.keyboard_return,
          'hint': 'مرجوع کردن کامل یا جزئی کالاها از یک فاکتور'
        },

        // صفحات حسابداری مرتبط با سهامداران و سود/زیان (مسیرها ثبت شده‌اند،
        // ولی صفحات گزارش/تعدیل فعلاً placeholder هستند)
        {
          'label': 'سود و زیان سهامداران',
          'route': '/sales/profit-shares',
          'icon': Icons.pie_chart,
          'hint': 'مشاهده و ثبت سهم هر سهامدار از سود فروش'
        },
        {
          'label': 'ثبت/تعدیل سود سهامداران',
          'route': '/sales/profit-adjust',
          'icon': Icons.balance,
          'hint': 'معکوس یا اصلاح تخصیص سود در صورت برگشت کالا'
        },

        // گزارش کلی سود و زیان (P&L)
        {
          'label': 'گزارش سود و زیان (P&L)',
          'route': '/reports/pnl',
          'icon': Icons.bar_chart,
          'hint': 'گزارش دوره‌ای سود و زیان برای سهامداران و کسب‌وکار'
        },
      ]
    }
  ];
}
