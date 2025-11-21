// lib/src/menus/products_menu.dart
// منوهای مربوط به بخش محصولات (فایل مستقل)
// - این فایل فقط دادهٔ منو (Map/لیست) را صادر می‌کند تا سایدبار از آن استفاده کند.
// - اگر در آینده بخواهی منوها را گسترش دهی کافی است همین فایل را تغییر دهی.
// کامنت فارسی مختصر دارد.

import 'package:flutter/material.dart';

List<Map<String, dynamic>> productsMenu() {
  return [
    {
      'key': 'products',
      'icon': Icons.inventory_2,
      'label': 'کالاها و خدمات',
      'children': [
        {
          'label': 'افزودن محصول',
          'route': '/products/new',
          'icon': Icons.add_box
        },
        {
          'label': 'افزودن خدمات',
          'route': '/services/new',
          'icon': Icons.miscellaneous_services
        },
        {
          'label': 'لیست محصولات و خدمات',
          'route': '/products/list',
          'icon': Icons.list_alt
        },
        {
          'label': 'بروزرسانی لیست قیمت',
          'route': '/products/update-prices',
          'icon': Icons.update
        },
        {
          'label': 'چاپ بارکد',
          'route': '/products/print-barcode',
          'icon': Icons.qr_code_scanner
        },
      ]
    }
  ];
}
