import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/work_record.dart';
import '../providers/settings_provider.dart';
import '../providers/timesheet_provider.dart';
import '../utils/time_calculator.dart';

/// 특정 날짜의 출퇴근 기록을 추가/수정/삭제하는 바텀 시트.
Future<void> showRecordEditSheet(BuildContext context, DateTime day) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _RecordEditSheet(day: day),
    ),
  );
}

class _RecordEditSheet extends StatefulWidget {
  const _RecordEditSheet({required this.day});

  final DateTime day;

  @override
  State<_RecordEditSheet> createState() => _RecordEditSheetState();
}

class _RecordEditSheetState extends State<_RecordEditSheet> {
  TimeOfDay? _clockIn;
  TimeOfDay? _clockOut;
  bool _clockOutNextDay = false;
  late final TextEditingController _noteController;
  WorkRecord? _existing;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TimesheetProvider>();
    final settings = context.read<SettingsProvider>().settings;
    _existing = provider.recordOn(widget.day);

    if (_existing?.clockIn != null) {
      _clockIn = TimeOfDay.fromDateTime(_existing!.clockIn!);
    } else {
      final start = parseHHmm(settings.workStart);
      if (start != null) {
        _clockIn = TimeOfDay(hour: start.hour, minute: start.minute);
      }
    }
    if (_existing?.clockOut != null) {
      _clockOut = TimeOfDay.fromDateTime(_existing!.clockOut!);
      _clockOutNextDay =
          dateKey(_existing!.clockOut!) != _existing!.date;
    } else if (_existing == null) {
      // 새 기록을 만들 때만 기본 퇴근 시간을 제안한다. 근무 중인(퇴근 없는)
      // 기존 기록은 빈칸 그대로 두어 저장해도 퇴근이 찍히지 않게 한다.
      final end = parseHHmm(settings.workEnd);
      if (end != null) {
        _clockOut = TimeOfDay(hour: end.hour, minute: end.minute);
      }
    }
    _noteController = TextEditingController(text: _existing?.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  DateTime _toDateTime(TimeOfDay time, {bool nextDay = false}) {
    final base = nextDay
        ? widget.day.add(const Duration(days: 1))
        : widget.day;
    return DateTime(base.year, base.month, base.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    if (_clockIn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출근 시간을 입력하세요.')),
      );
      return;
    }
    final record = WorkRecord(
      date: dateKey(widget.day),
      clockIn: _toDateTime(_clockIn!),
      clockOut: _clockOut != null
          ? _toDateTime(_clockOut!, nextDay: _clockOutNextDay)
          : null,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );
    final provider = context.read<TimesheetProvider>();
    await provider.saveRecord(record);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final provider = context.read<TimesheetProvider>();
    await provider.deleteRecord(dateKey(widget.day));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickTime({required bool isClockIn}) async {
    final initial = (isClockIn ? _clockIn : _clockOut) ??
        const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isClockIn) {
        _clockIn = picked;
      } else {
        _clockOut = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = DateFormat('M월 d일 (E)', 'ko_KR').format(widget.day);
    final timeLabel = MaterialLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              Text('$title 근무 기록', style: theme.textTheme.titleLarge),
              if (_existing != null)
                IconButton(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '기록 삭제',
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TimeField(
                  label: '출근',
                  value: _clockIn != null
                      ? timeLabel.formatTimeOfDay(_clockIn!,
                          alwaysUse24HourFormat: true)
                      : '--:--',
                  onTap: () => _pickTime(isClockIn: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeField(
                  label: '퇴근',
                  value: _clockOut != null
                      ? timeLabel.formatTimeOfDay(_clockOut!,
                          alwaysUse24HourFormat: true)
                      : '--:--',
                  onTap: () => _pickTime(isClockIn: false),
                  onClear: _clockOut != null
                      ? () => setState(() {
                            _clockOut = null;
                            _clockOutNextDay = false;
                          })
                      : null,
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('퇴근이 다음 날 (자정 넘김)'),
            value: _clockOutNextDay,
            // 퇴근 시간이 비어 있으면 의미가 없으므로 비활성화한다.
            onChanged: _clockOut != null
                ? (v) => setState(() => _clockOutNextDay = v)
                : null,
          ),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: '메모',
              hintText: '재택, 외근 등',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  /// null이 아니면 값 지우기(✕) 버튼을 보여준다.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear != null
              ? IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: '$label 시간 지우기',
                )
              : null,
        ),
        child: Text(value, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
