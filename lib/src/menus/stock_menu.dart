// lib/src/menus/stock_menu.dart
// منوهای مربوط به بخش انبار / موجودی (stock)

import 'package:flutter/material.dart';

List<Map<String, dynamic>> stockMenu() {
  return [
    {
      'key': 'stock',
      'icon': Icons.warehouse,
      'label': 'انبارداری',
      'children': [
        {
          'label': 'انبارها',
          'route': '/stock/warehouses',
          'icon': Icons.location_city
        },
        {
          'label': 'موجودی کالا',
          'route': '/stock/inventory',
          'icon': Icons.inventory
        },
        {
          'label': 'انبارگردانی',
          'route': '/stock/audit',
          'icon': Icons.fact_check
        },
      ]
    }
  ];
}
