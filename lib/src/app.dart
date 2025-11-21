// lib/src/app.dart
// ورودی اپ: تعریف Theme و تمامی مسیرها (routes).
// تغییرات این نسخه:
// - افزودن مسیر '/products/update-prices' که قبلاً بعضی منوها به آن رجوع می‌کردند.
// - اصلاح مسیر '/purchases/new' تا به کلاس صحیح ReceivePage اشاره کند.
// - ساختار و بقیهٔ routeها بدون تغییر حفظ شده‌اند.
// توضیح خیلی خیلی کوتاه: این فایل را جایگزین کن و اپ را پاکسازی و از اول بیلد کن.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// صفحات auth و عمومی
import 'pages/auth/login/login_page.dart';
import 'pages/auth/register/register_page.dart';
import 'pages/home/home_page.dart';
import 'pages/profile/profile_page.dart';
import 'pages/settings/settings_page.dart';
import 'pages/onboarding/onboarding_wizard.dart';
import 'pages/placeholder_page.dart';
import 'pages/persons/new_person_page.dart';
import 'pages/settings/business_settings_page.dart';
import 'pages/settings/finance_settings_page.dart';
import 'pages/settings/app_settings_page.dart';
import 'pages/settings/categories_persons_page.dart';
import 'pages/settings/categories_products_page.dart';
import 'pages/settings/print_settings_page.dart';
import 'theme/app_theme.dart';
import 'layouts/main_layout.dart';
import 'providers/theme_provider.dart';

// صفحات اشخاص
import 'pages/persons/persons_list_page.dart' as persons_page;
import 'pages/persons/new_person_page.dart' as persons_new_page;
import 'pages/persons/shareholders_page.dart' as persons_shareholders;

// صفحات انبارداری
import 'pages/stock/warehouses_page.dart' as stock_warehouses;
import 'pages/stock/inventory_page.dart' as stock_inventory;

// صفحهٔ ثبت دریافت خرید — کلاس در فایل: ReceivePage
import 'pages/purchases/receive_page.dart' as purchases_receive;

// صفحات محصولات
import 'pages/products/new_product_page.dart' as products_new;
import 'pages/products/products_list_page.dart' as products_list;
import 'pages/products/price_update/price_update_page.dart'
    as products_price_update; // صفحهٔ به‌روزرسانی قیمت‌ها

// صفحات settings:update
import 'pages/settings/update_page.dart' as settings_update;

// صفحات فروش
import 'pages/sales/quick_sale_page.dart' as sales_quick;
import 'pages/sales/new_sale_page.dart' as sales_new;
import 'pages/sales/sales_list_page.dart' as sales_list;

// صفحات مرجوعی
import 'pages/sales/returns/returns_list_page.dart' as sales_returns;
import 'pages/sales/returns/new_return_page.dart' as sales_returns_new;

// صفحات گزارش/داشبورد (در صورت نیاز قابل جایگزینی با صفحات واقعی)
import 'pages/dashboard/dashboard_page.dart' as dashboard_page;
import 'pages/sales/profit_shares_page.dart' as sales_profit_shares;
import 'pages/sales/profit_adjust_page.dart' as sales_profit_adjust;
import 'pages/reports/pnl_page.dart' as reports_pnl;

// AppNavigator برای navigatorKey
import 'core/navigation/app_navigator.dart';

// debug
import 'pages/debug/db_inspector_page.dart' as debug_db;
import 'pages/debug/db_error_page.dart' as debug_db_error;

