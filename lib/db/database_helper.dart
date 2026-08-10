import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/leave_entry.dart';
import '../models/work_record.dart';

/// sqflite 접근 계층. 테스트에서는 [dbPath]에 inMemoryDatabasePath를 넘긴다.
class DatabaseHelper {
  DatabaseHelper({this.dbPath});

  final String? dbPath;
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = dbPath ?? p.join(await getDatabasesPath(), 'timesheet.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE work_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL UNIQUE,
            clock_in TEXT,
            clock_out TEXT,
            note TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE leave_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL UNIQUE,
            amount REAL NOT NULL,
            note TEXT
          )
        ''');
      },
    );
    return _db!;
  }

  Future<List<WorkRecord>> getAllRecords() async {
    final db = await database;
    final rows = await db.query('work_records', orderBy: 'date');
    return rows.map(WorkRecord.fromMap).toList();
  }

  Future<List<LeaveEntry>> getAllLeaves() async {
    final db = await database;
    final rows = await db.query('leave_entries', orderBy: 'date');
    return rows.map(LeaveEntry.fromMap).toList();
  }

  /// date UNIQUE 제약을 이용해 삽입/갱신을 한 번에 처리한다.
  Future<WorkRecord> upsertRecord(WorkRecord record) async {
    final db = await database;
    final map = record.toMap()..remove('id');
    final id = await db.insert(
      'work_records',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return record.copyWith(id: id);
  }

  Future<void> deleteRecordByDate(String date) async {
    final db = await database;
    await db.delete('work_records', where: 'date = ?', whereArgs: [date]);
  }

  Future<LeaveEntry> upsertLeave(LeaveEntry entry) async {
    final db = await database;
    final map = entry.toMap()..remove('id');
    final id = await db.insert(
      'leave_entries',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return LeaveEntry(
      id: id,
      date: entry.date,
      amount: entry.amount,
      note: entry.note,
    );
  }

  Future<void> deleteLeaveByDate(String date) async {
    final db = await database;
    await db.delete('leave_entries', where: 'date = ?', whereArgs: [date]);
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('work_records');
      await txn.delete('leave_entries');
    });
  }

  /// 백업 복원: 기존 데이터를 지우고 통째로 교체한다.
  Future<void> replaceAll({
    required List<WorkRecord> records,
    required List<LeaveEntry> leaves,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('work_records');
      await txn.delete('leave_entries');
      for (final r in records) {
        await txn.insert('work_records', r.toMap()..remove('id'));
      }
      for (final l in leaves) {
        await txn.insert('leave_entries', l.toMap()..remove('id'));
      }
    });
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
