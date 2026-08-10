import 'dart:math';

import 'package:intl/intl.dart';

import '../models/app_settings.dart';
import '../models/leave_entry.dart';
import '../models/work_record.dart';

/// ===== 정책 결정 지점 =====
/// 휴게 차감 정책은 설정(AppSettings.breakPolicy)을 따른다:
/// - perFourHours (기본): 체류 4시간마다 30분 차감 (근로기준법 §54 근사)
/// - fixed: 체류가 breakThresholdMinutes 이상이면 breakMinutes 고정 차감
const int _perFourHoursUnit = 4 * 60;
const int _perFourHoursDeduction = 30;

final DateFormat _dateKeyFormat = DateFormat('yyyy-MM-dd');

String dateKey(DateTime d) => _dateKeyFormat.format(d);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 출근~퇴근 총 체류시간(분). 퇴근이 출근보다 빠르면 0.
int grossMinutes(DateTime clockIn, DateTime clockOut) =>
    max(0, clockOut.difference(clockIn).inMinutes);

/// 총 체류시간에 대한 휴게 차감량(분).
int breakDeductionMinutes(int gross, AppSettings settings) {
  switch (settings.breakPolicy) {
    case BreakPolicy.perFourHours:
      return (gross ~/ _perFourHoursUnit) * _perFourHoursDeduction;
    case BreakPolicy.fixed:
      return gross >= settings.breakThresholdMinutes
          ? settings.breakMinutes
          : 0;
  }
}

/// 실근무시간(분) = 총 체류시간 − 휴게 차감량.
int netWorkMinutes(DateTime clockIn, DateTime clockOut, AppSettings settings) {
  final gross = grossMinutes(clockIn, clockOut);
  return max(0, gross - breakDeductionMinutes(gross, settings));
}

/// 하루 초과근무(분) = 실근무 − 소정근로 (음수면 0).
int overtimeMinutes(int netMinutes, int standardDailyMinutes) =>
    max(0, netMinutes - standardDailyMinutes);

/// 그 날이 속한 주의 월요일. 주간 통계는 항상 월~일 기준이며
/// 월 경계와 무관하게 독립적으로 계산한다.
DateTime weekStartOf(DateTime d) =>
    dateOnly(d).subtract(Duration(days: d.weekday - DateTime.monday));

/// 오늘 기준 현재 연차년도의 시작일.
/// 기준일이 2/30처럼 존재하지 않는 날짜면 그 달의 말일로 보정한다.
DateTime leaveYearStartFor(DateTime today, int startMonth, int startDay) {
  DateTime buildStart(int year) {
    final lastDay = DateTime(year, startMonth + 1, 0).day;
    return DateTime(year, startMonth, min(startDay, lastDay));
  }

  final thisYear = buildStart(today.year);
  return today.isBefore(thisYear) ? buildStart(today.year - 1) : thisYear;
}

/// 기간 통계. 모든 값은 조회 시점에 원본 기록에서 계산한다 —
/// "매달 1일 갱신"은 저장값 리셋이 아니라 기간 필터로 구현된다.
class PeriodStats {
  const PeriodStats({
    required this.workedDays,
    required this.totalNetMinutes,
    required this.totalOvertimeMinutes,
    required this.leaveDays,
    required this.leaveCreditMinutes,
  });

  final int workedDays;
  final int totalNetMinutes;
  final int totalOvertimeMinutes;

  /// 기간 내 사용 연차(일). 반차는 0.5.
  final double leaveDays;

  /// 연차를 소정근로시간으로 인정한 분. (연차 1일 = 소정근로 1일)
  final int leaveCreditMinutes;

  /// 실근무 + 연차 인정 합계.
  int get combinedMinutes => totalNetMinutes + leaveCreditMinutes;
}

/// [start] 이상 [endExclusive] 미만 날짜 범위의 통계를 집계한다.
PeriodStats calcPeriodStats({
  required Iterable<WorkRecord> records,
  required Iterable<LeaveEntry> leaves,
  required DateTime start,
  required DateTime endExclusive,
  required AppSettings settings,
}) {
  final startKey = dateKey(start);
  final endKey = dateKey(endExclusive);
  bool inRange(String date) =>
      date.compareTo(startKey) >= 0 && date.compareTo(endKey) < 0;

  var workedDays = 0;
  var totalNet = 0;
  var totalOvertime = 0;
  for (final r in records) {
    if (!inRange(r.date) || !r.isComplete) continue;
    final net = netWorkMinutes(r.clockIn!, r.clockOut!, settings);
    workedDays++;
    totalNet += net;
    totalOvertime += overtimeMinutes(net, settings.standardDailyMinutes);
  }

  var leaveDays = 0.0;
  for (final l in leaves) {
    if (inRange(l.date)) leaveDays += l.amount;
  }

  return PeriodStats(
    workedDays: workedDays,
    totalNetMinutes: totalNet,
    totalOvertimeMinutes: totalOvertime,
    leaveDays: leaveDays,
    leaveCreditMinutes: (leaveDays * settings.standardDailyMinutes).round(),
  );
}

/// 현재 연차년도에 사용한 연차(일).
double leaveUsedInCurrentYear(
  Iterable<LeaveEntry> leaves,
  AppSettings settings, {
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final start = leaveYearStartFor(
    now,
    settings.leaveYearStartMonth,
    settings.leaveYearStartDay,
  );
  final end = DateTime(start.year + 1, start.month, start.day);
  final startKey = dateKey(start);
  final endKey = dateKey(end);
  var used = 0.0;
  for (final l in leaves) {
    if (l.date.compareTo(startKey) >= 0 && l.date.compareTo(endKey) < 0) {
      used += l.amount;
    }
  }
  return used;
}

/// '8시간 30분' 형태로 표시. 0분은 '0분'.
String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m분';
  if (m == 0) return '$h시간';
  return '$h시간 $m분';
}

/// 연차 일수 표시: 15.0 → '15', 1.5 → '1.5'.
String formatDays(double days) =>
    days == days.roundToDouble() ? '${days.round()}' : '$days';

/// 'HH:mm' 문자열 파싱. 잘못된 값이면 null.
({int hour, int minute})? parseHHmm(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
    return null;
  }
  return (hour: h, minute: m);
}
