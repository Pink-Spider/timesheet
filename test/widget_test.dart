import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timesheet/db/database_helper.dart';
import 'package:timesheet/main.dart';
import 'package:timesheet/providers/settings_provider.dart';
import 'package:timesheet/providers/timesheet_provider.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    // testWidgets는 FakeAsync 존에서 돌기 때문에 isolate를 오가는 기본 ffi
    // 팩토리는 응답이 돌아오지 않아 멈춘다. 같은 isolate에서 동기 실행되는
    // NoIsolate 팩토리를 써야 한다.
    databaseFactory = databaseFactoryFfiNoIsolate;
    await initializeDateFormatting('ko_KR');
  });

  Future<(TimesheetProvider, SettingsProvider)> buildProviders() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = DatabaseHelper(dbPath: inMemoryDatabasePath);
    final timesheet = TimesheetProvider(db);
    await timesheet.load();
    return (timesheet, SettingsProvider(prefs));
  }

  testWidgets('출근 버튼을 누르면 근무 중 상태가 된다', (tester) async {
    final (timesheet, settings) = await buildProviders();

    await tester.pumpWidget(
      TimesheetApp(timesheet: timesheet, settings: settings),
    );

    expect(find.text('출근 전'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '출근'));
    await tester.pump();

    expect(find.text('근무 중'), findsOneWidget);
    expect(timesheet.status, ClockStatus.working);
  });

  testWidgets('퇴근까지 기록하면 퇴근 완료 상태가 된다', (tester) async {
    final (timesheet, settings) = await buildProviders();

    await tester.pumpWidget(
      TimesheetApp(timesheet: timesheet, settings: settings),
    );

    await tester.tap(find.widgetWithText(FilledButton, '출근'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '퇴근'));
    await tester.pump();

    expect(find.text('퇴근 완료'), findsOneWidget);
    expect(timesheet.todayRecord?.isComplete, isTrue);
  });
}
