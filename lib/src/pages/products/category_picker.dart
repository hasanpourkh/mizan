// lib/src/pages/products/category_picker.dart
// ویجت انتخاب/مدیریت دسته‌بندی محصولات (پشتیبانی از ساختار درختی مانند وردپرس)
// - بارگذاری دسته‌ها از AppDatabase.getProductCategories()
// - نمایش درختی ساده (با تو رفتگی برای زیردسته‌ها)
// - انتخاب یک دسته به عنوان parent هنگام ایجاد دسته جدید یا انتخاب دسته محصول
// - امکان افزودن سریع دسته جدید (name + انتخاب parent) و بروزرسانی لیست بدون خروج از صفحه
// - کامنت فارسی مختصر برای هر بخش وجود دارد.

import 'package:flutter/material.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';

typedef OnCategorySelected = void Function(int? categoryId);

class CategoryPicker extends StatefulWidget {
  final int? selectedCategoryId;
  final OnCategorySelected onSelected;
  final bool allowManage; // اگر true اجازهٔ افزودن دسته را میدهد

  const CategoryPicker({
    super.key,
    required this.onSelected,
    this.selectedCategoryId,
    this.allowManage = true,
  });

  @override
  State<CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryNode {
  final int id;
  final String name;
  final int? parentId;
  final List<_CategoryNode> children;

  _CategoryNode({
    required this.id,
    required this.name,
    this.parentId,
    List<_CategoryNode>? children,
  }) : children = children ?? [];
}

class _CategoryPickerState extends State<CategoryPicker> {
  List<Map<String, dynamic>> _flat = [];
  bool _loading = true;
  int? _selectedId;
  final _newCatCtrl = TextEditingController();
  int? _newCatParent;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedCategoryId;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cats = await AppDatabase.getProductCategories();
      if (!mounted) return;
      setState(() {
        _flat = cats.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (e) {
      NotificationService.showToast(context, 'بارگذاری دسته‌ها انجام نشد: $e',
          backgroundColor: Colors.orange);
      setState(() => _flat = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // تبدیل لیست تخت به درختی ساده
  List<_CategoryNode> _buildTree() {
    final Map<int, _CategoryNode> map = {};
    final List<_CategoryNode> roots = [];

    for (final r in _flat) {
      final id = (r['id'] is int)
          ? r['id'] as int
          : int.tryParse(r['id']?.toString() ?? '') ?? 0;
      final name = r['name']?.toString() ?? 'بدون نام';
      final parentRaw = r['parent_id'];
      final parentId = (parentRaw is int)
          ? parentRaw
          : (parentRaw != null ? int.tryParse(parentRaw.toString()) : null);
      map[id] = _CategoryNode(id: id, name: name, parentId: parentId);
    }

    for (final node in map.values) {
      if (node.parentId != null && map.containsKey(node.parentId)) {
        map[node.parentId]!.children.add(node);
      } else {
        roots.add(node);
      }
    }

    // مرتب‌سازی الفبایی برای ثبات نمایش
    void sortRec(List<_CategoryNode> list) {
      list.sort((a, b) => a.name.compareTo(b.name));
      for (final c in list) {
        sortRec(c.children);
      }
    }

    sortRec(roots);
    return roots;
  }

  // به‌روزرسانی selected و فراخوانی callback والد
  void _select(int? id) {
    setState(() => _selectedId = id);
    widget.onSelected(id);
  }

  // فرمت مسیر درختی برای نمایش در انتخاب parent (مثلاً والد > فرزند)
  String _buildPathFor(int id) {
    final Map<int, Map<String, dynamic>> m = {
      for (final r in _flat)
        (r['id'] is int
            ? r['id'] as int
            : int.tryParse(r['id']?.toString() ?? '') ?? 0): r
    };
    final List<String> parts = [];
    int? cur = id;
    while (cur != null && m.containsKey(cur)) {
      final node = m[cur]!;
      parts.insert(0, node['name']?.toString() ?? '');
      final parRaw = node['parent_id'];
      cur = (parRaw is int)
          ? parRaw
          : (parRaw != null ? int.tryParse(parRaw.toString()) : null);
    }
    return parts.join(' › ');
  }

  Future<void> _addNewCategory() async {
    final name = _newCatCtrl.text.trim();
    if (name.isEmpty) {
      NotificationService.showToast(context, 'نام دسته خالی است',
          backgroundColor: Colors.orange);
      return;
    }
    setState(() => _loading = true);
    try {
      final data = {
        'name': name,
        'parent_id': _newCatParent,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };
      await AppDatabase.saveProductCategory(data);
      _newCatCtrl.clear();
      _newCatParent = null;
      await _load();
      NotificationService.showToast(context, 'دسته جدید ذخیره شد',
          backgroundColor: Colors.green);
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'افزودن دسته انجام نشد: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteCategory(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف دسته'),
          content: const Text(
              'آیا از حذف این دسته مطمئن هستید؟ در صورت وجود زیرشاخه‌، ممکن است نیاز به حذف/انتقال آنها باشد.'),
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
      try {
        await AppDatabase.deleteProductCategory(id);
        NotificationService.showToast(context, 'دسته حذف شد');
        await _load();
        if (_selectedId == id) _select(null);
      } catch (e) {
        NotificationService.showError(context, 'خطا', 'حذف دسته انجام نشد: $e');
      }
    }
  }

  Widget _buildNodeRow(_CategoryNode node, int depth) {
    final indent = 8.0 * depth;
    final selected = _selectedId == node.id;
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _select(node.id),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                child: Row(
                  children: [
                    Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                        size: 18, color: selected ? Colors.green : Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                        child:
                            Text(node.name, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ),
          ),
          if (widget.allowManage)
            Row(children: [
              IconButton(
                  tooltip: 'حذف',
                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                  onPressed: () => _deleteCategory(node.id)),
            ]),
        ],
      ),
    );
  }

  List<Widget> _renderTree(List<_CategoryNode> nodes, [int depth = 0]) {
    final out = <Widget>[];
    for (final n in nodes) {
      out.add(_buildNodeRow(n, depth));
      if (n.children.isNotEmpty) {
        out.addAll(_renderTree(n.children, depth + 1));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final tree = _buildTree();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('دسته‌بندی',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _loading
              ? const Center(
                  child: SizedBox(
                      height: 36,
                      width: 36,
                      child: CircularProgressIndicator()))
              : (_flat.isEmpty
                  ? const Text('هیچ دسته‌ای تعریف نشده است.')
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: SingleChildScrollView(
                        child: Column(children: _renderTree(tree)),
                      ),
                    )),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: () {
                  // لغو انتخاب
                  _select(null);
                },
                child: const Text('بدون دسته'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
                onPressed: _load, child: const Text('بارگذاری مجدد')),
          ]),
          if (widget.allowManage) ...[
            const Divider(height: 20),
            const Text('افزودن دسته جدید',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _newCatCtrl,
              decoration: const InputDecoration(
                  labelText: 'نام دسته',
                  border: OutlineInputBorder(),
                  isDense: true),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              initialValue: _newCatParent,
              decoration: const InputDecoration(
                  labelText: 'والد (اختیاری)',
                  isDense: true,
                  border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('- بدون والد -')),
                ..._flat.map((r) {
                  final id = (r['id'] is int)
                      ? r['id'] as int
                      : int.tryParse(r['id']?.toString() ?? '') ?? 0;
                  final label = _buildPathFor(id);
                  return DropdownMenuItem<int?>(value: id, child: Text(label));
                }).toList(),
              ],
              onChanged: (v) => setState(() => _newCatParent = v),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: FilledButton(
                      onPressed: _addNewCategory,
                      child: const Text('افزودن دسته'))),
              const SizedBox(width: 8),
              OutlinedButton(
                  onPressed: () {
                    _newCatCtrl.clear();
                    setState(() => _newCatParent = null);
                  },
                  child: const Text('لغو')),
            ]),
          ],
        ]),
      ),
    );
  }
}
