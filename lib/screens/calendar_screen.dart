import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../providers/settings_provider.dart';
import '../providers/timesheet_provider.dart';
import '../utils/time_calculator.dart';
import '../widgets/leave_edit_sheet.dart';
import '../widgets/record_edit_sheet.dart';

/// 오프라인 달력. 모든 데이터가 로컬이라 네트워크 없이 동작한다.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final timesheet = context.watch<TimesheetProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('달력')),
      body: ListView(
        children: [
          TableCalendar<Object>(
            locale: 'ko_KR',
            firstDay: DateTime(2020, 1, 1),
            lastDay: DateTime(2036, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            onDaySelected: (selected, focused) => setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
            }),
            onPageChanged: (focused) => _focusedDay = focused,
            availableCalendarFormats: const {CalendarFormat.month: '월'},
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                final record = timesheet.recordOn(day);
                final leave = timesheet.leaveOn(day);
                if (record == null && leave == null) return null;
                return Row(
                  mainAxisAlignment: .center,
                  children: [
                    if (record != null)
                      _MarkerDot(
                        color: record.isComplete
                            ? Colors.green
                            : Colors.orange,
                      ),
                    if (leave != null)
                      _MarkerDot(color: theme.colorScheme.tertiary),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _DayDetail(day: _selectedDay),
          ),
        ],
      ),
    );
  }
}

class _MarkerDot extends StatelessWidget {
  const _MarkerDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final timesheet = context.watch<TimesheetProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm');

    final record = timesheet.recordOn(day);
    final leave = timesheet.leaveOn(day);

    final rows = <Widget>[];
    if (record != null) {
      final clockInText = record.clockIn != null
          ? timeFormat.format(record.clockIn!)
          : '--:--';
      final clockOutText = record.clockOut != null
          ? timeFormat.format(record.clockOut!)
          : '--:--';
      rows.add(_detailRow(theme, Icons.login, '출근 $clockInText'));
      rows.add(_detailRow(theme, Icons.logout, '퇴근 $clockOutText'));
      if (record.isComplete) {
        final net =
            netWorkMinutes(record.clockIn!, record.clockOut!, settings);
        final overtime = overtimeMinutes(net, settings.standardDailyMinutes);
        rows.add(_detailRow(
          theme,
          Icons.timer_outlined,
          '실근무 ${formatMinutes(net)}'
          '${overtime > 0 ? ' · 초과 ${formatMinutes(overtime)}' : ''}',
        ));
      }
      if (record.note != null) {
        rows.add(_detailRow(theme, Icons.notes, record.note!));
      }
    }
    if (leave != null) {
      rows.add(_detailRow(
        theme,
        Icons.beach_access_outlined,
        leave.isHalfDay ? '반차 (0.5일)' : '연차 (1일)'
        '${leave.note != null ? ' · ${leave.note}' : ''}',
      ));
    }
    if (rows.isEmpty) {
      rows.add(Text('기록 없음', style: theme.textTheme.bodyMedium));
    }

    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(
          DateFormat('M월 d일 EEEE', 'ko_KR').format(day),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...rows,
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showRecordEditSheet(context, day),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(record == null ? '기록 추가' : '기록 수정'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showLeaveEditSheet(context, day),
                icon: const Icon(Icons.beach_access_outlined, size: 18),
                label: Text(leave == null ? '연차 등록' : '연차 수정'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _detailRow(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
