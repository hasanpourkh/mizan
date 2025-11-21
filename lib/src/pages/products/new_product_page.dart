// lib/src/pages/products/new_product_page.dart
// صفحهٔ افزودن / ویرایش محصول — شامل فیلدهای قیمت خرید، قیمت فروش و نقطهٔ سفارش.
// توضیح خیلی خیلی کوتاه: این نسخه تمام فیلدهای مهم محصول (price, purchase_price, reorder_point) را دارد و با AppDatabase و products_dao سازگار است.
// کامنتهای فارسی مختصر برای هر بخش قرار داده شده‌اند.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mizan/src/core/utils/image_utils.dart' as ImageUtils;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/db/daos/products_dao.dart' as products_dao;
import '../../core/config/config_manager.dart';
import '../../core/utils/image_utils.dart';
import 'package:sqflite/sqlite_api.dart';

class NewProductPage extends StatefulWidget {
  final Map<String, dynamic>? editing;
  const NewProductPage({super.key, this.editing});

  @override
  State<NewProductPage> createState() => _NewProductPageState();
}

class _NewProductPageState extends State<NewProductPage> {
  // کنترلرها و state
  final _productCodeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _barcodeGlobalCtrl = TextEditingController();
  final _barcodeStoreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _initialQtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _purchasePriceCtrl = TextEditingController();
  final _reorderCtrl = TextEditingController();
  bool _autoCode = true;
  bool _loading = true;
  bool _saving = false;
  int? _editingId;

  List<Map<String, dynamic>> _warehouses = [];
  int? _selectedWarehouseId;
  List<Map<String, dynamic>> _units = [];
  int? _selectedUnitId;
  String? _localImagePath;

  // دسته
  int? _categoryId;
  Map<int, String> _categoriesMap = {}; // id -> name

  // موجودی فعلی (برای نمایش در حالت ویرایش)
  double _currentTotalQty = 0.0;
  final _adjustQtyCtrl = TextEditingController();
  final _actorForAdjustCtrl = TextEditingController();
  final _reasonForAdjustCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      final db = await AppDatabase.db;
      await products_dao.createProductsTables(db);
      await products_dao.migrateProductsTables(db);

      _units = await products_dao.getUnits(db);
      _warehouses = await AppDatabase.getWarehouses();
      if (_warehouses.isNotEmpty) {
        _selectedWarehouseId ??= (_warehouses.first['id'] is int)
            ? _warehouses.first['id'] as int
            : int.tryParse(_warehouses.first['id']?.toString() ?? '') ??
                _selectedWarehouseId;
      }

      // categories
      try {
        final cats = await AppDatabase.getProductCategories();
        _categoriesMap = {
          for (final c in cats)
            ((c['id'] is int)
                    ? c['id'] as int
                    : int.tryParse(c['id']?.toString() ?? '') ?? 0):
                (c['name']?.toString() ?? '')
        };
      } catch (_) {
        _categoriesMap = {};
      }

