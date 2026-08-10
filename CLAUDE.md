# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`timesheet` — 개인용 출퇴근 기록 Flutter 앱 (Dart SDK ^3.12.2). 서버 없이 100% 오프라인으로 동작하며, 모든 데이터는 로컬 sqlite(sqflite)와 SharedPreferences에 저장된다. UI 문자열은 한국어. Android(`android/`)와 iOS(`ios/`)만 타겟.

기능: 버튼 출퇴근 기록, 오프라인 달력(table_calendar), 주간/월간 근무 통계, 초과근무 계산, 연차 관리(반차 지원), 과거 기록 수정, 평일 퇴근 리마인더 알림, CSV 내보내기, JSON 백업/복원, 앱 아이콘 퀵 액션(길게 눌러 출근/퇴근).

## Commands

```sh
flutter pub get          # install dependencies
flutter run              # run the app (hot reload: r, hot restart: R)
flutter test             # run all tests (첫 실행은 컴파일 때문에 2분 이상 걸릴 수 있음)
flutter test test/time_calculator_test.dart           # run a single test file
flutter test --plain-name "출근 버튼"                  # run a single test by name
flutter analyze          # static analysis / lint
flutter build appbundle --release   # Play Console용 AAB (서명: android/key.properties)
flutter build ipa        # TestFlight용 ipa (팀 Z53YTTRR32, 자동 서명)
dart run flutter_launcher_icons     # assets/icon/*.png 변경 후 앱 아이콘 재생성
```

## Architecture

데이터 흐름: `sqflite(DatabaseHelper) → ChangeNotifier 프로바이더(전체 데이터를 메모리에 로드) → 화면에서 파생 계산`. 통계는 절대 저장하지 않고 항상 원본 기록에서 조회 시점에 집계한다 — "매달 1일 갱신"은 기간 필터로 구현되어 있다.

- `lib/models/` — `WorkRecord`(날짜당 1개, date `yyyy-MM-dd` UNIQUE), `LeaveEntry`(연차, amount 1.0/0.5), `AppSettings`
- `lib/db/database_helper.dart` — sqflite CRUD. 테스트에서는 `DatabaseHelper(dbPath: inMemoryDatabasePath)` + `sqflite_common_ffi`
- `lib/utils/time_calculator.dart` — **모든 정책이 모이는 순수 함수 계층** (아래 참고)
- `lib/providers/` — `TimesheetProvider`(기록/연차 상태, 출퇴근 트랜지션), `SettingsProvider`(SharedPreferences)
- `lib/services/` — `NotificationService`(퇴근 리마인더: 출근시각+오프셋 일회성 알림, 출근 시 예약/퇴근 시 취소 — `TimesheetProvider`의 onClockIn/onClockOut 훅으로 연결), `ExportService`(CSV/백업)
- `lib/screens/` — `MainShell`(NavigationBar) 아래 홈/달력/통계/설정 4탭, `lib/widgets/` — 기록/연차 편집 바텀 시트
- `lib/main.dart` — 부트스트랩. 프로바이더는 `runApp` 전에 생성해 퀵 액션 핸들러와 공유

## 정책 결정 지점 (lib/utils/time_calculator.dart)

도메인 규칙은 전부 이 파일에 있다. 규칙을 바꿀 때 UI를 건드리지 말 것:

- **휴게 차감**: 설정(`AppSettings.breakPolicy`)에서 선택 — 법정(체류 4시간마다 30분, 기본값) 또는 고정(체류 ≥ `breakThresholdMinutes`이면 `breakMinutes` 차감, 기준 0 = 항상)
- **주 경계**: 주는 항상 월~일. 월간 통계와 독립적이며, 월간 화면의 주차별 분해는 그 달에 속한 날짜만 합산
- **연차년도**: 설정의 기준일(월/일)부터 1년. 존재하지 않는 날짜(2/30)는 말일로 보정
- **연차 인정**: 연차 1일 = 소정근로시간 1일로 통계 합계에 가산
- **자정 넘김**: 퇴근 기록은 출근한 날짜의 레코드에 저장 (`TimesheetProvider.openRecord`가 어제 미퇴근 기록까지 탐색)

## Release

- 앱 ID `io.pinkspider.timesheet`, 표시명 `출퇴근기록장`(App Store에서 `출퇴근기록`이 선점되어 변경), Apple 팀 `Z53YTTRR32`.
- Android 업로드 키스토어는 저장소 밖 `~/keystores/timesheet-upload.jks`, 비밀번호는 gitignore된 `android/key.properties`. 이 둘이 없으면 릴리즈 빌드는 디버그 키로 폴백된다 (Play 업로드 불가).
- `android/settings.gradle.kts`의 AGP는 8.12로 고정 — AGP 9(Built-in Kotlin)는 file_picker/share_plus/flutter_timezone과 아직 비호환. 이 플러그인들이 Built-in Kotlin을 지원하기 전까지 AGP 9로 올리지 말 것.

## Notes

- 새 패키지 추가 시 버전을 직접 적지 말고 `flutter pub add`로 해결시킬 것. 현재 `share_plus`는 `file_picker`와의 win32 충돌 때문에 ^12로 고정되어 있다 (둘 다 올릴 땐 함께 해결 필요).
- `flutter_local_notifications` v22는 모든 인자가 named (`initialize(settings:)`, `zonedSchedule(id:...)`, `cancel(id:)`), `file_picker` v11은 `FilePicker.pickFiles` static 호출.
- Android는 core library desugaring이 켜져 있다(`android/app/build.gradle.kts`) — flutter_local_notifications 요구사항.
- 위젯 테스트는 sqflite_common_ffi로 실제 DB 경로를 대체하고 `SharedPreferences.setMockInitialValues`를 사용한다. 알림/퀵 액션 초기화는 `main()`에만 있어 위젯 테스트에서 플랫폼 채널을 건드리지 않는다.
- 코드가 Dart dot-shorthand 문법(`.fromSeed(...)`, `.center`)을 사용한다 — 문법 오류가 아니다.
- Linting은 표준 `flutter_lints` 룰셋 (`analysis_options.yaml`), 커스텀 룰 없음.
