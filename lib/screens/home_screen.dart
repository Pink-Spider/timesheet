import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../providers/timesheet_provider.dart';
import '../utils/time_calculator.dart';
import '../widgets/record_edit_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _handleClockIn(BuildContext context) async {
    final provider = context.read<TimesheetProvider>();
    final result = await provider.clockIn();
    if (!context.mounted) return;
    if (result == ClockResult.needsOverwriteConfirm) {
      final ok = await _confirm(
        context,
        title: '출근 시간 변경',
        message: '오늘 이미 출근 기록이 있습니다.\n출근 시간을 지금으로 변경할까요?',
      );
      if (ok && context.mounted) {
        await provider.clockIn(overwrite: true);
      }
    }
  }

  Future<void> _handleClockOut(BuildContext context) async {
    final provider = context.read<TimesheetProvider>();
    final result = await provider.clockOut();
    if (!context.mounted) return;
    switch (result) {
      case ClockResult.needsOverwriteConfirm:
        final ok = await _confirm(
          context,
          title: '퇴근 시간 변경',
          message: '이미 퇴근 기록이 있습니다.\n퇴근 시간을 지금으로 변경할까요?',
        );
        if (ok && context.mounted) {
          await provider.clockOut(overwrite: true);
        }
      case ClockResult.noOpenRecord:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('출근 기록이 없습니다. 먼저 출근을 기록하세요.')),
        );
      case ClockResult.success:
        break;
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('변경'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final timesheet = context.watch<TimesheetProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final now = DateTime.now();
    final theme = Theme.of(context);

    final weekStart = weekStartOf(now);
    final weekStats = calcPeriodStats(
      records: timesheet.records,
      leaves: timesheet.leaves,
      start: weekStart,
      endExclusive: weekStart.add(const Duration(days: 7)),
      settings: settings,
    );
    final leaveUsed = leaveUsage(timesheet.leaves, settings).total;
    final leaveRemaining = settings.totalAnnualLeave - leaveUsed;

    return Scaffold(
      appBar: AppBar(title: const Text('타임시트')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            DateFormat('yyyy년 M월 d일 EEEE', 'ko_KR').format(now),
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          Text(
            DateFormat('HH:mm:ss').format(now),
            style: theme.textTheme.displayMedium
                ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _StatusCard(
            timesheet: timesheet,
            settings: settings,
            onTap: (timesheet.openRecord ?? timesheet.todayRecord) == null
                ? null
                : () => showRecordEditSheet(
                      context,
                      (timesheet.openRecord ?? timesheet.todayRecord)!
                          .clockIn!,
                    ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: timesheet.status == ClockStatus.working
                      ? null
                      : () => _handleClockIn(context),
                  icon: const Icon(Icons.login),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('출근', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: timesheet.status == ClockStatus.notClockedIn
                      ? null
                      : () => _handleClockOut(context),
                  icon: const Icon(Icons.logout),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('퇴근', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text('이번 주', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: '실근무',
                    value: formatMinutes(weekStats.totalNetMinutes),
                  ),
                  _SummaryRow(
                    label: '초과근무',
                    value: formatMinutes(weekStats.totalOvertimeMinutes),
                  ),
                  _SummaryRow(
                    label: '근무일수',
                    value: '${weekStats.workedDays}일',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text('연차', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: '남은 연차',
                    value:
                        '${formatDays(leaveRemaining)}일 / ${formatDays(settings.totalAnnualLeave)}일',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.timesheet,
    required this.settings,
    this.onTap,
  });

  final TimesheetProvider timesheet;
  final AppSettings settings;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm');

    final open = timesheet.openRecord;
    final today = timesheet.todayRecord;

    String statusText;
    String detailText;
    Color color;
    switch (timesheet.status) {
      case ClockStatus.notClockedIn:
        statusText = '출근 전';
        detailText = '출근 버튼을 눌러 하루를 시작하세요';
        color = theme.colorScheme.outline;
      case ClockStatus.working:
        final since = open!.clockIn!;
        final elapsed = DateTime.now().difference(since).inMinutes;
        statusText = '근무 중';
        detailText =
            '${timeFormat.format(since)} 출근 · ${formatMinutes(elapsed)} 경과';
        color = theme.colorScheme.primary;
      case ClockStatus.done:
        final net = netWorkMinutes(today!.clockIn!, today.clockOut!, settings);
        statusText = '퇴근 완료';
        detailText =
            '${timeFormat.format(today.clockIn!)} ~ ${timeFormat.format(today.clockOut!)} · 실근무 ${formatMinutes(net)}';
        color = theme.colorScheme.tertiary;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.circle, size: 14, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(statusText, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(detailText, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.edit_outlined,
                    size: 18, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: .spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
