import 'package:flutter_test/flutter_test.dart';
import 'package:timesheet/models/app_settings.dart';
import 'package:timesheet/models/leave_entry.dart';
import 'package:timesheet/models/work_record.dart';
import 'package:timesheet/utils/time_calculator.dart';

void main() {
  group('netWorkMinutes — 법정 기준 (4시간당 30분, 기본값)', () {
    const settings = AppSettings(); // breakPolicy: perFourHours

    test('9시~18시(9시간 체류)는 60분 차감해 480분', () {
      final net = netWorkMinutes(
        DateTime(2026, 8, 3, 9, 0),
        DateTime(2026, 8, 3, 18, 0),
        settings,
      );
      expect(net, 480);
    });

    test('4시간 근무는 30분 차감', () {
      final net = netWorkMinutes(
        DateTime(2026, 8, 3, 9, 0),
        DateTime(2026, 8, 3, 13, 0),
        settings,
      );
      expect(net, 210);
    });

    test('4시간 미만은 차감 없음', () {
      final net = netWorkMinutes(
        DateTime(2026, 8, 3, 9, 0),
        DateTime(2026, 8, 3, 12, 59),
        settings,
      );
      expect(net, 239);
    });

    test('12시간 근무는 90분 차감', () {
      final net = netWorkMinutes(
        DateTime(2026, 8, 3, 9, 0),
        DateTime(2026, 8, 3, 21, 0),
        settings,
      );
      expect(net, 630);
    });

    test('자정을 넘긴 근무도 전체 타임스탬프로 계산된다', () {
      final net = netWorkMinutes(
        DateTime(2026, 8, 3, 22, 0),
        DateTime(2026, 8, 4, 2, 0),
        settings,
      );
      expect(net, 210);
    });

    test('퇴근이 출근보다 빠르면 0', () {
      final net = netWorkMinutes(
        DateTime(2026, 8, 3, 18, 0),
        DateTime(2026, 8, 3, 9, 0),
        settings,
      );
      expect(net, 0);
    });
  });

  group('netWorkMinutes — 고정 차감', () {
    const settings = AppSettings(
      breakPolicy: BreakPolicy.fixed,
      breakMinutes: 60,
      breakThresholdMinutes: 360,
    );

    test('기준(6시간) 이상이면 휴게 60분 차감', () {
      final net = netWorkMinutes(
        DateTime(2026, 8, 3, 9, 0),
        DateTime(2026, 8, 3, 18, 0),
        settings,
      );
      expect(net, 480);
    });

    test('기준 미만이면 차감하지 않는다', () {
      final net = netWorkMinutes(
        DateTime(2026, 8, 3, 9, 0),
        DateTime(2026, 8, 3, 13, 0),
        settings,
      );
      expect(net, 240);
    });

    test('정확히 기준이면 차감한다', () {
      final net = netWorkMinutes(
        DateTime(2026, 8, 3, 9, 0),
        DateTime(2026, 8, 3, 15, 0),
        settings,
      );
      expect(net, 300);
    });

    test('기준이 0이면 항상 차감한다', () {
      const always = AppSettings(
        breakPolicy: BreakPolicy.fixed,
        breakMinutes: 60,
        breakThresholdMinutes: 0,
      );
      final net = netWorkMinutes(
        DateTime(2026, 8, 3, 9, 0),
        DateTime(2026, 8, 3, 13, 0),
        always,
      );
      expect(net, 180);
    });
  });

  group('overtimeMinutes', () {
    test('소정근로 초과분만 계산한다', () {
      expect(overtimeMinutes(540, 480), 60);
      expect(overtimeMinutes(400, 480), 0);
      expect(overtimeMinutes(480, 480), 0);
    });
  });

  group('weekStartOf', () {
    test('주는 항상 월요일에 시작한다', () {
      expect(weekStartOf(DateTime(2026, 8, 5)), DateTime(2026, 8, 3)); // 수
      expect(weekStartOf(DateTime(2026, 8, 3)), DateTime(2026, 8, 3)); // 월
      expect(weekStartOf(DateTime(2026, 8, 9)), DateTime(2026, 8, 3)); // 일
    });

    test('월 경계에 걸친 주도 월요일 기준으로 유지된다', () {
      // 2026-08-31은 월요일 — 9월 첫 주는 8/31에 시작한다.
      expect(weekStartOf(DateTime(2026, 9, 2)), DateTime(2026, 8, 31));
    });
  });

  group('leaveYearStartFor', () {
    test('1월 1일 기준(회계연도)', () {
      expect(
        leaveYearStartFor(DateTime(2026, 8, 7), 1, 1),
        DateTime(2026, 1, 1),
      );
    });

    test('기준일이 아직 오지 않았으면 작년 기준일', () {
      expect(
        leaveYearStartFor(DateTime(2026, 2, 1), 3, 15),
        DateTime(2025, 3, 15),
      );
    });

    test('존재하지 않는 날짜(2/30)는 말일로 보정한다', () {
      expect(
        leaveYearStartFor(DateTime(2026, 8, 7), 2, 30),
        DateTime(2026, 2, 28),
      );
    });
  });

  group('calcPeriodStats', () {
    const settings = AppSettings(); // 소정근로 480분, 법정 휴게(4시간당 30분)

    final records = [
      WorkRecord(
        date: '2026-08-03',
        clockIn: DateTime(2026, 8, 3, 9, 0),
        clockOut: DateTime(2026, 8, 3, 18, 0),
      ), // 480분
      WorkRecord(
        date: '2026-08-04',
        clockIn: DateTime(2026, 8, 4, 9, 0),
        clockOut: DateTime(2026, 8, 4, 20, 0),
      ), // 600분, 초과 120분
      WorkRecord(
        date: '2026-08-05',
        clockIn: DateTime(2026, 8, 5, 9, 0),
        clockOut: null,
      ), // 미완료 — 제외
      WorkRecord(
        date: '2026-07-31',
        clockIn: DateTime(2026, 7, 31, 9, 0),
        clockOut: DateTime(2026, 7, 31, 18, 0),
      ), // 범위 밖
    ];
    final leaves = [
      const LeaveEntry(date: '2026-08-06', amount: 0.5),
      const LeaveEntry(date: '2026-07-01', amount: 1.0), // 범위 밖
    ];

    test('범위 내 완료 기록만 집계하고 연차를 인정한다', () {
      final stats = calcPeriodStats(
        records: records,
        leaves: leaves,
        start: DateTime(2026, 8, 1),
        endExclusive: DateTime(2026, 9, 1),
        settings: settings,
      );
      expect(stats.workedDays, 2);
      expect(stats.totalNetMinutes, 1080);
      expect(stats.totalOvertimeMinutes, 120);
      expect(stats.leaveDays, 0.5);
      expect(stats.leaveCreditMinutes, 240);
      expect(stats.combinedMinutes, 1320);
    });

    test('기간 시작일은 포함, 종료일은 제외', () {
      final stats = calcPeriodStats(
        records: records,
        leaves: leaves,
        start: DateTime(2026, 8, 3),
        endExclusive: DateTime(2026, 8, 4),
        settings: settings,
      );
      expect(stats.workedDays, 1);
      expect(stats.totalNetMinutes, 480);
    });
  });

  group('leaveUsedInCurrentYear', () {
    test('현재 연차년도 안의 사용량만 합산한다', () {
      const settings = AppSettings(); // 1/1 기준
      final leaves = [
        const LeaveEntry(date: '2026-03-02', amount: 1.0),
        const LeaveEntry(date: '2026-08-06', amount: 0.5),
        const LeaveEntry(date: '2025-12-24', amount: 1.0), // 작년
      ];
      final used = leaveUsedInCurrentYear(
        leaves,
        settings,
        today: DateTime(2026, 8, 7),
      );
      expect(used, 1.5);
    });
  });

  group('formatMinutes / parseHHmm', () {
    test('분을 시간 문자열로 표시한다', () {
      expect(formatMinutes(0), '0분');
      expect(formatMinutes(60), '1시간');
      expect(formatMinutes(90), '1시간 30분');
      expect(formatMinutes(45), '45분');
    });

    test('HH:mm 파싱', () {
      expect(parseHHmm('09:30'), (hour: 9, minute: 30));
      expect(parseHHmm('25:00'), isNull);
      expect(parseHHmm('abc'), isNull);
    });
  });
}
