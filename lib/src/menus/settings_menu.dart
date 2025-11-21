// lib/src/menus/settings_menu.dart
// منوهای مربوط به بخش تنظیمات (فایل مستقل)
// شامل لینک‌های جداگانه برای دسته‌بندی اشخاص و دسته‌بندی محصولات
import 'package:flutter/material.dart'; // این باید ابتدای فایل باشد

List<Map<String, dynamic>> settingsMenu() {
  return [
    {
      'key': 'settings',
      'icon': Icons.settings,
      'label': 'تنظیمات',
      'children': [
        {
          'label': 'اطلاعات کسب و کار',
          'route': '/settings/business',
          'icon': Icons.business
        },
        {
          'label': 'تنظیمات مالی',
          'route': '/settings/finance',
          'icon': Icons.account_balance_wallet
        },
        {
          'label': 'تنظیمات برنامه',
          'route': '/settings/app',
          'icon': Icons.app_settings_alt
        },
        {
          'label': 'دسته‌بندی اشخاص',
          'route': '/settings/categories-persons',
          'icon': Icons.person_search
        },
        {
          'label': 'دسته‌بندی محصولات',
          'route': '/settings/categories-products',
          'icon': Icons.category
        },
        {
          'label': 'جدول تبدیل نرخ',
          'route': '/settings/exchange',
          'icon': Icons.swap_horiz
        },
        {
          'label': 'مدیریت کاربران',
          'route': '/settings/users',
          'icon': Icons.manage_accounts
        },
        {
          'label': 'تنظیمات چاپ',
          'route': '/settings/print',
          'icon': Icons.print
        },
        {
          'label': 'اعلانات',
          'route': '/settings/notifications',
          'icon': Icons.notifications
        },
      ]
    }
  ];
}
