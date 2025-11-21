// lib/src/pages/shifts/shifts_page.dart
// صفحهٔ مدیریت شیفت‌ها (Start / End) — برای ثبت اینکه چه کسی در چه بازه‌ای پشت سیستم بوده.
// - لیست افراد مجاز (فروشنده/کارمند/سهامدار) نمایش داده می‌شود.
// - امکان انتخاب شخص و شروع شیفت وجود دارد؛ شیفت فعال نمایش و قابل پایان دادن است.
// - کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'package:flutter/material.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';

class ShiftsPage extends StatefulWidget {
  const ShiftsPage({super.key});

  @override
  State<ShiftsPage> createState() => _ShiftsPageState();
}

class _ShiftsPageState extends State<ShiftsPage> {
  List<Map<String, dynamic>> _actors = [];
  Map<String, dynamic>? _activeShift;
  int? _selectedPersonId;
  String _terminalId = ''; // می‌توان از تنظیمات یا نام دستگاه استفاده کرد
  bool _loading = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _load();
    // پیشنهاد: مقدار پیشفرض terminalId را از ConfigManager یا از hostname بگیر
    _terminalId = _computeTerminalId();
  }

  String _computeTerminalId() {
    // ساده: نام ماشین + user; در دسکتاپ میتوان از Platform.resolvedExecutable یا hostname گرفت.
    try {
      return DateTime.now()
          .millisecondsSinceEpoch
          .toString()
          .substring(7); // placeholder/unique
    } catch (_) {
      return 'terminal';
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final persons = await AppDatabase.getPersons();
      final actors = persons.where((p) {
        final isSeller = p.containsKey('type_seller') &&
            (p['type_seller'] == 1 ||
                p['type_seller'] == true ||
                (p['type_seller'] is String &&
                    p['type_seller'].toString() == '1'));
        final isEmployee = p.containsKey('type_employee') &&
            (p['type_employee'] == 1 ||
                p['type_employee'] == true ||
                (p['type_employee'] is String &&
                    p['type_employee'].toString() == '1'));
        final isShareholder = p.containsKey('type_shareholder') &&
            (p['type_shareholder'] == 1 ||
                p['type_shareholder'] == true ||
                (p['type_shareholder'] is String &&
                    p['type_shareholder'].toString() == '1'));
        return isSeller || isEmployee || isShareholder;
      }).toList();
      final active = await AppDatabase.getActiveShift(terminalId: _terminalId);
      setState(() {
        _actors = actors;
        _activeShift = active;
        if (_actors.isNotEmpty && _selectedPersonId == null) {
          final idRaw = _actors.first['id'];
          _selectedPersonId =
              (idRaw is int) ? idRaw : int.tryParse(idRaw?.toString() ?? '');
        }
      });
    } catch (e) {
      NotificationService.showToast(context, 'بارگذاری انجام نشد: $e',
          backgroundColor: Colors.orange);
      setState(() {
        _actors = [];
        _activeShift = null;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _startShift() async {
    if (_selectedPersonId == null) {
      NotificationService.showError(
          context, 'انتخاب نکرده‌اید', 'یک شخص را انتخاب کنید');
      return;
    }
    setState(() => _processing = true);
    try {
      final id = await AppDatabase.startShift({
        'person_id': _selectedPersonId,
        'terminal_id': _terminalId,
        'notes': 'شروع شیفت از رابط کاربری',
      });
      NotificationService.showToast(context, 'شیفت شروع شد (id=$id)');
      await _load();
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'شروع شیفت ناموفق بود: $e');
    } finally {
      setState(() => _processing = false);
    }
  }

  Future<void> _endShift() async {
    if (_activeShift == null) {
      NotificationService.showToast(context, 'شیفت فعالی وجود ندارد');
      return;
    }
    final sid = (_activeShift!['id'] is int)
        ? _activeShift!['id'] as int
        : int.tryParse(_activeShift!['id']?.toString() ?? '') ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('پایان شیفت'),
          content: const Text('آیا از اتمام شیفت اطمینان دارید؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('لغو')),
            FilledButton.tonal(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('پایان')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    setState(() => _processing = true);
    try {
      await AppDatabase.endShift(sid);
      NotificationService.showToast(context, 'شیفت پایان یافت');
      await _load();
    } catch (e) {
      NotificationService.showError(
          context, 'خطا', 'پایان شیفت ناموفق بود: $e');
    } finally {
      setState(() => _processing = false);
    }
  }

  Widget _activeCard() {
    if (_activeShift == null) return const SizedBox.shrink();
    final personName = _activeShift!['person_name'] ??
        _activeShift!['person_id']?.toString() ??
        '';
    final started = _activeShift!['started_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch((_activeShift!['started_at']
                    is int)
                ? _activeShift!['started_at'] as int
                : int.tryParse(_activeShift!['started_at']?.toString() ?? '') ??
                    0)
            .toString()
        : '';
    return Card(
      color: Colors.green.shade50,
      child: ListTile(
        title: Text('شیفت فعال: $personName'),
        subtitle: Text(
            'شروع: $started\nترمینال: ${_activeShift!['terminal_id'] ?? ''}'),
        trailing: FilledButton.tonal(
            onPressed: _processing ? null : _endShift,
            child: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('پایان شیفت')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مدیریت شیفت‌ها'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(children: [
                _activeCard(),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          initialValue: _selectedPersonId,
                          decoration: const InputDecoration(
                              labelText: 'انتخاب شخص برای شیفت',
                              border: OutlineInputBorder(),
                              isDense: true),
                          items: _actors.map((p) {
                            final id = (p['id'] is int)
                                ? p['id'] as int
                                : int.tryParse(p['id']?.toString() ?? '') ?? 0;
                            final name = p['display_name']?.toString() ??
                                '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}';
                            return DropdownMenuItem<int?>(
                                value: id, child: Text(name));
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _selectedPersonId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                          width: 140,
                          child: FilledButton.tonal(
                              onPressed: _processing ? null : _startShift,
                              child: _processing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Text('شروع شیفت'))),
                      const SizedBox(width: 8),
                      OutlinedButton(
                          onPressed: _load, child: const Text('بارگذاری')),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                    child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: AppDatabase.getShifts(limit: 200),
                      builder: (c, s) {
                        if (!s.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final rows = s.data!;
                        if (rows.isEmpty) {
                          return const Center(
                              child: Text('هنوز شیفتی ثبت نشده'));
                        }
                        return ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 6),
                          itemBuilder: (ctx, idx) {
                            final r = rows[idx];
                            final id = (r['id'] is int)
                                ? r['id'] as int
                                : int.tryParse(r['id']?.toString() ?? '') ?? 0;
                            final name = r['person_name']?.toString() ??
                                r['person_id']?.toString() ??
                                '';
                            final started = r['started_at'] != null
                                ? DateTime.fromMillisecondsSinceEpoch(
                                        (r['started_at'] is int)
                                            ? r['started_at'] as int
                                            : int.tryParse(r['started_at']
                                                        ?.toString() ??
                                                    '') ??
                                                0)
                                    .toString()
                                : '';
                            final ended = r['ended_at'] != null
                                ? DateTime.fromMillisecondsSinceEpoch(
                                        (r['ended_at'] is int)
                                            ? r['ended_at'] as int
                                            : int.tryParse(
                                                    r['ended_at']?.toString() ??
                                                        '') ??
                                                0)
                                    .toString()
                                : '-';
                            final active =
                                (r['active'] == 1 || r['active'] == true);
                            return ListTile(
                              title: Text('$name  (id:$id)'),
                              subtitle: Text(
                                  'شروع: $started\nپایان: $ended\nترمینال: ${r['terminal_id'] ?? ''}'),
                              trailing: active
                                  ? const Chip(
                                      label: Text('فعال'),
                                      backgroundColor: Colors.greenAccent)
                                  : null,
                            );
                          },
                        );
                      },
                    ),
                  ),
                )),
              ]),
            ),
    );
  }
}
