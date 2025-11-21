// lib/src/pages/settings/categories_products_page.dart
// صفحهٔ مدیریت دسته‌بندی‌های محصولات — طراحی دوست‌داشتنی شبیه وردپرس (ستون چپ: درخت/جستجو، ستون راست: فرم)
// - کلاس اصلی: CategoriesProductsPage (نام یکتا و سازگار با import در app.dart)
// - همهٔ فراخوانی‌های دیتابیس با AppDatabase و با try/catch محافظت شده‌اند.
// - ردیف‌های لیست و درخت dense هستند تا تعداد بیشتری دسته همزمان دیده شوند.
// - کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'package:flutter/material.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';

class CategoriesProductsPage extends StatefulWidget {
  const CategoriesProductsPage({super.key});

  @override
  State<CategoriesProductsPage> createState() => _CategoriesProductsPageState();
}

class _CategoryNode {
  final int id;
  final String name;
  final int parentId;
  final String description;
  final List<_CategoryNode> children = [];

  _CategoryNode({
    required this.id,
    required this.name,
    required this.parentId,
    required this.description,
  });
}

class _CategoriesProductsPageState extends State<CategoriesProductsPage> {
  List<Map<String, dynamic>> _cats = [];
  bool _loading = true;

  // فرم سمت راست
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _parentId = 0;
  int? _editingId;

