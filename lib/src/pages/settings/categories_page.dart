// lib/src/pages/settings/categories_page.dart
// صفحهٔ مدیریت دسته‌بندی‌ها (Categories) — افزودن / ویرایش / حذف و تعیین parent
// - اصلاح نوع‌ها: تمام Map/Itemها به صورت Map<String, dynamic> تعریف شده‌اند تا خطاهای null-safety/typing رفع شوند.
// - مقداردهی و castها ایمن انجام می‌شوند.
// - کامنت‌های فارسی مختصر برای هر بخش وجود دارد.

import 'package:flutter/material.dart';
import '../../core/db/database.dart';
import '../../core/notifications/notification_service.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<Map<String, dynamic>> _cats = [];
  bool _loading = true;

  final TextEditingController _nameCtrl = TextEditingController();
  int _parentId = 0;
  int? _editingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // بارگذاری دسته‌ها از دیتابیس
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await AppDatabase.getCategories();
      setState(() {
        _cats = List<Map<String, dynamic>>.from(list);
      });
    } catch (e) {
      _cats = [];
    } finally {
      setState(() => _loading = false);
    }
  }

  // ذخیرهٔ دسته (جدید یا ویرایش)
  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      NotificationService.showError(context, 'خطا', 'نام دسته را وارد کنید');
      return;
    }

    final slug = name.replaceAll(' ', '-').toLowerCase();
    // صریحاً از Map<String, dynamic استفاده میکنیم تا نوع‌ها با دیتابیس سازگار باشند
    final Map<String, dynamic> item = {
      'name': name,
      'slug': slug,
      'parent_id': _parentId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };

    if (_editingId != null) {
      item['id'] = _editingId!;
    }

    try {
      await AppDatabase.saveCategory(item);
      _nameCtrl.clear();
      _parentId = 0;
      _editingId = null;
      await _load();
      NotificationService.showToast(context, 'ذخیره شد');
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'ذخیره انجام نشد: $e');
    }
  }

  // آماده‌سازی فرم برای ویرایش یک رکورد
  Future<void> _edit(Map<String, dynamic> row) async {
    // parse امن id و parent_id به int
    final idRaw = row['id'];
    final int? id =
        (idRaw is int) ? idRaw : (int.tryParse(idRaw?.toString() ?? ''));

    final parentRaw = row['parent_id'];
    final int parentId = (parentRaw is int)
        ? parentRaw
        : (int.tryParse(parentRaw?.toString() ?? '0') ?? 0);

    setState(() {
      _editingId = id;
      _nameCtrl.text = row['name']?.toString() ?? '';
      _parentId = parentId;
    });
  }

  // حذف دسته
  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف دسته'),
          content: const Text(
              'آیا از حذف این دسته اطمینان دارید؟ دسته‌های زیر به والد 0 منتقل می‌شوند.'),
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
        await AppDatabase.deleteCategory(id);
        await _load();
        NotificationService.showToast(context, 'حذف شد');
      } catch (e) {
        NotificationService.showError(context, 'خطا', 'حذف انجام نشد: $e');
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // لیست والدها برای Dropdown با cast ایمن
    final parentItems = <DropdownMenuItem<int>>[
      const DropdownMenuItem<int>(value: 0, child: Text('بدون والد')),
      ..._cats.map((c) {
        final idRaw = c['id'];
        final int id = (idRaw is int)
            ? idRaw
            : (int.tryParse(idRaw?.toString() ?? '0') ?? 0);
        final name = c['name']?.toString() ?? '';
        return DropdownMenuItem<int>(value: id, child: Text(name));
      }).toList(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('دسته‌بندی‌ها')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      // فرم افزودن/ویرایش
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              TextField(
                                controller: _nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'نام دسته',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      initialValue: _parentId,
                                      items: parentItems,
                                      onChanged: (v) =>
                                          setState(() => _parentId = v ?? 0),
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        labelText: 'والد',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.tonal(
                                      onPressed: _save,
                                      child: const Text('ذخیره')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // لیست دسته‌ها
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: _cats.isEmpty
                                ? const Center(
                                    child: Text('دسته‌ای وجود ندارد.'))
                                : ListView(
                                    children: _cats.map((c) {
                                      final id = (c['id'] is int)
                                          ? c['id'] as int
                                          : (int.tryParse(
                                                  c['id']?.toString() ?? '0') ??
                                              0);
                                      final parent = (c['parent_id'] is int)
                                          ? c['parent_id'] as int
                                          : (int.tryParse(
                                                  c['parent_id']?.toString() ??
                                                      '0') ??
                                              0);
                                      final name = c['name']?.toString() ?? '';

                                      return ListTile(
                                        title: Text(name),
                                        subtitle:
                                            Text('id: $id, parent: $parent'),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                                icon: const Icon(Icons.edit),
                                                onPressed: () => _edit(c)),
                                            IconButton(
                                                icon: const Icon(Icons.delete),
                                                onPressed: () => _delete(id)),
                                          ],
                                        ),
                                      );
                                    }).toList(),
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
