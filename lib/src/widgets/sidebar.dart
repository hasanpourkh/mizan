// lib/src/widgets/sidebar.dart
// سایدبار: حفظ ساختار قبلی و افزودن نگهداری وضعیت پنل باز بین بازسازی‌ها
// - تغییر کلیدی: _openCategoryKey به صورت static نگهداری میشود تا بعد از ناوبری پنل باز بماند.
// - نمایش نسخهٔ برنامه در فوتر و دکمهٔ «بررسی بروزرسانی» اضافه شد.
// - ساختار منوی اصلی با توابع ../menus/* حفظ شده است.
// کامنتهای فارسی مختصر برای بخشهای جدید قرار داده شده است.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/navigation/app_navigator.dart';
import '../menus/products_menu.dart';
import '../menus/persons_menu.dart';
import '../menus/settings_menu.dart';
import '../menus/sales_menu.dart';
import '../menus/purchases_menu.dart';
import '../menus/stock_menu.dart';
import '../menus/reports_menu.dart';
import '../core/app_info.dart'; // برای نمایش نسخه برنامه

class AppSidebar extends StatefulWidget {
  final String currentRoute;
  final ValueChanged<String>? onNavigate;
  final bool collapsed;

  const AppSidebar(
      {super.key,
      required this.currentRoute,
      this.onNavigate,
      this.collapsed = false});

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  final _storage = const FlutterSecureStorage();
  String? _name;
  String? _email;
  String? _avatarUrl;
  bool _avatarHover = false;

  // کلیدی که نشان میدهد کدام دسته (category) باز است
  // تغییر: static تا بین نمونه‌های جدید ویجت (بعد از ناوبری) حفظ شود.
  static String? _openCategoryKeyStatic;
  String? get _openCategoryKey => _openCategoryKeyStatic;
  set _openCategoryKey(String? v) => _openCategoryKeyStatic = v;

  String? _hoverLabel;