  // جستجو برای لیست سمت چپ
  final _searchCtrl = TextEditingController();
  String _searchQ = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQ = _searchCtrl.text.trim().toLowerCase());
    });
    _load();
  }

  // بارگذاری دسته‌ها با handling خطا
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await AppDatabase.getProductCategories();
      if (!mounted) return;
      setState(() => _cats = List<Map<String, dynamic>>.from(list));
    } catch (e) {
      if (mounted) {
        NotificationService.showToast(context, 'بارگذاری دسته‌ها انجام نشد: $e',
            backgroundColor: Colors.orange);
        setState(() => _cats = []);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ساخت درخت از لیست تخت
  List<_CategoryNode> _buildTree() {
    final Map<int, _CategoryNode> map = {};
    final roots = <_CategoryNode>[];

    for (final r in _cats) {
      final id = (r['id'] is int)
          ? r['id'] as int
          : int.tryParse(r['id']?.toString() ?? '') ?? 0;
      final name = r['name']?.toString() ?? '';
      final parentRaw = r['parent_id'];
      final parentId = (parentRaw is int)
          ? parentRaw
          : int.tryParse(parentRaw?.toString() ?? '0') ?? 0;
      final desc = r['description']?.toString() ?? '';
      map[id] = _CategoryNode(
          id: id, name: name, parentId: parentId, description: desc);
    }

    for (final node in map.values) {
      if (node.parentId != 0 && map.containsKey(node.parentId)) {
        map[node.parentId]!.children.add(node);
      } else {
        roots.add(node);
      }
    }

    void sortRec(List<_CategoryNode> list) {
      list.sort((a, b) => a.name.compareTo(b.name));
      for (final c in list) {
        sortRec(c.children);
      }
    }

    sortRec(roots);
    return roots;
  }

  // تولید لیست والدها با نمایش مسیر (مثل WP)
  List<DropdownMenuItem<int>> _parentItems() {
    final items = <DropdownMenuItem<int>>[];
    items.add(const DropdownMenuItem<int>(value: 0, child: Text('بدون والد')));
    final Map<int, Map<String, dynamic>> m = {
      for (final r in _cats)
        ((r['id'] is int)
            ? r['id'] as int
            : int.tryParse(r['id']?.toString() ?? '') ?? 0): r
    };

    String buildPath(int id) {
      final parts = <String>[];
      int? cur = id;
      while (cur != null && cur != 0 && m.containsKey(cur)) {
        final node = m[cur]!;
        parts.insert(0, node['name']?.toString() ?? '');
        final parentRaw = node['parent_id'];
        cur = (parentRaw is int)
            ? parentRaw
            : (parentRaw != null ? int.tryParse(parentRaw.toString()) : null);
      }
      return parts.join(' › ');
    }

    final ids = m.keys.toList();
    ids.sort((a, b) => buildPath(a).compareTo(buildPath(b)));

    for (final id in ids) {
      final label = buildPath(id);
      items.add(DropdownMenuItem<int>(value: id, child: Text(label)));
    }
    return items;
  }

  // فیلتر تخت برای جستجو
  List<Map<String, dynamic>> _filteredFlat() {
    if (_searchQ.isEmpty) return _cats;
    return _cats.where((c) {
      final name = c['name']?.toString().toLowerCase() ?? '';
      final desc = c['description']?.toString().toLowerCase() ?? '';
      final slug = c['slug']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQ) ||
          desc.contains(_searchQ) ||
          slug.contains(_searchQ);
    }).toList();
  }

  // ویرایش: مقدارها را در فرم سمت راست قرار میدهد
  void _edit(Map<String, dynamic> row) {
    final idRaw = row['id'];
    final id = (idRaw is int) ? idRaw : int.tryParse(idRaw?.toString() ?? '');
    final parentRaw = row['parent_id'];
    final parentId = (parentRaw is int)
        ? parentRaw
        : int.tryParse(parentRaw?.toString() ?? '0') ?? 0;

    setState(() {
      _editingId = id;
      _nameCtrl.text = row['name']?.toString() ?? '';
      _slugCtrl.text = row['slug']?.toString() ?? '';
      _descCtrl.text = row['description']?.toString() ?? '';
      _parentId = parentId;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      NotificationService.showError(context, 'خطا', 'نام دسته را وارد کنید');
      return;
    }
    final slug = _slugCtrl.text.trim().isEmpty
        ? name.replaceAll(RegExp(r'\s+'), '-').toLowerCase()
        : _slugCtrl.text.trim();
    final item = <String, dynamic>{
      'name': name,
      'slug': slug,
      'description': _descCtrl.text.trim(),
      'parent_id': _parentId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (_editingId != null) item['id'] = _editingId!;
    setState(() => _loading = true);
    try {
      await AppDatabase.saveProductCategory(item);
      // ریست فرم
      _nameCtrl.clear();
      _slugCtrl.clear();
      _descCtrl.clear();
      _parentId = 0;
      _editingId = null;
      await _load();
      NotificationService.showToast(context, 'ذخیره شد');
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'ذخیره انجام نشد: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف دسته'),
          content: const Text(
              'آیا از حذف این دسته اطمینان دارید؟ فرزندان به والد 0 منتقل میشوند.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('لغو')),
            FilledButton.tonal(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('حذف')),
          ],
        ),
      ),
    );
    if (ok == true) {
      setState(() => _loading = true);
      try {
        await AppDatabase.deleteProductCategory(id);
        await _load();
        NotificationService.showToast(context, 'حذف شد');
      } catch (e) {
        NotificationService.showError(context, 'خطا', 'حذف انجام نشد: $e');
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  // نماگر درخت در سمت چپ: بازگشتی
  List<Widget> _renderTreeNodes(List<_CategoryNode> nodes, [int depth = 0]) {
    final out = <Widget>[];
    final flat = _filteredFlat();
    for (final n in nodes) {
      final included = flat.any((f) {
            final id = (f['id'] is int)
                ? f['id'] as int
                : int.tryParse(f['id']?.toString() ?? '') ?? 0;
            return id == n.id;
          }) ||
          flat.any((f) {
            int pid = (f['parent_id'] is int)
                ? f['parent_id'] as int
                : int.tryParse(f['parent_id']?.toString() ?? '0') ?? 0;
            while (pid != 0) {
              if (pid == n.id) return true;
              final p = _cats.firstWhere(
                  (e) =>
                      ((e['id'] is int)
                          ? e['id'] as int
                          : int.tryParse(e['id']?.toString() ?? '') ?? 0) ==
                      pid,
                  orElse: () => {});
              if (p.isEmpty) break;
              pid = (p['parent_id'] is int)
                  ? p['parent_id'] as int
                  : int.tryParse(p['parent_id']?.toString() ?? '0') ?? 0;
            }
            return false;
          });

      if (!included && _searchQ.isNotEmpty) {
        continue;
      }

      out.add(Padding(
        padding: EdgeInsets.only(left: depth * 12.0),
        child: ListTile(
          dense: true,
          minVerticalPadding: 2,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          title: Text(n.name, overflow: TextOverflow.ellipsis),
          subtitle: n.description.isNotEmpty
              ? Text(n.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12))
              : null,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              tooltip: 'ویرایش',
              onPressed: () {
                final src = _cats.firstWhere(
                    (c) =>
                        ((c['id'] is int)
                            ? c['id'] as int
                            : int.tryParse(c['id']?.toString() ?? '') ?? 0) ==
                        n.id,
                    orElse: () => {});
                if (src.isNotEmpty) _edit(src);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              tooltip: 'حذف',
              onPressed: () => _delete(n.id),
            ),
          ]),
        ),
      ));
      if (n.children.isNotEmpty) {
        out.addAll(_renderTreeNodes(n.children, depth + 1));
      }
    }
    return out;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _descCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tree = _buildTree();

    return Scaffold(
      appBar: AppBar(title: const Text('دسته‌بندی‌های محصولات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ستون چپ: جستجو و درخت دسته‌ها (compact)
                      SizedBox(
                        width: 520,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                // جستجو و دکمه‌ها
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _searchCtrl,
                                        decoration: const InputDecoration(
                                          prefixIcon: Icon(Icons.search),
                                          hintText: 'جستجو دسته‌ها...',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.tonal(
                                        onPressed: _load,
                                        child: const Text('بارگذاری')),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // ناحیهٔ قابل اسکرول درخت
                                Expanded(
                                  child: tree.isEmpty
                                      ? const Center(
                                          child: Text(
                                              'هیچ دسته‌ای تعریف نشده است.'))
                                      : Scrollbar(
                                          child: SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: _renderTreeNodes(tree),
                                            ),
                                          ),
                                        ),
                                ),

                                const SizedBox(height: 8),
                                // افزودن سریع دسته
                                Row(children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('افزودن سریع'),
                                      onPressed: () {
                                        setState(() {
                                          _editingId = null;
                                          _nameCtrl.clear();
                                          _slugCtrl.clear();
                                          _descCtrl.clear();
                                          _parentId = 0;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                      icon: const Icon(Icons.reorder),
                                      label: const Text('نمایش مسیرها'),
                                      onPressed: () {
                                        final paths = _cats.map((c) {
                                          final id = (c['id'] is int)
                                              ? c['id'] as int
                                              : int.tryParse(
                                                      c['id']?.toString() ??
                                                          '') ??
                                                  0;
                                          String buildPathLocal(int id2) {
                                            final Map<int, Map<String, dynamic>>
                                                m = {
                                              for (final r in _cats)
                                                ((r['id'] is int)
                                                    ? r['id'] as int
                                                    : int.tryParse(r['id']
                                                                ?.toString() ??
                                                            '') ??
                                                        0): r
                                            };
                                            final parts = <String>[];
                                            int? cur = id2;
                                            while (cur != null &&
                                                cur != 0 &&
                                                m.containsKey(cur)) {
                                              final node = m[cur]!;
                                              parts.insert(
                                                  0,
                                                  node['name']?.toString() ??
                                                      '');
                                              final parentRaw =
                                                  node['parent_id'];
                                              cur = (parentRaw is int)
                                                  ? parentRaw
                                                  : (parentRaw != null
                                                      ? int.tryParse(
                                                          parentRaw.toString())
                                                      : null);
                                            }
                                            return parts.join(' › ');
                                          }

                                          return '${c['name'] ?? ''} — ${buildPathLocal(id)}';
                                        }).join('\n');
                                        showDialog(
                                            context: context,
                                            builder: (c) => AlertDialog(
                                                  title: const Text(
                                                      'مسیر دسته‌ها'),
                                                  content: SizedBox(
                                                      width: 420,
                                                      child:
                                                          SingleChildScrollView(
                                                              child:
                                                                  SelectableText(
                                                                      paths))),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(c)
                                                                .pop(),
                                                        child:
                                                            const Text('بستن'))
                                                  ],
                                                ));
                                      }),
                                ]),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // ستون راست: فرم افزودن/ویرایش (شبیه بخش سمت راست WP)
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _editingId == null
                                      ? 'افزودن دسته جدید'
                                      : 'ویرایش دسته',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _nameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'نام دسته',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _slugCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'slug (آدرس کوتاه)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<int>(
                                  initialValue: _parentId,
                                  decoration: const InputDecoration(
                                    labelText: 'والد',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _parentItems(),
                                  onChanged: (v) =>
                                      setState(() => _parentId = v ?? 0),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _descCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'توضیحات (اختیاری)',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 4,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.tonal(
                                        onPressed: _save,
                                        child: Text(_editingId == null
                                            ? 'افزودن دسته'
                                            : 'بروزرسانی دسته'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _editingId = null;
                                          _nameCtrl.clear();
                                          _slugCtrl.clear();
                                          _descCtrl.clear();
                                          _parentId = 0;
                                        });
                                      },
                                      child: const Text('انصراف'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'توضیح: ساختار درختی شبیه وردپرس است؛ برای ایجاد زیرشاخه، هنگام افزودن/ویرایش والد مناسب انتخاب کنید.',
                                  style: TextStyle(
                                      color: Colors.black54, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
