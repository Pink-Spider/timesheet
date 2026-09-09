import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../providers/timesheet_provider.dart';
import '../utils/time_calculator.dart';

enum _StatsMode { weekly, monthly }

/// 주간/월간 통계. 저장된 집계값 없이 항상 원본 기록에서 계산하므로
/// 월간 통계는 매달 1일 자동으로 새 기간으로 넘어간다.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  _StatsMode _mode = .weekly;

  /// 주간이면 그 주의 월요일, 월간이면 그 달의 1일.
  DateTime _anchor = weekStartOf(DateTime.now());

  (DateTime, DateTime) get _range {
    switch (_mode) {
      case _StatsMode.weekly:
        return (_anchor, _anchor.add(const Duration(days: 7)));
      case _StatsMode.monthly:
        return (
          DateTime(_anchor.year, _anchor.month, 1),
          DateTime(_anchor.year, _anchor.month + 1, 1),
        );
    }
  }

  void _move(int direction) {
    setState(() {
      switch (_mode) {
        case _StatsMode.weekly:
          _anchor = _anchor.add(Duration(days: 7 * direction));
        case _StatsMode.monthly:
          _anchor = DateTime(_anchor.year, _anchor.month + direction, 1);
      }
    });
  }

  void _setMode(_StatsMode mode) {
    setState(() {
      _mode = mode;
      final now = DateTime.now();
      _anchor = mode == .weekly
          ? weekStartOf(now)
          : DateTime(now.year, now.month, 1);
    });
  }

  String get _periodLabel {
    final (start, end) = _range;
    switch (_mode) {
      case _StatsMode.weekly:
        final last = end.subtract(const Duration(days: 1));
        return '${DateFormat('M.d').format(start)} ~ ${DateFormat('M.d').format(last)}';
      case _StatsMode.monthly:
        return DateFormat('yyyy년 M월').format(start);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timesheet = context.watch<TimesheetProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final (start, end) = _range;
    final stats = calcPeriodStats(
      records: timesheet.records,
      leaves: timesheet.leaves,
      start: start,
      endExclusive: end,
      settings: settings,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('통계')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_StatsMode>(
            segments: const [
              ButtonSegment(value: _StatsMode.weekly, label: Text('주간')),
              ButtonSegment(value: _StatsMode.monthly, label: Text('월간')),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) => _setMode(selection.first),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              IconButton(
                onPressed: () => _move(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                _periodLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              IconButton(
                onPressed: () => _move(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _StatTiles(stats: stats),
          const SizedBox(height: 16),
          if (_mode == .weekly)
            _WeeklyBreakdown(start: start, settings: settings)
          else
            _MonthlyBreakdown(month: start, settings: settings),
          const SizedBox(height: 16),
          _LeaveCard(settings: settings),
        ],
      ),
    );
  }
}

class _StatTiles extends StatelessWidget {
  const _StatTiles({required this.stats});

  final PeriodStats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(context, '근무일수', '${stats.workedDays}일'),
            _row(context, '실근무', formatMinutes(stats.totalNetMinutes)),
            _row(context, '초과근무',
                formatMinutes(stats.totalOvertimeMinutes)),
            _row(context, '사용 연차', '${formatDays(stats.leaveDays)}일'),
            const Divider(),
            _row(
              context,
              '합계 (연차 인정 포함)',
              formatMinutes(stats.combinedMinutes),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool emphasize = false}) {
    final style = emphasize
        ? Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: .spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}

/// 주간: 요일별 실근무를 막대로 표시.
class _WeeklyBreakdown extends StatelessWidget {
  const _WeeklyBreakdown({required this.start, required this.settings});

  final DateTime start;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final timesheet = context.watch<TimesheetProvider>();
    final days = List.generate(7, (i) => start.add(Duration(days: i)));
    final nets = <int>[];
    for (final day in days) {
      final record = timesheet.recordOn(day);
      nets.add(record != null && record.isComplete
          ? netWorkMinutes(record.clockIn!, record.clockOut!, settings)
          : 0);
    }
    // 스케일 기준: 최대값과 소정근로 중 큰 쪽.
    final scale = max(nets.fold(0, max), settings.standardDailyMinutes);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Text('요일별 근무', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (var i = 0; i < 7; i++)
              _BreakdownBar(
                label: DateFormat('E', 'ko_KR').format(days[i]),
                minutes: nets[i],
                scaleMinutes: scale,
                standardMinutes: settings.standardDailyMinutes,
              ),
          ],
        ),
      ),
    );
  }
}

/// 월간: 주차별(월~일, 해당 월에 속한 날만) 실근무 합계.
class _MonthlyBreakdown extends StatelessWidget {
  const _MonthlyBreakdown({required this.month, required this.settings});

  final DateTime month;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final timesheet = context.watch<TimesheetProvider>();
    final firstDay = DateTime(month.year, month.month, 1);
    final nextMonth = DateTime(month.year, month.month + 1, 1);

    // 이 달의 날짜들을 주 시작(월요일)으로 묶는다.
    final weekTotals = <DateTime, int>{};
    for (var day = firstDay;
        day.isBefore(nextMonth);
        day = day.add(const Duration(days: 1))) {
      final record = timesheet.recordOn(day);
      final net = record != null && record.isComplete
          ? netWorkMinutes(record.clockIn!, record.clockOut!, settings)
          : 0;
      final week = weekStartOf(day);
      weekTotals[week] = (weekTotals[week] ?? 0) + net;
    }
    final weeks = weekTotals.keys.toList()..sort();
    final weeklyStandard = settings.standardDailyMinutes * 5;
    final scale = max(weekTotals.values.fold(0, max), weeklyStandard);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Text('주차별 근무', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '월 경계에 걸친 주는 이 달에 속한 날짜만 합산합니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < weeks.length; i++)
              _BreakdownBar(
                label: '${i + 1}주',
                minutes: weekTotals[weeks[i]]!,
                scaleMinutes: scale,
                standardMinutes: weeklyStandard,
              ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownBar extends StatelessWidget {
  const _BreakdownBar({
    required this.label,
    required this.minutes,
    required this.scaleMinutes,
    required this.standardMinutes,
  });

  final String label;
  final int minutes;
  final int scaleMinutes;
  final int standardMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final over = minutes > standardMinutes;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text(label)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: scaleMinutes == 0 ? 0 : minutes / scaleMinutes,
                minHeight: 10,
                color: over
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              minutes == 0 ? '-' : formatMinutes(minutes),
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final timesheet = context.watch<TimesheetProvider>();
    final theme = Theme.of(context);
    final used = leaveUsage(timesheet.leaves, settings).total;
    final total = settings.totalAnnualLeave;
    final remaining = total - used;
    final start = leaveYearStartFor(
      DateTime.now(),
      settings.leaveYearStartMonth,
      settings.leaveYearStartDay,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Text('연차 현황', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '연차년도 시작: ${DateFormat('yyyy.M.d').format(start)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : (used / total).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Text('사용 ${formatDays(used)}일',
                    style: theme.textTheme.bodyMedium),
                Text(
                  '남음 ${formatDays(remaining)}일 / 총 ${formatDays(total)}일',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
