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
    // NoIsolate ffi 팩토리는 in-memory DB를 프로세스 안에서 공유하므로,
    // 앞 테스트의 기록이 남지 않게 테이블을 비우고 시작한다.
    // (deleteDatabase는 FakeAsync 존에서 완료되지 않아 쓸 수 없다.)
    final db = DatabaseHelper(dbPath: inMemoryDatabasePath);
    final raw = await db.database;
    await raw.delete('work_records');
    await raw.delete('leave_entries');
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

  testWidgets('근무 중 기록은 수정 시트에서 저장해도 퇴근 시간이 생기지 않는다',
      (tester) async {
    final (timesheet, settings) = await buildProviders();

    await tester.pumpWidget(
      TimesheetApp(timesheet: timesheet, settings: settings),
    );

    await tester.tap(find.widgetWithText(FilledButton, '출근'));
    await tester.pump();

    // 홈 상태 카드를 탭하면 기록 수정 시트가 열린다.
    await tester.tap(find.text('근무 중'));
    await tester.pumpAndSettle();

    // 퇴근 필드는 기본값으로 채워지지 않고 빈칸이어야 한다.
    expect(find.text('--:--'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();

    expect(timesheet.todayRecord?.clockOut, isNull);
    expect(timesheet.status, ClockStatus.working);
  });

  testWidgets('수정 시트에서 퇴근 시간을 지우고 저장하면 다시 근무 중이 된다',
      (tester) async {
    final (timesheet, settings) = await buildProviders();

    await tester.pumpWidget(
      TimesheetApp(timesheet: timesheet, settings: settings),
    );

    await tester.tap(find.widgetWithText(FilledButton, '출근'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '퇴근'));
    await tester.pump();

    await tester.tap(find.text('퇴근 완료'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();

    expect(timesheet.todayRecord?.clockOut, isNull);
    expect(timesheet.status, ClockStatus.working);
  });
}
