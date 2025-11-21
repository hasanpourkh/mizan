// lib/src/menus/purchases_menu.dart
// منوهای مربوط به بخش خرید (purchases)

import 'package:flutter/material.dart';

List<Map<String, dynamic>> purchasesMenu() {
  return [
    {
      'key': 'purchases',
      'icon': Icons.shopping_basket,
      'label': 'خرید و تأمین',
      'children': [
        {
          'label': 'سفارش خرید جدید',
          'route': '/purchases/new',
          'icon': Icons.add_shopping_cart
        },
        {
          'label': 'لیست سفارشات خرید',
          'route': '/purchases/list',
          'icon': Icons.list_alt
        },
      ]
    }
  ];
}
