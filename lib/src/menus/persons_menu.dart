// lib/src/menus/persons_menu.dart
// منوهای مربوط به بخش اشخاص (فایل مستقل)
// - شامل آیتم‌های اشخاص است؛ سایدبار این فایل را import می‌کند.

import 'package:flutter/material.dart';

List<Map<String, dynamic>> personsMenu() {
  return [
    {
      'key': 'persons',
      'icon': Icons.people,
      'label': 'اشخاص',
      'children': [
        {
          'label': 'شخص جدید',
          'route': '/persons/new',
          'icon': Icons.person_add
        },
        {
          'label': 'لیست اشخاص',
          'route': '/persons/list',
          'icon': Icons.list_alt
        },
        {
          'label': 'سهامداران',
          'route': '/persons/shareholders',
          'icon': Icons.group
        },
        {
          'label': 'فروشندگان',
          'route': '/persons/sellers',
          'icon': Icons.person_search
        },
      ]
    }
  ];
}
