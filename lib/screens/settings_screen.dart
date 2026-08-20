import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../providers/timesheet_provider.dart';
import '../services/export_service.dart';
import '../services/notification_service.dart';
import '../services/purchase_service.dart';
import '../utils/time_calculator.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;
    // 위젯 테스트에서는 등록되지 않으므로 nullable로 조회한다.
    final purchases = context.watch<PurchaseService?>();

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          const _SectionHeader('연차'),
          ListTile(
            title: const Text('총 연차'),
            subtitle: const Text('1년 동안 사용할 수 있는 연차 일수'),
            trailing: Text('${settings.totalAnnualLeave}일'),
            onTap: () => _editTotalLeave(context, settingsProvider),
          ),
          ListTile(
            title: const Text('연차년도 기준일'),
            subtitle: const Text('회계연도면 1월 1일, 입사일 기준이면 입사 월/일'),
            trailing: Text(
                '${settings.leaveYearStartMonth}월 ${settings.leaveYearStartDay}일'),
            onTap: () => _editLeaveYearStart(context, settingsProvider),
          ),
          const Divider(),
          const _SectionHeader('근무 기준'),
          ListTile(
            title: const Text('1일 소정근로시간'),
            subtitle: const Text('초과근무 판정 기준'),
            trailing: Text(formatMinutes(settings.standardDailyMinutes)),
            onTap: () => _editStandardDaily(context, settingsProvider),
          ),
          ListTile(
            title: const Text('휴게 차감 방식'),
            subtitle: Text(switch (settings.breakPolicy) {
              BreakPolicy.perFourHours => '근무 4시간마다 30분 차감 (근로기준법 기준)',
              BreakPolicy.fixed => settings.breakThresholdMinutes == 0
                  ? '근무시간과 관계없이 ${settings.breakMinutes}분 차감'
                  : '${formatMinutes(settings.breakThresholdMinutes)} 이상 근무 시 '
                      '${settings.breakMinutes}분 차감',
            }),
            trailing: Text(switch (settings.breakPolicy) {
              BreakPolicy.perFourHours => '법정',
              BreakPolicy.fixed => '고정',
            }),
            onTap: () => _editBreakPolicy(context, settingsProvider),
          ),
          if (settings.breakPolicy == BreakPolicy.fixed) ...[
            ListTile(
              title: const Text('휴게시간'),
              subtitle: const Text('고정 차감할 휴게시간'),
              trailing: Text('${settings.breakMinutes}분'),
              onTap: () => _editBreakMinutes(context, settingsProvider),
            ),
            ListTile(
              title: const Text('휴게 차감 기준'),
              subtitle: const Text('이 시간 이상 근무하면 차감 (0이면 항상 차감)'),
              trailing: Text(settings.breakThresholdMinutes == 0
                  ? '항상'
                  : formatMinutes(settings.breakThresholdMinutes)),
              onTap: () => _editBreakThreshold(context, settingsProvider),
            ),
          ],
          ListTile(
            title: const Text('기본 출근 시간'),
            subtitle: const Text('기록 수동 입력 시 초기값'),
            trailing: Text(settings.workStart),
            onTap: () => _editWorkTime(context, settingsProvider,
                isStart: true),
          ),
          ListTile(
            title: const Text('기본 퇴근 시간'),
            trailing: Text(settings.workEnd),
            onTap: () => _editWorkTime(context, settingsProvider,
                isStart: false),
          ),
          const Divider(),
          const _SectionHeader('알림'),
          SwitchListTile(
            title: const Text('퇴근 리마인더'),
            subtitle: Text(
                '출근하면 ${formatMinutes(settings.reminderOffsetMinutes)} 뒤에 알림'),
            value: settings.reminderEnabled,
            onChanged: (enabled) =>
                _toggleReminder(context, settingsProvider, enabled),
          ),
          if (settings.reminderEnabled)
            ListTile(
              title: const Text('알림 시점'),
              subtitle: const Text('출근 시각부터 알림까지의 시간'),
              trailing:
                  Text('출근 + ${formatMinutes(settings.reminderOffsetMinutes)}'),
              onTap: () => _editReminderOffset(context, settingsProvider),
            ),
          if (purchases != null) ...[
            const Divider(),
            const _SectionHeader('광고'),
            if (purchases.adsRemoved)
              const ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('광고 제거됨'),
                subtitle: Text('구매해 주셔서 감사합니다.'),
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('광고 제거'),
                subtitle: Text(purchases.product == null
                    ? '스토어에 연결할 수 없습니다.'
                    : '한 번만 구매하면 모든 광고가 사라집니다.'),
                trailing: purchases.pending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(purchases.product?.price ?? ''),
                enabled: purchases.product != null && !purchases.pending,
                onTap: purchases.buyRemoveAds,
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('구매 복원'),
                subtitle: const Text('재설치·기기 변경 후 이전 구매를 복원'),
                onTap: () => _restorePurchases(context, purchases),
              ),
            ],
          ],
          const Divider(),
          const _SectionHeader('데이터'),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('CSV 내보내기'),
            subtitle: const Text('엑셀에서 열 수 있는 기록 파일'),
            onTap: () => _exportCsv(context),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('백업 내보내기'),
            subtitle: const Text('기록·연차·설정을 JSON 파일로 저장'),
            onTap: () => _exportBackup(context),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('백업 복원'),
            subtitle: const Text('백업 파일로 현재 데이터를 교체'),
            onTap: () => _restoreBackup(context),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              '모든 기록 삭제',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text('출퇴근·연차 기록 삭제 (설정은 유지)'),
            onTap: () => _clearAll(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---- 연차 ----

  Future<void> _editTotalLeave(
      BuildContext context, SettingsProvider provider) async {
    final value = await _promptNumber(
      context,
      title: '총 연차',
      suffix: '일',
      initial: '${provider.settings.totalAnnualLeave}',
      allowDecimal: true,
    );
    if (value == null) return;
    await provider.update(provider.settings.copyWith(totalAnnualLeave: value));
  }

  Future<void> _editLeaveYearStart(
      BuildContext context, SettingsProvider provider) async {
    var month = provider.settings.leaveYearStartMonth;
    var day = provider.settings.leaveYearStartDay;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('연차년도 기준일'),
          content: Row(
            mainAxisAlignment: .center,
            children: [
              DropdownButton<int>(
                value: month,
                items: [
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem(value: m, child: Text('$m월')),
                ],
                onChanged: (v) => setState(() => month = v!),
              ),
              const SizedBox(width: 16),
              DropdownButton<int>(
                value: day,
                items: [
                  for (var d = 1; d <= 31; d++)
                    DropdownMenuItem(value: d, child: Text('$d일')),
                ],
                onChanged: (v) => setState(() => day = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await provider.update(provider.settings
        .copyWith(leaveYearStartMonth: month, leaveYearStartDay: day));
  }

  // ---- 근무 기준 ----

  Future<void> _editStandardDaily(
      BuildContext context, SettingsProvider provider) async {
    final value = await _promptNumber(
      context,
      title: '1일 소정근로시간',
      suffix: '시간',
      initial: '${provider.settings.standardDailyMinutes / 60}',
      allowDecimal: true,
    );
    if (value == null || value <= 0 || value > 24) return;
    await provider.update(provider.settings
        .copyWith(standardDailyMinutes: (value * 60).round()));
  }

  Future<void> _editBreakPolicy(
      BuildContext context, SettingsProvider provider) async {
    final selected = await showDialog<BreakPolicy>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('휴게 차감 방식'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, BreakPolicy.perFourHours),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('법정 기준'),
              subtitle: Text('근무 4시간마다 30분 차감\n(4시간 → 30분, 8시간 → 1시간)'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, BreakPolicy.fixed),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('고정 차감'),
              subtitle: Text('기준 시간 이상 근무하면 설정한 휴게시간을 차감'),
            ),
          ),
        ],
      ),
    );
    if (selected == null) return;
    await provider.update(provider.settings.copyWith(breakPolicy: selected));
  }

  Future<void> _editBreakThreshold(
      BuildContext context, SettingsProvider provider) async {
    final value = await _promptNumber(
      context,
      title: '휴게 차감 기준',
      suffix: '시간',
      initial: '${provider.settings.breakThresholdMinutes / 60}',
      allowDecimal: true,
    );
    if (value == null || value < 0 || value > 24) return;
    await provider.update(provider.settings
        .copyWith(breakThresholdMinutes: (value * 60).round()));
  }

  Future<void> _editBreakMinutes(
      BuildContext context, SettingsProvider provider) async {
    final value = await _promptNumber(
      context,
      title: '휴게시간',
      suffix: '분',
      initial: '${provider.settings.breakMinutes}',
    );
    if (value == null || value < 0) return;
    await provider.update(
        provider.settings.copyWith(breakMinutes: value.round()));
  }

  Future<void> _editWorkTime(
    BuildContext context,
    SettingsProvider provider, {
    required bool isStart,
  }) async {
    final current = parseHHmm(
        isStart ? provider.settings.workStart : provider.settings.workEnd);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current?.hour ?? (isStart ? 9 : 18),
        minute: current?.minute ?? 0,
      ),
    );
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await provider.update(isStart
        ? provider.settings.copyWith(workStart: formatted)
        : provider.settings.copyWith(workEnd: formatted));
  }

  // ---- 알림 ----

  /// 현재 근무 중이면 출근시각 + 오프셋으로 리마인더를 (재)예약한다.
  Future<void> _rescheduleForOpenRecord(
      BuildContext context, int offsetMinutes) async {
    final notifications = context.read<NotificationService>();
    final open = context.read<TimesheetProvider>().openRecord;
    if (open?.clockIn == null) return;
    await notifications.scheduleClockOutReminder(
      open!.clockIn!.add(Duration(minutes: offsetMinutes)),
    );
  }

  Future<void> _toggleReminder(BuildContext context,
      SettingsProvider provider, bool enabled) async {
    final notifications = context.read<NotificationService>();
    if (enabled) {
      final granted = await notifications.requestPermissions();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('알림 권한이 거부되어 리마인더를 켤 수 없습니다.')),
          );
        }
        return;
      }
      if (context.mounted) {
        await _rescheduleForOpenRecord(
            context, provider.settings.reminderOffsetMinutes);
      }
    } else {
      await notifications.cancelClockOutReminder();
    }
    await provider.update(
        provider.settings.copyWith(reminderEnabled: enabled));
  }

  Future<void> _editReminderOffset(
      BuildContext context, SettingsProvider provider) async {
    final value = await _promptNumber(
      context,
      title: '알림 시점 (출근 후 경과 시간)',
      suffix: '시간',
      initial: '${provider.settings.reminderOffsetMinutes / 60}',
      allowDecimal: true,
    );
    if (value == null || value <= 0 || value > 24) return;
    final offset = (value * 60).round();
    await provider.update(
        provider.settings.copyWith(reminderOffsetMinutes: offset));
    if (context.mounted) {
      await _rescheduleForOpenRecord(context, offset);
    }
  }

  // ---- 광고 ----

  Future<void> _restorePurchases(
      BuildContext context, PurchaseService purchases) async {
    // 복원 결과는 purchaseStream으로 돌아와 adsRemoved에 반영된다.
    await purchases.restore();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('구매 내역을 확인하고 있습니다.')),
      );
    }
  }

  // ---- 데이터 ----

  Future<void> _exportCsv(BuildContext context) async {
    final timesheet = context.read<TimesheetProvider>();
    final settings = context.read<SettingsProvider>().settings;
    final export = context.read<ExportService>();
    try {
      await export.shareCsv(
        records: timesheet.records,
        leaves: timesheet.leaves,
        settings: settings,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('내보내기 실패: $e')));
      }
    }
  }

  Future<void> _exportBackup(BuildContext context) async {
    final timesheet = context.read<TimesheetProvider>();
    final settings = context.read<SettingsProvider>().settings;
    final export = context.read<ExportService>();
    try {
      await export.shareBackup(
        settings: settings,
        records: timesheet.records,
        leaves: timesheet.leaves,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('백업 실패: $e')));
      }
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final timesheet = context.read<TimesheetProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final export = context.read<ExportService>();

    final BackupData? backup;
    try {
      backup = await export.pickAndParseBackup();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('백업 파일을 읽을 수 없습니다: $e')));
      }
      return;
    }
    if (backup == null || !context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('백업 복원'),
        content: Text(
          '기록 ${backup!.records.length}건, 연차 ${backup.leaves.length}건을 복원합니다.\n'
          '현재 데이터는 모두 백업 내용으로 교체됩니다. 계속할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('복원'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    await timesheet.restore(records: backup.records, leaves: backup.leaves);
    await settingsProvider.update(backup.settings);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('복원이 완료되었습니다.')));
    }
  }

  Future<void> _clearAll(BuildContext context) async {
    final timesheet = context.read<TimesheetProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모든 기록 삭제'),
        content: const Text('모든 출퇴근·연차 기록이 삭제됩니다.\n'
            '이 작업은 되돌릴 수 없습니다. 계속할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await timesheet.clearAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('모든 기록을 삭제했습니다.')));
    }
  }

  Future<double?> _promptNumber(
    BuildContext context, {
    required String title,
    required String suffix,
    required String initial,
    bool allowDecimal = false,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType:
              TextInputType.numberWithOptions(decimal: allowDecimal),
          autofocus: true,
          decoration: InputDecoration(suffixText: suffix),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