/// placeholder ساده داخلی
class SimplePlaceholder extends StatelessWidget {
  final String title;
  final String subtitle;
  const SimplePlaceholder({super.key, required this.title, this.subtitle = ''});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(title,
                  style: Theme.of(context).textTheme.titleLarge ??
                      const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54)),
            ]),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  final String? dbInitErrorMessage;
  final bool dbInitialized;

  const MyApp({
    super.key,
    this.initialRoute = '/login',
    this.dbInitErrorMessage,
    this.dbInitialized = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(builder: (context, themeProv, _) {
      const String appFontFamily = 'IRANSansXFaNum';

      return MaterialApp(
        title: 'Mizan - حسابداری',
        debugShowCheckedModeBanner: false,
        navigatorKey: AppNavigator.navigatorKey,
        theme: AppTheme.lightTheme(fontFamily: appFontFamily),
        darkTheme: AppTheme.darkTheme(fontFamily: appFontFamily),
        themeMode: themeProv.mode,
        builder: (context, child) {
          return Directionality(
              textDirection: TextDirection.rtl,
              child: child ?? const SizedBox.shrink());
        },
        initialRoute: initialRoute,
        routes: {
          // صفحهٔ خطای دیتابیس
          '/db-error': (context) => MainLayout(
              child: debug_db_error.DebugDbErrorPage(
                message: dbInitErrorMessage ??
                    'خطای نامشخص در مقداردهی دیتابیس. لطفاً مسیر دیتابیس را بررسی کنید.',
              ),
              currentRoute: '/debug/db-error'),

          // احراز هویت
          '/login': (context) => const LoginPage(),
          '/register': (context) => const RegisterPage(),

          // صفحهٔ اصلی و پروفایل
          '/home': (context) =>
              MainLayout(child: const HomePage(), currentRoute: '/home'),
          '/profile': (context) =>
              MainLayout(child: const ProfilePage(), currentRoute: '/profile'),

          // تنظیمات و ویـزارد
          '/settings': (context) => MainLayout(
              child: const SettingsPage(), currentRoute: '/settings'),
          '/onboarding': (context) => const OnboardingWizard(),

          '/settings/print': (context) => MainLayout(
              child: const PrintSettingsPage(),
              currentRoute: '/settings/print'),
          '/settings/update': (context) => MainLayout(
              child: const settings_update.UpdatePage(),
              currentRoute: '/settings/update'),

          '/settings/business': (context) => MainLayout(
              child: const BusinessSettingsPage(),
              currentRoute: '/settings/business'),
          '/settings/finance': (context) => MainLayout(
              child: const FinanceSettingsPage(),
              currentRoute: '/settings/finance'),
          '/settings/app': (context) => MainLayout(
              child: const AppSettingsPage(), currentRoute: '/settings/app'),
          '/settings/categories-persons': (context) => MainLayout(
              child: const CategoriesPersonsPage(),
              currentRoute: '/settings/categories-persons'),
          '/settings/categories-products': (context) => MainLayout(
              child: const CategoriesProductsPage(),
              currentRoute: '/settings/categories-products'),

          // اشخاص
          '/persons/new': (context) => MainLayout(
              child: persons_new_page.NewPersonPage(),
              currentRoute: '/persons/new'),
          '/persons/list': (context) => MainLayout(
              child: persons_page.PersonsListPage(),
              currentRoute: '/persons/list'),
          '/persons/shareholders': (context) => MainLayout(
              child: persons_shareholders.ShareholdersPage(),
              currentRoute: '/persons/shareholders'),

          // محصولات
          '/products/new': (context) => MainLayout(
              child: products_new.NewProductPage(),
              currentRoute: '/products/new'),
          '/products/list': (context) => MainLayout(
              child: products_list.ProductsListPage(),
              currentRoute: '/products/list'),
          '/products/price-update': (context) => MainLayout(
              child: products_price_update.PriceUpdatePage(),
              currentRoute: '/products/price-update'),

          // اضافه: مسیری که منو به آن اشاره می‌کند (رفع ارور Route)
          '/products/update-prices': (context) => MainLayout(
              child: products_price_update.PriceUpdatePage(),
              currentRoute: '/products/update-prices'),

          // purchases / stock routes
          // اصلاح: مسیر به کلاس صحیح ReceivePage ارجاع داده شد
          '/purchases/new': (context) => MainLayout(
              child: purchases_receive.ReceivePage(),
              currentRoute: '/purchases/new'),

          '/stock/warehouses': (context) => MainLayout(
              child: stock_warehouses.WarehousesPage(),
              currentRoute: '/stock/warehouses'),
          '/stock/inventory': (context) => MainLayout(
              child: stock_inventory.InventoryPage(),
              currentRoute: '/stock/inventory'),

          // sales routes
          '/sales/quick': (context) => MainLayout(
              child: sales_quick.QuickSalePage(), currentRoute: '/sales/quick'),
          '/sales/new': (context) => MainLayout(
              child: sales_new.NewSalePage(), currentRoute: '/sales/new'),
          '/sales/list': (context) => MainLayout(
              child: sales_list.SalesListPage(), currentRoute: '/sales/list'),

          // returns
          '/sales/returns': (context) => MainLayout(
              child: sales_returns.ReturnsListPage(),
              currentRoute: '/sales/returns'),
          '/sales/returns/new': (context) => MainLayout(
              child: sales_returns_new.NewReturnPage(),
              currentRoute: '/sales/returns/new'),

          // گزارش / داشبورد (در صورت نبودن صفحات واقعی، Placeholder نمایش داده میشود)
          '/sales/profit-shares': (context) => MainLayout(
              child: const SimplePlaceholder(
                  title: 'سود و زیان سهامداران',
                  subtitle:
                      'صفحهٔ گزارش/تخصیص سود سهامداران در صورت نبود پیاده‌سازی نمایش داده شده'),
              currentRoute: '/sales/profit-shares'),
          '/sales/profit-adjust': (context) => MainLayout(
              child: const SimplePlaceholder(
                  title: 'تعدیل سود سهامداران',
                  subtitle:
                      'صفحهٔ تعدیل در صورت نبود پیاده‌سازی نمایش داده می‌شود'),
              currentRoute: '/sales/profit-adjust'),
          '/reports/pnl': (context) => MainLayout(
              child: const SimplePlaceholder(
                  title: 'گزارش P&L', subtitle: 'گزارش سود و زیان'),
              currentRoute: '/reports/pnl'),

          // dashboard
          '/dashboard': (context) => MainLayout(
              child: dashboard_page.DashboardPage(),
              currentRoute: '/dashboard'),

          // debug inspector
          '/debug/db': (context) => MainLayout(
              child: debug_db.DebugDbInspectorPage(),
              currentRoute: '/debug/db'),
        },
      );
    });
  }
}