      final editing = widget.editing;
      if (editing != null) {
        _editingId = (editing['id'] is int)
            ? editing['id'] as int
            : int.tryParse(editing['id']?.toString() ?? '');
        _productCodeCtrl.text = editing['product_code']?.toString() ?? '';
        _nameCtrl.text = editing['name']?.toString() ?? '';
        _skuCtrl.text = editing['sku']?.toString() ?? '';
        _barcodeGlobalCtrl.text = editing['barcode_global']?.toString() ??
            editing['barcode']?.toString() ??
            '';
        _barcodeStoreCtrl.text = editing['barcode_store']?.toString() ?? '';
        _descCtrl.text = editing['description']?.toString() ?? '';
        _localImagePath = editing['image_path']?.toString();
        final uid = editing['unit_id'];
        _selectedUnitId = (uid is int)
            ? uid
            : (int.tryParse(uid?.toString() ?? '') ?? _selectedUnitId);
        if (_productCodeCtrl.text.isNotEmpty) _autoCode = false;

        _priceCtrl.text =
            (editing['price'] != null) ? editing['price'].toString() : '';
        _purchasePriceCtrl.text = (editing['purchase_price'] != null)
            ? editing['purchase_price'].toString()
            : '';
        _reorderCtrl.text = (editing['reorder_point'] != null)
            ? editing['reorder_point'].toString()
            : '';

        // خواندن دستهٔ ویرایشی اگر وجود دارد
        final catRaw = editing['category_id'];
        _categoryId = (catRaw is int)
            ? catRaw
            : (catRaw != null ? int.tryParse(catRaw.toString()) : null);

        // خواندن موجودی فعلی (جمع همه انبارها یا انبار انتخابی 0)
        try {
          final qty =
              await AppDatabase.getQtyForItemInWarehouse(_editingId ?? 0, 0);
          _currentTotalQty = qty;
          _adjustQtyCtrl.text = _currentTotalQty.toString();
        } catch (_) {
          _currentTotalQty = 0.0;
          _adjustQtyCtrl.text = '0';
        }
      } else {
        // تولید کد پیشفرض در حالت افزودن جدید
        if (_autoCode) {
          try {
            final db2 = await AppDatabase.db;
            final nxt =
                await products_dao.getCurrentSequence(db2, 'product_code_seq');
            final displaySeq = (nxt == 0) ? 1 : (nxt + 1);
            final codeNumber = 1000 + displaySeq;
            _productCodeCtrl.text = 'p$codeNumber';
          } catch (_) {}
        }
      }
    } catch (e) {
      NotificationService.showToast(context, 'بارگذاری انجام نشد: $e',
          backgroundColor: Colors.orange);
      _units = [];
      _warehouses = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _productCodeCtrl.dispose();
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _barcodeGlobalCtrl.dispose();
    _barcodeStoreCtrl.dispose();
    _descCtrl.dispose();
    _initialQtyCtrl.dispose();
    _priceCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _reorderCtrl.dispose();
    _adjustQtyCtrl.dispose();
    _actorForAdjustCtrl.dispose();
    _reasonForAdjustCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndSaveImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.single.path;
      if (filePath == null) return;

      String? storagePath;
      try {
        final bp = await AppDatabase.getBusinessProfile();
        storagePath = bp?['storage_path']?.toString();
      } catch (_) {
        storagePath = null;
      }
      if (storagePath == null || storagePath.trim().isEmpty) {
        final appDoc = await getApplicationDocumentsDirectory();
        storagePath = p.join(appDoc.path, 'mizan_assets');
      }
      final destDir = p.join(storagePath, 'pictures_db', 'products_pic');
      final ext = p.extension(filePath).toLowerCase();
      final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}$ext';

      final res = await ImageUtils.resizeAndSave(
          srcPath: filePath,
          destDir: destDir,
          fileName: fileName,
          maxSize: 500);
      if (res['path'] != null) {
        setState(() => _localImagePath = res['path'] as String);
        final msg = res['message'] as String?;
        if (msg != null) {
          NotificationService.showToast(context, msg,
              backgroundColor: Colors.orange);
        } else {
          NotificationService.showToast(
              context, 'تصویر با اندازه مناسب ذخیره شد');
        }
      } else {
        NotificationService.showError(
            context, 'خطا', res['message']?.toString() ?? 'خطای ذخیره تصویر');
      }
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'انتخاب تصویر با خطا مواجه شد: $e');
    }
  }

  Future<void> _autoGenerateStoreBarcode() async {
    try {
      final seed = await ConfigManager.get('barcode_store_seed') ?? '';
      final counterStr =
          await ConfigManager.get('barcode_store_counter') ?? '1';
      int counter = int.tryParse(counterStr) ?? 1;
      final generated = '$seed$counter';
      try {
        await ConfigManager.saveConfig(
            {'barcode_store_counter': (counter + 1).toString()});
      } catch (e) {
        NotificationService.showToast(
            context, 'بارکد تولید شد اما ذخیرهٔ کانتر موفق نبود: $generated',
            backgroundColor: Colors.orange);
      }
      setState(() => _barcodeStoreCtrl.text = generated);
      NotificationService.showToast(
          context, 'بارکد فروشگاهی تولید شد: $generated');
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'تولید بارکد انجام نشد: $e');
    }
  }

  // ذخیره محصول
  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      NotificationService.showError(context, 'خطا', 'نام محصول را وارد کنید');
      return;
    }

    setState(() => _saving = true);
    try {
      final db = await AppDatabase.db;
      String productCode = _productCodeCtrl.text.trim();

      if (_autoCode) {
        productCode = await products_dao.generateNextProductCode(db);
      } else {
        await products_dao.getNextSequence(db, 'product_code_seq');
      }

      final priceVal =
          double.tryParse(_priceCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
      final purchaseVal = double.tryParse(
              _purchasePriceCtrl.text.trim().replaceAll(',', '.')) ??
          0.0;
      final reorderVal =
          double.tryParse(_reorderCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;

      final item = <String, dynamic>{
        'product_code': productCode,
        'name': name,
        'sku': _skuCtrl.text.trim(),
        'barcode_global': _barcodeGlobalCtrl.text.trim(),
        'barcode_store': _barcodeStoreCtrl.text.trim(),
        'barcode': _barcodeGlobalCtrl.text.trim().isNotEmpty
            ? _barcodeGlobalCtrl.text.trim()
            : _barcodeStoreCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'image_path': _localImagePath ?? '',
        'unit_id': _selectedUnitId,
        'unit': (_selectedUnitId == null) ? '' : null,
        'price': priceVal,
        'purchase_price': purchaseVal,
        'reorder_point': reorderVal,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'category_id': _categoryId,
      };

      if (_editingId != null) item['id'] = _editingId;

      // old values for audit (optional)
      Map<String, dynamic>? oldValues;
      if (_editingId != null) {
        try {
          final rows = await db.query('inventory_items',
              where: 'id = ?', whereArgs: [_editingId], limit: 1);
          if (rows.isNotEmpty) {
            oldValues = Map<String, dynamic>.from(rows.first);
          }
        } catch (_) {
          oldValues = null;
        }
      }

      final res = await products_dao.saveProduct(db, item);
      int productId = 0;
      if (_editingId != null) {
        productId = _editingId!;
      } else if (res > 0) productId = res;

      // مقدار اولیه
      final qtyText = _initialQtyCtrl.text.trim();
      if (qtyText.isNotEmpty && _selectedWarehouseId != null) {
        final parsed = double.tryParse(qtyText.replaceAll(',', '.')) ?? 0.0;
        if (parsed > 0 && productId > 0) {
          try {
            await AppDatabase.registerStockMovement(
              itemId: productId,
              warehouseId: _selectedWarehouseId!,
              type: 'in',
              qty: parsed,
              reference: null,
              notes: 'مقدار اولیه هنگام ایجاد محصول',
              actor: 'system',
            );
          } catch (e) {
            NotificationService.showToast(
                context, 'مقدار اولیه ثبت نشد (اما محصول ذخیره شد): $e',
                backgroundColor: Colors.orange);
          }
        }
      }

      // درج رکورد تغییرات برای audit (ساده)
      try {
        final createdAt = DateTime.now().millisecondsSinceEpoch;
        await db.insert('product_changes', {
          'product_id': productId,
          'action': _editingId == null ? 'create' : 'update',
          'actor': 'ui',
          'reason': _editingId == null ? 'create product' : 'edit product',
          'old_values': oldValues != null ? jsonEncode(oldValues) : null,
          'new_values': jsonEncode(item),
          'created_at': createdAt,
        });
      } catch (_) {}

      NotificationService.showSuccess(
          context, 'ذخیره شد', 'محصول با موفقیت ذخیره شد', onOk: () {
        Navigator.of(context).pushReplacementNamed('/products/list');
      });
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'ذخیره انجام نشد: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // تنظیم جدید موجودی در حالت ویرایش (افزودن حرکت و رکورد audit)
  Future<void> _applyAdjustQuantity() async {
    if (_editingId == null) {
      NotificationService.showToast(
          context, 'فقط در حالت ویرایش امکان‌پذیر است',
          backgroundColor: Colors.orange);
      return;
    }
    final newVal =
        double.tryParse(_adjustQtyCtrl.text.replaceAll(',', '.')) ?? double.nan;
    if (newVal.isNaN) {
      NotificationService.showError(context, 'خطا', 'مقدار جدید نامعتبر است');
      return;
    }
    final actor = _actorForAdjustCtrl.text.trim();
    final reason = _reasonForAdjustCtrl.text.trim();
    if (reason.isEmpty) {
      NotificationService.showError(
          context, 'خطا', 'دلیل تغییر موجودی را وارد کنید');
      return;
    }

    setState(() => _saving = true);
    try {
      final d = await AppDatabase.db;
      final curr = await AppDatabase.getQtyForItemInWarehouse(_editingId!, 0);
      final delta = newVal - curr;
      if (delta == 0.0) {
        NotificationService.showToast(context, 'مقدار تغییری نکرده است');
        return;
      }

      const type = 'adjustment';
      final qtyToRegister = delta.abs();

      await AppDatabase.registerStockMovement(
        itemId: _editingId!,
        warehouseId: 0,
        type: type,
        qty: qtyToRegister,
        reference: 'adjust_by_ui:$_editingId',
        notes: 'Adjust by UI — reason: $reason',
        actor: actor.isNotEmpty ? actor : 'ui_user',
      );

      // درج رکورد audit ساده
      final oldValuesRows = await d.query('inventory_items',
          where: 'id = ?', whereArgs: [_editingId], limit: 1);
      final oldValues = oldValuesRows.isNotEmpty
          ? Map<String, dynamic>.from(oldValuesRows.first)
          : null;

      final createdAt = DateTime.now().millisecondsSinceEpoch;
      final newValues = Map<String, dynamic>.from(oldValues ?? {});
      newValues['computed_total_qty'] = newVal;

      try {
        await d.insert('product_changes', {
          'product_id': _editingId,
          'action': 'adjust',
          'actor': actor.isNotEmpty ? actor : 'ui_user',
          'reason': reason,
          'old_values': oldValues != null ? jsonEncode(oldValues) : null,
          'new_values': jsonEncode(newValues),
          'created_at': createdAt,
        });
      } catch (_) {}

      NotificationService.showSuccess(context, 'ثبت شد', 'تغییر موجودی ثبت شد',
          onOk: () {
        setState(() {
          _currentTotalQty = newVal;
        });
      });
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'تنظیم موجودی انجام نشد: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // compact category dialog (همان منطق قبلی)
  Future<void> _showCompactCategoryDialog() async {
    try {
      final cats = await AppDatabase.getProductCategories();
      if (!mounted) return;

      final items = cats.map((c) {
        final id = (c['id'] is int)
            ? c['id'] as int
            : int.tryParse(c['id']?.toString() ?? '') ?? 0;
        final name = c['name']?.toString() ?? '';
        return {'id': id, 'name': name, 'parent_id': c['parent_id']};
      }).toList();

      final selected = await showDialog<int?>(
        context: context,
        builder: (c) {
          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520, maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 10.0),
                    child: Row(
                      children: [
                        const Expanded(
                            child: Text('دستهبندیها',
                                style: TextStyle(fontWeight: FontWeight.w700))),
                        IconButton(
                            onPressed: () => Navigator.of(c).pop(null),
                            icon: const Icon(Icons.close, size: 20)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(
                            child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text('هیچ دستهای تعریف نشده است')))
                        : Scrollbar(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                final it = items[idx];
                                return ListTile(
                                  dense: true,
                                  minVerticalPadding: 2,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12.0, vertical: 4.0),
                                  title: Text(it['name'] ?? '',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14)),
                                  trailing: (_categoryId != null &&
                                          _categoryId == it['id'])
                                      ? const Icon(Icons.check,
                                          color: Colors.green, size: 18)
                                      : null,
                                  onTap: () {
                                    Navigator.of(c).pop(it['id'] as int);
                                  },
                                );
                              },
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: () => Navigator.of(c).pop(null),
                              child: const Text('لغو'))),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                          onPressed: () => Navigator.of(c).pop(0),
                          child: const Text('بدون دسته')),
                    ]),
                  )
                ],
              ),
            ),
          );
        },
      );

      if (selected != null) {
        setState(() {
          _categoryId = (selected == 0) ? null : selected;
        });
        NotificationService.showToast(
            context, selected == 0 ? 'بدون دسته انتخاب شد' : 'دسته انتخاب شد',
            backgroundColor: Colors.green);
      }
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'بارگذاری دستهها با خطا مواجه شد: $e');
    }
  }

  String _categoryDisplayText() {
    if (_categoryId == null) return 'بدون دسته';
    return _categoriesMap[_categoryId] ?? '#$_categoryId';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_editingId == null ? 'افزودن محصول' : 'ویرایش محصول')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ListView(children: [
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(children: [
                              Expanded(
                                  child: Column(children: [
                                Row(children: [
                                  Expanded(
                                      child: TextField(
                                          controller: _productCodeCtrl,
                                          decoration: const InputDecoration(
                                              labelText:
                                                  'کد محصول (Product Code)',
                                              border: OutlineInputBorder()),
                                          enabled: !_autoCode)),
                                  const SizedBox(width: 8),
                                  Column(children: [
                                    const Text('خودکار'),
                                    Switch(
                                        value: _autoCode,
                                        onChanged: (v) async {
                                          setState(() => _autoCode = v);
                                          if (v) {
                                            try {
                                              final db = await AppDatabase.db;
                                              final nxt = await products_dao
                                                  .getCurrentSequence(
                                                      db, 'product_code_seq');
                                              final displaySeq =
                                                  (nxt == 0) ? 1 : (nxt + 1);
                                              final codeNumber =
                                                  1000 + displaySeq;
                                              setState(() => _productCodeCtrl
                                                  .text = 'p$codeNumber');
                                            } catch (_) {}
                                          }
                                        })
                                  ])
                                ]),
                                const SizedBox(height: 8),
                                TextField(
                                    controller: _nameCtrl,
                                    decoration: const InputDecoration(
                                        labelText: 'نام محصول',
                                        border: OutlineInputBorder())),
                              ])),
                              const SizedBox(width: 12),
                              Column(children: [
                                CircleAvatar(
                                    radius: 44,
                                    backgroundImage: _localImagePath != null &&
                                            _localImagePath!.isNotEmpty
                                        ? FileImage(File(_localImagePath!))
                                            as ImageProvider
                                        : null,
                                    child: (_localImagePath == null)
                                        ? const Icon(Icons.image, size: 36)
                                        : null),
                                const SizedBox(height: 8),
                                SizedBox(
                                    width: 140,
                                    child: FilledButton.tonal(
                                        onPressed: _pickAndSaveImage,
                                        child: const Text('انتخاب تصویر'))),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: 140,
                                  child: OutlinedButton.icon(
                                    onPressed: _showCompactCategoryDialog,
                                    icon: const Icon(Icons.category, size: 16),
                                    label: Text(
                                      _categoryDisplayText(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ]),
                            ]))),
                    const SizedBox(height: 12),

                    // بخش فیلدهای فنی: SKU / بارکد / واحد / قیمتها / نقطه سفارش
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(children: [
                              Row(children: [
                                Expanded(
                                    child: TextField(
                                        controller: _skuCtrl,
                                        decoration: const InputDecoration(
                                            labelText: 'SKU',
                                            border: OutlineInputBorder()))),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: TextField(
                                        controller: _barcodeGlobalCtrl,
                                        decoration: const InputDecoration(
                                            labelText: 'بارکد جهانی (EAN/UPC)',
                                            border: OutlineInputBorder()))),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Row(children: [
                                  Expanded(
                                      child: TextField(
                                          controller: _barcodeStoreCtrl,
                                          decoration: const InputDecoration(
                                              labelText: 'بارکد فروشگاهی',
                                              border: OutlineInputBorder()))),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                      width: 44,
                                      child: IconButton(
                                          tooltip: 'تولید خودکار',
                                          icon: const Icon(Icons.autorenew),
                                          onPressed: _autoGenerateStoreBarcode))
                                ])),
                              ]),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(
                                    child: DropdownButtonFormField<int?>(
                                        initialValue: _selectedUnitId,
                                        decoration: const InputDecoration(
                                            labelText: 'واحد',
                                            border: OutlineInputBorder()),
                                        items: [
                                          const DropdownMenuItem<int?>(
                                              value: null,
                                              child: Text('- انتخاب کنید -')),
                                          ..._units.map((u) {
                                            final id = u['id'] is int
                                                ? u['id'] as int
                                                : int.tryParse(
                                                        u['id']?.toString() ??
                                                            '') ??
                                                    0;
                                            final name =
                                                u['name']?.toString() ?? '';
                                            final abbr =
                                                u['abbr']?.toString() ?? '';
                                            return DropdownMenuItem<int?>(
                                                value: id,
                                                child: Text(
                                                    '$name ${abbr.isNotEmpty ? '($abbr)' : ''}'));
                                          }).toList()
                                        ],
                                        onChanged: (v) => setState(
                                            () => _selectedUnitId = v))),
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                    onPressed: () async {
                                      final db = await AppDatabase.db;
                                      final newCtrl = TextEditingController();
                                      final abbrCtrl = TextEditingController();
                                      await showDialog(
                                          context: context,
                                          builder: (c) {
                                            return Directionality(
                                              textDirection: TextDirection.rtl,
                                              child: AlertDialog(
                                                title:
                                                    const Text('افزودن واحد'),
                                                content: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      TextField(
                                                          controller: newCtrl,
                                                          decoration:
                                                              const InputDecoration(
                                                                  labelText:
                                                                      'نام واحد')),
                                                      const SizedBox(height: 8),
                                                      TextField(
                                                          controller: abbrCtrl,
                                                          decoration:
                                                              const InputDecoration(
                                                                  labelText:
                                                                      'اختصار')),
                                                    ]),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(c).pop(),
                                                      child: const Text('لغو')),
                                                  FilledButton(
                                                      onPressed: () async {
                                                        final name =
                                                            newCtrl.text.trim();
                                                        if (name.isEmpty) {
                                                          return;
                                                        }
                                                        await products_dao
                                                            .saveUnit(db, {
                                                          'name': name,
                                                          'abbr': abbrCtrl.text
                                                              .trim(),
                                                          'created_at': DateTime
                                                                  .now()
                                                              .millisecondsSinceEpoch
                                                        });
                                                        newCtrl.dispose();
                                                        abbrCtrl.dispose();
                                                        Navigator.of(c).pop();
                                                        _init();
                                                      },
                                                      child:
                                                          const Text('ذخیره'))
                                                ],
                                              ),
                                            );
                                          });
                                    },
                                    child: const Text('مدیریت واحدها')),
                              ]),
                              const SizedBox(height: 12),
                              TextField(
                                  controller: _descCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'توضیحات',
                                      border: OutlineInputBorder()),
                                  maxLines: 3),
                            ]))),

                    const SizedBox(height: 12),

                    // بخش قیمتها و نقطه سفارش
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(children: [
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: _purchasePriceCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'قیمت خرید',
                                    border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _priceCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'قیمت فروش',
                                    border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 200,
                              child: TextField(
                                controller: _reorderCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'نقطه سفارش (Reorder Point)',
                                    border: OutlineInputBorder()),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // بخش مقدار اولیه / تنظیم موجودی (برای ویرایش)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                  _editingId == null
                                      ? 'مقدار اولیه (اختیاری)'
                                      : 'موجودی فعلی: ${_currentTotalQty.toString()} — تنظیم موجودی جدید',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(
                                    child: TextField(
                                  controller: _editingId == null
                                      ? _initialQtyCtrl
                                      : _adjustQtyCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: InputDecoration(
                                      labelText: _editingId == null
                                          ? 'مقدار اولیه'
                                          : 'مقدار جدید کل (برای تنظیم موجودی)',
                                      border: const OutlineInputBorder()),
                                )),
                                const SizedBox(width: 8),
                                if (_editingId != null)
                                  SizedBox(
                                    width: 160,
                                    child: FilledButton.tonal(
                                        onPressed: _saving
                                            ? null
                                            : _applyAdjustQuantity,
                                        child: _saving
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2))
                                            : const Text('اعمال تنظیم')),
                                  )
                              ]),
                              if (_editingId != null) ...[
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _actorForAdjustCtrl,
                                  decoration: const InputDecoration(
                                      labelText:
                                          'عامل (مثلاً person:1 یا نام کاربر)',
                                      border: OutlineInputBorder()),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _reasonForAdjustCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'دلیل تنظیم موجودی (الزامی)',
                                      border: OutlineInputBorder()),
                                  maxLines: 2,
                                ),
                              ]
                            ]),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: FilledButton.tonal(
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Text('ذخیره محصول'))),
                      const SizedBox(width: 12),
                      OutlinedButton(
                          onPressed: _init, child: const Text('بارگذاری مجدد')),
                    ]),
                  ]),
                ),
              ),
            ),
    );
  }
}
