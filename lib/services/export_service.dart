import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_settings.dart';
import '../models/leave_entry.dart';
import '../models/work_record.dart';
import '../utils/time_calculator.dart';

class BackupData {
  const BackupData({
    required this.settings,
    required this.records,
    required this.leaves,
  });

  final AppSettings settings;
  final List<WorkRecord> records;
  final List<LeaveEntry> leaves;
}

/// CSV 내보내기와 JSON 백업/복원. 모두 공유 시트를 통해 사용자가
/// 저장 위치(파일, 메일, 클라우드 등)를 직접 고른다.
class ExportService {
  static const backupVersion = 1;

  /// 기록+연차를 날짜순 CSV로 만든다. 엑셀 한글 호환을 위해 BOM을 붙인다.
  String buildCsv({
    required Iterable<WorkRecord> records,
    required Iterable<LeaveEntry> leaves,
    required AppSettings settings,
  }) {
    final recordMap = {for (final r in records) r.date: r};
    final leaveMap = {for (final l in leaves) l.date: l};
    final dates = {...recordMap.keys, ...leaveMap.keys}.toList()..sort();

    final buffer = StringBuffer('﻿');
    buffer.writeln('날짜,요일,출근,퇴근,실근무(분),실근무,초과근무(분),연차(일),메모');
    final weekdayFormat = DateFormat.E('ko_KR');
    final timeFormat = DateFormat('HH:mm');
    for (final date in dates) {
      final record = recordMap[date];
      final leave = leaveMap[date];
      final day = DateTime.parse(date);
      var net = 0;
      var overtime = 0;
      if (record != null && record.isComplete) {
        net = netWorkMinutes(record.clockIn!, record.clockOut!, settings);
        overtime = overtimeMinutes(net, settings.standardDailyMinutes);
      }
      final cells = [
        date,
        weekdayFormat.format(day),
        record?.clockIn != null ? timeFormat.format(record!.clockIn!) : '',
        record?.clockOut != null ? timeFormat.format(record!.clockOut!) : '',
        record != null && record.isComplete ? '$net' : '',
        record != null && record.isComplete ? formatMinutes(net) : '',
        record != null && record.isComplete ? '$overtime' : '',
        leave != null ? '${leave.amount}' : '',
        _escapeCsv(record?.note ?? leave?.note ?? ''),
      ];
      buffer.writeln(cells.join(','));
    }
    return buffer.toString();
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> shareCsv({
    required Iterable<WorkRecord> records,
    required Iterable<LeaveEntry> leaves,
    required AppSettings settings,
  }) async {
    final csv =
        buildCsv(records: records, leaves: leaves, settings: settings);
    final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
    final path = await _writeTempFile('timesheet_$stamp.csv', csv);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], subject: '출퇴근 기록 CSV'),
    );
  }

  Map<String, Object?> buildBackup({
    required AppSettings settings,
    required Iterable<WorkRecord> records,
    required Iterable<LeaveEntry> leaves,
  }) {
    return {
      'app': 'timesheet',
      'version': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings.toMap(),
      'records': [for (final r in records) r.toMap()..remove('id')],
      'leaves': [for (final l in leaves) l.toMap()..remove('id')],
    };
  }

  Future<void> shareBackup({
    required AppSettings settings,
    required Iterable<WorkRecord> records,
    required Iterable<LeaveEntry> leaves,
  }) async {
    final json = const JsonEncoder.withIndent('  ').convert(
      buildBackup(settings: settings, records: records, leaves: leaves),
    );
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final path = await _writeTempFile('timesheet_backup_$stamp.json', json);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], subject: '출퇴근 기록 백업'),
    );
  }

  /// 백업 파일을 골라 파싱한다. 취소하면 null, 형식이 다르면 FormatException.
  Future<BackupData?> pickAndParseBackup() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return null;

    final content = await File(path).readAsString();
    final map = jsonDecode(content) as Map<String, dynamic>;
    if (map['app'] != 'timesheet' || map['records'] is! List) {
      throw const FormatException('timesheet 백업 파일이 아닙니다.');
    }
    return BackupData(
      settings: AppSettings.fromMap(
        (map['settings'] as Map<String, dynamic>?) ?? {},
      ),
      records: [
        for (final r in map['records'] as List)
          WorkRecord.fromMap((r as Map).cast<String, Object?>()),
      ],
      leaves: [
        for (final l in (map['leaves'] as List? ?? []))
          LeaveEntry.fromMap((l as Map).cast<String, Object?>()),
      ],
    );
  }

  Future<String> _writeTempFile(String name, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(content);
    return file.path;
  }
}
