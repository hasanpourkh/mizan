// lib/src/layouts/main_layout.dart
// لایهٔ اصلی برنامه: هدر با نمایش نام صفحه، دکمهٔ شب/روز، و سایدبار سمت راست که جمع/باز میشود.
// اصلاحات: در حالت موبایل از drawer (leading) استفاده شد تا در RTL سایدبار سمت راست باز شود.
// همچنین ترتیب Row ثابت شد (textDirection: TextDirection.ltr) تا سایدبار همیشه سمت راست قرار گیرد.
// کامنتهای فارسی مختصر برای هر بخش قرار دارد.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/sidebar.dart';
import '../providers/theme_provider.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  final String currentRoute;

  const MainLayout(
      {super.key, required this.child, this.currentRoute = '/home'});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  bool _collapsed = false; // حالت جمعشده برای سایدبار (نمایش بزرگ)
  bool _drawerOpen = false; // برای نمایش در موبایل

  // نگاشت مسیر به عنوان خوانا (هدر)
  final Map<String, String> _titles = {
    '/home': 'داشبورد',
    '/register': 'ثبتنام',
    '/profile': 'پروفایل',
    '/settings': 'تنظیمات',
    '/persons/new': 'شخص جدید',
    // میتوان مسیرهای بیشتر را اینجا اضافه کرد
  };

  String get _pageTitle {
    return _titles[widget.currentRoute] ??
        widget.currentRoute.replaceAll('/', ' ');
  }

  void _navigate(String route) {
    if (route == widget.currentRoute) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool isWide = width >= 900;
    final themeProv = Provider.of<ThemeProvider>(context);

    return Scaffold(
      // AppBar: نمایش عنوان صفحه و دکمهٔ شب/روز
      appBar: AppBar(
        // هدر ثابت بالا: نمایش عنوان صفحه به صورت برجسته
        title: Row(
          children: [
            // در حالت جمع شده، عنوان کوچک تر نشان داده میشود؛ ولی همیشه عنوان در هدر نشان داده شود
            Text(
              _pageTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            // دکمهٔ سوییچ تم
            IconButton(
              tooltip: themeProv.isDark ? 'حالت روز' : 'حالت شب',
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: themeProv.isDark
                    ? const Icon(Icons.wb_sunny, key: ValueKey('sun'))
                    : const Icon(Icons.nightlight_round, key: ValueKey('moon')),
              ),
              onPressed: () => themeProv.toggle(),
            ),
            const SizedBox(width: 8),
            // منوی همبرگری که در موبایل drawer را باز میکند (در RTL leading == راست)
            IconButton(
              tooltip: 'منوی کناری',
              icon: const Icon(Icons.menu),
              onPressed: () {
                if (isWide) {
                  setState(() {
                    _collapsed = !_collapsed;
                  });
                } else {
                  setState(() {
                    _drawerOpen = true;
                  });
                  // باز کردن drawer (leading side) تا در RTL سمت راست باز شود
                  Scaffold.of(context).openDrawer();
                }
              },
            ),
          ],
        ),
        elevation: 1,
      ),

      // در اندازههای کوچک از drawer استفاده میکنیم (در RTL drawer در سمت راست خواهد بود)
      drawer: isWide
          ? null
          : AppSidebar(
              currentRoute: widget.currentRoute,
              collapsed: false,
              onNavigate: (r) {
                Navigator.of(context).pop(); // بستن drawer
                _navigate(r);
              },
            ),

      body: Row(
        // تنظیم textDirection به LTR برای ثابت نگهداشتن ترتیب children:
        // Expanded (محتوا) در سمت چپ کد قرار دارد و سایدبار در انتها -> با LTR همیشه سایدبار سمت راست قرار میگیرد.
        textDirection: TextDirection.ltr,
        children: [
          // محتوای اصلی (سمت چپ در RTL، چون سایدبار سمت راست است)
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: widget.child,
              ),
            ),
          ),

          // سایدبار ثابت در حالات پهن
          if (isWide)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: _collapsed ? 84 : 320,
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                    left: BorderSide(
                        color: Theme.of(context).dividerColor, width: 0.6)),
              ),
              child: Column(
                children: [
                  // کنترل کنندهٔ collapse ساده در بالای سایدبار
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 6),
                    child: Row(
                      children: [
                        const Spacer(),
                        IconButton(
                          tooltip: _collapsed ? 'باز کردن منو' : 'جمع کردن منو',
                          icon: Icon(_collapsed
                              ? Icons.chevron_left
                              : Icons.chevron_right),
                          onPressed: () =>
                              setState(() => _collapsed = !_collapsed),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AppSidebar(
                      currentRoute: widget.currentRoute,
                      collapsed: _collapsed,
                      onNavigate: (r) => _navigate(r),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
