import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/leave_entry.dart';
import '../providers/timesheet_provider.dart';
import '../utils/time_calculator.dart';

/// 특정 날짜의 연차(연차/반차)를 등록/수정/삭제하는 바텀 시트.
Future<void> showLeaveEditSheet(BuildContext context, DateTime day) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _LeaveEditSheet(day: day),
    ),
  );
}

class _LeaveEditSheet extends StatefulWidget {
  const _LeaveEditSheet({required this.day});

  final DateTime day;

  @override
  State<_LeaveEditSheet> createState() => _LeaveEditSheetState();
}

class _LeaveEditSheetState extends State<_LeaveEditSheet> {
  double _amount = 1.0;
  late final TextEditingController _noteController;
  LeaveEntry? _existing;

  @override
  void initState() {
    super.initState();
    _existing = context.read<TimesheetProvider>().leaveOn(widget.day);
    _amount = _existing?.amount ?? 1.0;
    _noteController = TextEditingController(text: _existing?.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final entry = LeaveEntry(
      date: dateKey(widget.day),
      amount: _amount,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );
    final provider = context.read<TimesheetProvider>();
    await provider.saveLeave(entry);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final provider = context.read<TimesheetProvider>();
    await provider.deleteLeave(dateKey(widget.day));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = DateFormat('M월 d일 (E)', 'ko_KR').format(widget.day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              Text('$title 연차', style: theme.textTheme.titleLarge),
              if (_existing != null)
                IconButton(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '연차 삭제',
                ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<double>(
            segments: const [
              ButtonSegment(value: 1.0, label: Text('연차 (1일)')),
              ButtonSegment(value: 0.5, label: Text('반차 (0.5일)')),
            ],
            selected: {_amount},
            onSelectionChanged: (selection) =>
                setState(() => _amount = selection.first),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: '메모',
              hintText: '오전 반차, 여름 휴가 등',
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
