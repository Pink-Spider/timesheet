import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db/database_helper.dart';
import 'providers/settings_provider.dart';
import 'providers/timesheet_provider.dart';
import 'screens/main_shell.dart';
import 'services/export_service.dart';
import 'services/notification_service.dart';

/// 퀵 액션 결과를 화면 어디서든 스낵바로 알리기 위한 전역 키.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsProvider(prefs);

  final notifications = NotificationService();
  await notifications.init();

  final db = DatabaseHelper();
  final timesheet = TimesheetProvider(
    db,
    // 출근하면 출근시각 + 오프셋에 일회성 리마인더 예약, 퇴근하면 취소.
    onClockIn: (clockInTime) async {
      final s = settings.settings;
      if (!s.reminderEnabled) return;
      await notifications.scheduleClockOutReminder(
        clockInTime.add(Duration(minutes: s.reminderOffsetMinutes)),
      );
    },
    onClockOut: notifications.cancelClockOutReminder,
  );
  await timesheet.load();

  // 앱 재시작 시 근무 중이면 리마인더를 멱등하게 재예약한다 (예약 유실 대비).
  final open = timesheet.openRecord;
  if (settings.settings.reminderEnabled && open?.clockIn != null) {
    await notifications.scheduleClockOutReminder(
      open!.clockIn!
          .add(Duration(minutes: settings.settings.reminderOffsetMinutes)),
    );
  }

  _setupQuickActions(timesheet);

  runApp(TimesheetApp(
    timesheet: timesheet,
    settings: settings,
    notifications: notifications,
  ));
}

/// 앱 아이콘을 길게 눌러 앱 진입과 동시에 출근/퇴근을 기록한다.
void _setupQuickActions(TimesheetProvider timesheet) {
  const quickActions = QuickActions();
  quickActions.initialize((type) async {
    final messenger = rootScaffoldMessengerKey.currentState;
    switch (type) {
      case 'action_clock_in':
        final result = await timesheet.clockIn();
        messenger?.showSnackBar(SnackBar(
          content: Text(result == ClockResult.success
              ? '출근을 기록했습니다.'
              : '오늘 이미 출근 기록이 있습니다. 홈 화면에서 변경하세요.'),
        ));
      case 'action_clock_out':
        final result = await timesheet.clockOut();
        messenger?.showSnackBar(SnackBar(
          content: Text(switch (result) {
            ClockResult.success => '퇴근을 기록했습니다.',
            ClockResult.noOpenRecord => '출근 기록이 없습니다.',
            _ => '이미 퇴근했습니다. 홈 화면에서 변경하세요.',
          }),
        ));
    }
  });
  quickActions.setShortcutItems(const [
    ShortcutItem(type: 'action_clock_in', localizedTitle: '출근하기'),
    ShortcutItem(type: 'action_clock_out', localizedTitle: '퇴근하기'),
  ]);
}

class TimesheetApp extends StatelessWidget {
  const TimesheetApp({
    super.key,
    required this.timesheet,
    required this.settings,
    this.notifications,
  });

  final TimesheetProvider timesheet;
  final SettingsProvider settings;
  final NotificationService? notifications;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: timesheet),
        ChangeNotifierProvider.value(value: settings),
        Provider<ExportService>(create: (_) => ExportService()),
        if (notifications != null)
          Provider<NotificationService>.value(value: notifications!),
      ],
      child: MaterialApp(
        title: '타임시트',
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        theme: ThemeData(
          colorScheme: .fromSeed(seedColor: Colors.teal),
        ),
        darkTheme: ThemeData(
          colorScheme: .fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.dark,
          ),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ko'), Locale('en')],
        home: const MainShell(),
      ),
    );
  }
}