  List<Map<String, dynamic>> _menuStructure = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _buildMenuStructure();
    // همگام‌سازی اولیه: اگر currentRoute متعلق به یک پنل است، آن پنل را باز کن
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _syncOpenWithRoute(widget.currentRoute));
  }

  @override
  void didUpdateWidget(covariant AppSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // اگر مسیر تغییر کرده، پنل باز را بر اساس مسیر جدید همگام کن
    if (oldWidget.currentRoute != widget.currentRoute) {
      _syncOpenWithRoute(widget.currentRoute);
    }
  }

  // ساختار منو (مثل نسخهٔ اصلی) — از توابع موجود در ../menus/* استفاده میکنیم
  void _buildMenuStructure() {
    final base = [
      {
        'key': 'dashboard',
        'icon': Icons.dashboard,
        'label': 'داشبورد',
        'route': '/home',
      },
    ];
    _menuStructure = [];
    _menuStructure.addAll(base);

    // استفاده از توابع کمک‌کننده که در فایل‌های menus تعریف شده‌اند
    try {
      _menuStructure.addAll(personsMenu());
    } catch (_) {}
    try {
      _menuStructure.addAll(productsMenu());
    } catch (_) {}
    try {
      _menuStructure.addAll(salesMenu());
    } catch (_) {}
    try {
      _menuStructure.addAll(purchasesMenu());
    } catch (_) {}
    try {
      _menuStructure.addAll(stockMenu());
    } catch (_) {}
    try {
      _menuStructure.addAll(reportsMenu());
    } catch (_) {}
    try {
      _menuStructure.addAll(settingsMenu());
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    final name = await _storage.read(key: 'profile_name');
    final email = await _storage.read(key: 'profile_email');
    final avatar = await _storage.read(key: 'profile_avatar');
    if (!mounted) return;
    setState(() {
      _name = name;
      _email = email;
      _avatarUrl = avatar;
    });
  }

  void _nav(String route) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(route);
      return;
    }
    // استفاده از AppNavigator که در پروژه تعریف شده — pushReplacement برای جایگزینی صفحه فعلی
    AppNavigator.pushReplacementNamed(route);
  }

  bool _isSelected(String? route) {
    if (route == null) return false;
    return widget.currentRoute == route;
  }

  // Helper: پیدا کردن کلید پنل والد برای یک route مشخص
  String? _findParentKeyForRoute(String route) {
    for (final cat in _menuStructure) {
      final children = cat['children'] as List<dynamic>?;
      if (children != null) {
        for (final ch in children) {
          if (ch['route'] == route) return cat['key']?.toString();
        }
      } else {
        // خودِ دسته یک route مستقیم دارد
        if (cat['route'] == route) return cat['key']?.toString();
      }
    }
    return null;
  }

  // همگام‌سازی وضعیت بازِ پنل با مسیر جاری:
  // - اگر مسیر مربوط به پنلی باشد، آن را باز کن (و سایر پنل‌ها را ببند).
  // - اگر مسیر متعلق به هیچ پنلی نیست، وضعیت فعلی را حفظ کن (به همین دلیل پنل پس از ناوبری باز می‌ماند).
  void _syncOpenWithRoute(String route) {
    final parent = _findParentKeyForRoute(route);
    setState(() {
      if (parent != null) {
        _openCategoryKey = parent;
      } else {
        // حفظ وضعیت فعلی به‌منظور باز ماندن پنل پس از ناوبری به صفحات غیرمرتبط
        _openCategoryKey = _openCategoryKey;
      }
    });
  }

  Widget _menuItem(
      {required IconData icon,
      required String label,
      String? route,
      VoidCallback? onTap}) {
    final selected = _isSelected(route);
    final bgColor = selected
        ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
        : null;
    final fgColor = selected ? Theme.of(context).colorScheme.primary : null;

    if (widget.collapsed) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hoverLabel = label),
        onExit: (_) => setState(() => _hoverLabel = null),
        child: IconButton(
          tooltip: label,
          icon: Icon(icon, color: fgColor),
          onPressed: route != null ? () => _nav(route) : onTap,
        ),
      );
    }

    return Container(
      color: bgColor,
      child: ListTile(
        leading: Icon(icon, color: fgColor),
        title: Text(label, style: TextStyle(color: fgColor)),
        selected: selected,
        selectedTileColor:
            Theme.of(context).colorScheme.primary.withOpacity(0.06),
        onTap: route != null ? () => _nav(route) : onTap,
        dense: true,
        visualDensity: const VisualDensity(vertical: -1),
      ),
    );
  }

  Widget _subItem(
      {required IconData icon, required String label, String? route}) {
    final selected = _isSelected(route);
    final bgColor = selected
        ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
        : null;
    final fgColor = selected ? Theme.of(context).colorScheme.primary : null;

    if (widget.collapsed) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hoverLabel = label),
        onExit: (_) => setState(() => _hoverLabel = null),
        child: IconButton(
          tooltip: label,
          icon: Icon(icon, size: 18, color: fgColor),
          onPressed: route != null ? () => _nav(route) : null,
        ),
      );
    }

    return Container(
      color: bgColor,
      child: ListTile(
        leading: Icon(icon, size: 18, color: fgColor),
        title: Text(label, style: TextStyle(fontSize: 14, color: fgColor)),
        contentPadding: const EdgeInsets.only(right: 18.0, left: 18.0),
        dense: true,
        onTap: route != null ? () => _nav(route) : null,
      ),
    );
  }

  Widget _profileHeader() {
    final avatarRadius = widget.collapsed ? 20.0 : 36.0;
    final name = _name ?? 'کاربر';
    final email = _email ?? 'خوش آمدید';
    final avatar = (_avatarUrl != null && _avatarUrl!.isNotEmpty)
        ? CachedNetworkImageProvider(_avatarUrl!) as ImageProvider
        : null;

    final avatarWidget = MouseRegion(
      onEnter: (_) => setState(() => _avatarHover = true),
      onExit: (_) => setState(() => _avatarHover = false),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: avatar,
            child: avatar == null
                ? Text(name.isNotEmpty ? name.substring(0, 1) : 'M',
                    style: const TextStyle(color: Colors.white))
                : null,
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _avatarHover ? 0.9 : 0.0,
            child: Container(
              width: avatarRadius * 2,
              height: avatarRadius * 2,
              decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(avatarRadius)),
              alignment: Alignment.center,
              child: _avatarHover
                  ? const Icon(Icons.edit, color: Colors.white, size: 18)
                  : const SizedBox.shrink(),
            ),
          )
        ],
      ),
    );

    if (widget.collapsed) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: avatarWidget);
    }

    return InkWell(
      onTap: () => _nav('/profile'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
        child: Row(
          children: [
            avatarWidget,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(email,
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color)),
                  ]),
            ),
            const Icon(Icons.chevron_left, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _categoryItem(Map<String, dynamic> cat) {
    final key = cat['key']?.toString() ?? cat['label'].toString();
    final isOpen = _openCategoryKey == key;
    final children = cat['children'] as List<dynamic>?;

    if (widget.collapsed) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hoverLabel = cat['label']),
        onExit: (_) => setState(() => _hoverLabel = null),
        child: IconButton(
          tooltip: cat['label'],
          icon: Icon(cat['icon'] as IconData),
          onPressed: () {
            showDialog(
              context: context,
              builder: (c) {
                return Directionality(
                  textDirection: TextDirection.rtl,
                  child: AlertDialog(
                    title: Text(cat['label']),
                    content: SingleChildScrollView(
                      child: Column(
                        children: (children ?? []).map<Widget>((ch) {
                          return ListTile(
                            dense: true,
                            leading: Icon(ch['icon'] as IconData),
                            title: Text(ch['label'] as String),
                            onTap: () {
                              Navigator.of(c).pop();
                              if (ch['route'] != null) _nav(ch['route']);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(c).pop(),
                          child: const Text('بستن'))
                    ],
                  ),
                );
              },
            );
          },
        ),
      );
    }

    if (children == null || children.isEmpty) {
      return _menuItem(
          icon: cat['icon'] as IconData,
          label: cat['label'] as String,
          route: cat['route'] as String?);
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey<String>(key),
        initiallyExpanded: isOpen,
        leading: Icon(cat['icon'] as IconData),
        title: Text(cat['label'] as String),
        childrenPadding: const EdgeInsets.only(right: 12.0),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12.0),
        children: (children).map<Widget>((ch) {
          return _subItem(
              icon: ch['icon'] as IconData,
              label: ch['label'] as String,
              route: ch['route'] as String?);
        }).toList(),
        onExpansionChanged: (open) {
          setState(() {
            // single-open behavior: اگر باز شد سایر پنل‌ها بسته شوند
            if (open) {
              _openCategoryKey = key;
            } else {
              if (_openCategoryKey == key) _openCategoryKey = null;
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: widget.collapsed
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _profileHeader(),
                const Divider(),
                ..._menuStructure.map((m) {
                  if (m.containsKey('children')) return _categoryItem(m);
                  return _menuItem(
                      icon: m['icon'] as IconData,
                      label: m['label'] as String,
                      route: m['route'] as String?);
                }).toList(),
                const SizedBox(height: 12),
                if (!widget.collapsed)
                  ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('خروج'),
                      onTap: () => _nav('/login'))
                else
                  IconButton(
                      icon: const Icon(Icons.logout),
                      tooltip: 'خروج',
                      onPressed: () => _nav('/login')),
                const SizedBox(height: 24),
              ],
            ),
          ),
          if (widget.collapsed && _hoverLabel != null)
            Positioned(
              right: 84,
              top: 120,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _hoverLabel != null ? 1.0 : 0.0,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).cardColor,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Text(_hoverLabel!,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          // فوتر ثابت: نسخهٔ برنامه و دکمهٔ بررسی بروزرسانی
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(
                          color: Theme.of(context).dividerColor, width: 0.6))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.collapsed)
                    const Row(children: [
                      Icon(Icons.info_outline, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text('نسخه: ${AppInfo.version}',
                              style: TextStyle(fontSize: 12))),
                    ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => _nav('/settings/update'),
                        child: const Text('بررسی بروزرسانی'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _nav('/settings'),
                      child: const Text('تنظیمات'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
