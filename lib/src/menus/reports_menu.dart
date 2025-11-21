// lib/src/menus/reports_menu.dart
// منوهای مربوط به بخش گزارشات (reports)

import 'package:flutter/material.dart';

List<Map<String, dynamic>> reportsMenu() {
  return [
    {
      'key': 'reports',
      'icon': Icons.bar_chart,
      'label': 'گزارشات',
      'children': [
        {
          'label': 'گزارش فروش',
          'route': '/reports/sales',
          'icon': Icons.show_chart
        },
        {
          'label': 'گزارش خرید',
          'route': '/reports/purchases',
          'icon': Icons.insert_chart
        },
        {
          'label': 'گزارش موجودی',
          'route': '/reports/stock',
          'icon': Icons.storage
        },
      ]
    }
  ];
}
