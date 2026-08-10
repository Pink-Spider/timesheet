import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/leave_entry.dart';
import '../models/work_record.dart';
import '../utils/time_calculator.dart';

enum ClockStatus { notClockedIn, working, done }

enum ClockResult {
  success,
  needsOverwriteConfirm,
  noOpenRecord,
}

/// 출퇴근/연차 기록 상태. 개인용 데이터 규모(수천 행)라 전체를 메모리에 올려
/// 모든 화면이 네트워크·디스크 대기 없이 즉시 파생 계산한다.
class TimesheetProvider extends ChangeNotifier {
  TimesheetProvider(this._db, {this._onClockIn, this._onClockOut});

  final DatabaseHelper _db;

  /// 출근/퇴근 성공 시 호출되는 훅. 리마인더 예약/취소를 여기 연결한다
  /// (프로바이더는 알림 구현을 모른다).
  final Future<void> Function(DateTime clockInTime)? _onClockIn;
  final Future<void> Function()? _onClockOut;

  final Map<String, WorkRecord> _recordsByDate = {};
  final Map<String, LeaveEntry> _leavesByDate = {};

  Map<String, WorkRecord> get recordsByDate => _recordsByDate;
  Map<String, LeaveEntry> get leavesByDate => _leavesByDate;

  Iterable<WorkRecord> get records => _recordsByDate.values;
  Iterable<LeaveEntry> get leaves => _leavesByDate.values;

  Future<void> load() async {
    final records = await _db.getAllRecords();
    final leaves = await _db.getAllLeaves();
    _recordsByDate
      ..clear()
      ..addEntries(records.map((r) => MapEntry(r.date, r)));
    _leavesByDate
      ..clear()
      ..addEntries(leaves.map((l) => MapEntry(l.date, l)));
    notifyListeners();
  }

  WorkRecord? recordOn(DateTime day) => _recordsByDate[dateKey(day)];
  LeaveEntry? leaveOn(DateTime day) => _leavesByDate[dateKey(day)];

  WorkRecord? get todayRecord => recordOn(DateTime.now());

  /// 퇴근 대상 기록: 오늘 또는 어제(자정 넘긴 근무)의 미퇴근 기록.
  WorkRecord? get openRecord {
    final now = DateTime.now();
    final today = _recordsByDate[dateKey(now)];
    if (today != null && today.isOpen) return today;
    final yesterday =
        _recordsByDate[dateKey(now.subtract(const Duration(days: 1)))];
    if (yesterday != null && yesterday.isOpen) return yesterday;
    return null;
  }

  ClockStatus get status {
    if (openRecord != null) return ClockStatus.working;
    final today = todayRecord;
    if (today != null && today.isComplete) return ClockStatus.done;
    return ClockStatus.notClockedIn;
  }

  /// 출근. 오늘 이미 출근 기록이 있으면 [overwrite] 없이는 확인을 요구한다.
  Future<ClockResult> clockIn({bool overwrite = false}) async {
    final now = DateTime.now();
    final key = dateKey(now);
    final existing = _recordsByDate[key];
    if (existing?.clockIn != null && !overwrite) {
      return ClockResult.needsOverwriteConfirm;
    }
    final record = WorkRecord(
      date: key,
      clockIn: now,
      clockOut: null,
      note: existing?.note,
    );
    _recordsByDate[key] = await _db.upsertRecord(record);
    notifyListeners();
    await _onClockIn?.call(now);
    return ClockResult.success;
  }

  /// 퇴근. 미퇴근 기록이 없으면 오늘 완료된 기록의 퇴근시간 갱신을 확인받는다.
  Future<ClockResult> clockOut({bool overwrite = false}) async {
    final now = DateTime.now();
    var target = openRecord;
    if (target == null) {
      final today = todayRecord;
      if (today == null || today.clockIn == null) {
        return ClockResult.noOpenRecord;
      }
      if (!overwrite) return ClockResult.needsOverwriteConfirm;
      target = today;
    }
    final updated = target.copyWith(clockOut: now);
    _recordsByDate[updated.date] = await _db.upsertRecord(updated);
    notifyListeners();
    await _onClockOut?.call();
    return ClockResult.success;
  }

  Future<void> saveRecord(WorkRecord record) async {
    _recordsByDate[record.date] = await _db.upsertRecord(record);
    notifyListeners();
  }

  Future<void> deleteRecord(String date) async {
    await _db.deleteRecordByDate(date);
    _recordsByDate.remove(date);
    notifyListeners();
  }

  Future<void> saveLeave(LeaveEntry entry) async {
    _leavesByDate[entry.date] = await _db.upsertLeave(entry);
    notifyListeners();
  }

  Future<void> deleteLeave(String date) async {
    await _db.deleteLeaveByDate(date);
    _leavesByDate.remove(date);
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _db.clearAll();
    _recordsByDate.clear();
    _leavesByDate.clear();
    notifyListeners();
  }

  /// 백업 복원: DB와 메모리를 통째로 교체.
  Future<void> restore({
    required List<WorkRecord> records,
    required List<LeaveEntry> leaves,
  }) async {
    await _db.replaceAll(records: records, leaves: leaves);
    await load();
  }
}
