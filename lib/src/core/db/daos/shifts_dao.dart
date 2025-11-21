// lib/src/core/db/daos/shifts_dao.dart
// DAO برای مدیریت شیفت‌ها (sessions / shifts).
// - جدول shifts: id, person_id, started_at, ended_at, terminal_id, notes, active
// - متد startShift: قبل از ایجاد شیفت جدید، شیفت فعال قبلی برای همان ترمینال یا همان شخص را خاتمه می‌دهد.
// - متد endShift: انتهای شیفت را ثبت می‌کند (ended_at + active=0).
// - متدهای خواندن: getActiveShift, getShiftById, getShifts (پایگاه برای گزارش).
// کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'package:sqflite/sqflite.dart';

Future<void> createShiftsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS shifts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      person_id INTEGER NOT NULL,
      started_at INTEGER NOT NULL,
      ended_at INTEGER,
      terminal_id TEXT,
      notes TEXT,
      active INTEGER DEFAULT 1
    )
  ''');
}

Future<void> migrateShiftsTable(Database db) async {
  try {
    final info = await db.rawQuery("PRAGMA table_info(shifts)");
    if (info.isEmpty) {
      await createShiftsTable(db);
      return;
    }

    Future<void> maybeAdd(String colDef, String colName) async {
      if (!info.any((r) => (r['name']?.toString() ?? '') == colName)) {
        try {
          await db.execute('ALTER TABLE shifts ADD COLUMN $colDef');
        } catch (_) {}
      }
    }

    await maybeAdd('person_id INTEGER NOT NULL', 'person_id');
    await maybeAdd('started_at INTEGER NOT NULL', 'started_at');
    await maybeAdd('ended_at INTEGER', 'ended_at');
    await maybeAdd('terminal_id TEXT', 'terminal_id');
    await maybeAdd('notes TEXT', 'notes');
    await maybeAdd('active INTEGER DEFAULT 1', 'active');
  } catch (_) {
    try {
      await createShiftsTable(db);
    } catch (_) {}
  }
}

/// شروع شیفت: item باید شامل حداقل person_id و (اختیاری) terminal_id و notes باشد
/// رفتار:
/// - در تراکنش: اگر شیفت فعال دیگری برای همان terminal_id یا همان person_id وجود داشت آن را خاتمه می‌کنیم (ended_at = now, active = 0)
/// - سپس شیفت جدید را با started_at = now و active = 1 درج می‌کنیم و id را برمی‌گردانیم.
Future<int> startShift(Database db, Map<String, dynamic> item) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  return await db.transaction<int>((txn) async {
    final int? personId = (item['person_id'] is int)
        ? item['person_id'] as int
        : int.tryParse(item['person_id']?.toString() ?? '');
    final String? terminalId = item['terminal_id']?.toString();

    // خاتمهٔ شیفت‌های فعال قبلی برای همان ترمینال (اگر terminalId داده شده)
    if (terminalId != null && terminalId.isNotEmpty) {
      try {
        await txn.update('shifts', {'ended_at': now, 'active': 0},
            where: 'terminal_id = ? AND active = 1', whereArgs: [terminalId]);
      } catch (_) {}
    }

    // خاتمهٔ شیفت فعال قبلی برای همان شخص (اگر وجود دارد)
    if (personId != null) {
      try {
        await txn.update('shifts', {'ended_at': now, 'active': 0},
            where: 'person_id = ? AND active = 1', whereArgs: [personId]);
      } catch (_) {}
    }

    final toInsert = <String, dynamic>{
      'person_id': personId,
      'started_at': now,
      'ended_at': null,
      'terminal_id': terminalId,
      'notes': item['notes'],
      'active': 1,
    };
    final newId = await txn.insert('shifts', toInsert);
    return newId;
  });
}

/// پایان شیفت: ended_at = now, active = 0
Future<int> endShift(Database db, int shiftId) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  return await db.update('shifts', {'ended_at': now, 'active': 0},
      where: 'id = ?', whereArgs: [shiftId]);
}

/// خواندن شیفت فعال (active=1). اگر terminalId داده شود قبلویت بر اساس ترمینال است.
Future<Map<String, dynamic>?> getActiveShift(Database db,
    {String? terminalId}) async {
  if (terminalId != null && terminalId.isNotEmpty) {
    final rows = await db.query('shifts',
        where: 'terminal_id = ? AND active = 1',
        whereArgs: [terminalId],
        limit: 1);
    if (rows.isNotEmpty) return rows.first;
  }
  final rows = await db.query('shifts', where: 'active = 1', limit: 1);
  if (rows.isEmpty) return null;
  return rows.first;
}

Future<Map<String, dynamic>?> getShiftById(Database db, int id) async {
  final rows =
      await db.query('shifts', where: 'id = ?', whereArgs: [id], limit: 1);
  if (rows.isEmpty) return null;
  return rows.first;
}

/// لیست شیفت‌ها (برای گزارش) — میتوان بر اساس personId فیلتر کرد
Future<List<Map<String, dynamic>>> getShifts(Database db,
    {int? personId, int limit = 100, int offset = 0}) async {
  String sql =
      'SELECT s.*, p.display_name as person_name FROM shifts s LEFT JOIN persons p ON p.id = s.person_id';
  final args = <dynamic>[];
  if (personId != null) {
    sql += ' WHERE s.person_id = ?';
    args.add(personId);
  }
  sql += ' ORDER BY s.started_at DESC LIMIT ? OFFSET ?';
  args.add(limit);
  args.add(offset);
  return await db.rawQuery(sql, args);
}
