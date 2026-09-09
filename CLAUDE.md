# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`timesheet` — 개인용 출퇴근 기록 Flutter 앱 (Dart SDK ^3.12.2). 자체 서버 없이 동작하며, 모든 사용자 데이터는 로컬 sqlite(sqflite)와 SharedPreferences에 저장된다(네트워크는 AdMob 광고 로드에만 사용, 오프라인이어도 전 기능 동작). UI 문자열은 한국어. Android(`android/`)와 iOS(`ios/`)만 타겟.

기능: 버튼 출퇴근 기록, 오프라인 달력(table_calendar), 주간/월간 근무 통계, 초과근무 계산, 연차 관리(반차 지원), 과거 기록 수정, 평일 퇴근 리마인더 알림, CSV 내보내기, JSON 백업/복원, 앱 아이콘 퀵 액션(길게 눌러 출근/퇴근), AdMob 배너(통계·달력 탭만) + "광고 제거" 비소모성 인앱결제.

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
- `lib/services/` — `NotificationService`(퇴근 리마인더: 출근시각+오프셋 일회성 알림, 출근 시 예약/퇴근 시 취소 — `TimesheetProvider`의 onClockIn/onClockOut 훅으로 연결), `ExportService`(CSV/백업), `AdService`(iOS ATT → UMP 동의 → MobileAds 초기화 순서 고정, 배너 광고 단위 ID 보유 — 디버그는 구글 테스트 ID), `PurchaseService`(`remove_ads` 비소모성 IAP, adsRemoved 플래그를 SharedPreferences에 저장)
- 광고 규칙: 배너는 `AdBanner` 위젯 하나로, `MainShell`이 NavigationBar 바로 위에서 달력·통계 탭일 때만 트리에 넣는다(숨김이 아니라 제거 — 안 보이는 광고가 노출 집계되면 정책 위반). 홈·설정·퀵 액션 경로는 무광고. 광고 제거 구매 시 `AdService.init()` 자체를 건너뛴다. `AdService.init()`/`PurchaseService.init()`은 main()에서만 호출(위젯 테스트에서 플랫폼 채널 미사용 규칙) — `AdBanner`와 설정 화면은 `context.watch<PurchaseService?>()`로 nullable 조회하므로 테스트 트리에서는 광고 UI가 아예 없다
- 설정 화면 "광고" 섹션은 `purchases.product == null`(스토어 미연결·유료 계약 미활성 등 상품 조회 실패)이면 오류 문구 대신 **섹션 자체를 그리지 않는다** — 결제 UI에 오류를 노출하면 App Store 심사 가이드라인 2.1b 거부 사유가 된다
- `lib/screens/` — `MainShell`(NavigationBar) 아래 홈/달력/통계/설정 4탭, `lib/widgets/` — 기록/연차 편집 바텀 시트
- `lib/main.dart` — 부트스트랩. 프로바이더는 `runApp` 전에 생성해 퀵 액션 핸들러와 공유

## 정책 결정 지점 (lib/utils/time_calculator.dart)

도메인 규칙은 전부 이 파일에 있다. 규칙을 바꿀 때 UI를 건드리지 말 것:

- **휴게 차감**: 설정(`AppSettings.breakPolicy`)에서 선택 — 법정(체류 4시간마다 30분, 기본값) 또는 고정(체류 ≥ `breakThresholdMinutes`이면 `breakMinutes` 차감, 기준 0 = 항상)
- **주 경계**: 주는 항상 월~일. 월간 통계와 독립적이며, 월간 화면의 주차별 분해는 그 달에 속한 날짜만 합산
- **연차년도**: 설정의 기준일(월/일)부터 1년. 존재하지 않는 날짜(2/30)는 말일로 보정
- **연차 인정**: 연차 1일 = 소정근로시간 1일로 통계 합계에 가산
- **사용 연차**: 달력 기록 집계 + 설정의 수동 보정값(`leaveUsedAdjustment`). 설정 화면은 입력값 그대로가 아니라 **기록 집계와의 차이**를 보정값으로 저장하므로, 사용 연차를 직접 입력한 뒤에도 달력에 연차를 찍으면 사용량이 그만큼 늘어난다. 보정값은 저장 당시 연차년도(`leaveAdjustmentYearKey`)에만 유효 — 연차년도가 넘어가면 자동 무효가 되어 새 해가 기록만으로 시작한다. 통계의 근무시간 인정(`leaveCreditMinutes`)은 날짜가 있는 기록만 쓰므로 보정값의 영향을 받지 않는다
- **자정 넘김**: 퇴근 기록은 출근한 날짜의 레코드에 저장 (`TimesheetProvider.openRecord`가 어제 미퇴근 기록까지 탐색)

## Release

- 앱 ID `io.pinkspider.timesheet`, 표시명 `출퇴근기록장`(App Store에서 `출퇴근기록`이 선점되어 변경), Apple 팀 `Z53YTTRR32`.
- 현재 버전 `1.0.1+9`. AdMob 게시자 ID `pub-6329038356545416`(구 계정에서 이전 완료 — 중복 계정 문제로 구 계정은 폐쇄).
- Android 업로드 키스토어는 저장소 밖 `~/keystores/timesheet-upload.jks`, 비밀번호는 gitignore된 `android/key.properties`. 이 둘이 없으면 릴리즈 빌드는 디버그 키로 폴백된다 (Play 업로드 불가).
- `android/settings.gradle.kts`의 AGP는 8.12로 고정 — AGP 9(Built-in Kotlin)는 file_picker/share_plus/flutter_timezone과 아직 비호환. 이 플러그인들이 Built-in Kotlin을 지원하기 전까지 AGP 9로 올리지 말 것.

## Notes

- 새 패키지 추가 시 버전을 직접 적지 말고 `flutter pub add`로 해결시킬 것. 현재 `share_plus`는 `file_picker`와의 win32 충돌 때문에 ^12로 고정되어 있다 (둘 다 올릴 땐 함께 해결 필요).
- `flutter_local_notifications` v22는 모든 인자가 named (`initialize(settings:)`, `zonedSchedule(id:...)`, `cancel(id:)`), `file_picker` v11은 `FilePicker.pickFiles` static 호출.
- Android는 core library desugaring이 켜져 있다(`android/app/build.gradle.kts`) — flutter_local_notifications 요구사항.
- 위젯 테스트는 sqflite_common_ffi로 실제 DB 경로를 대체하고 `SharedPreferences.setMockInitialValues`를 사용한다. 알림/퀵 액션 초기화는 `main()`에만 있어 위젯 테스트에서 플랫폼 채널을 건드리지 않는다. `inMemoryDatabasePath`는 테스트 간에 같은 DB를 공유하므로 각 테스트 시작 시 `work_records`/`leave_entries`를 직접 delete 해 오염을 막는다.
- 코드가 Dart dot-shorthand 문법(`.fromSeed(...)`, `.center`)을 사용한다 — 문법 오류가 아니다.
- Linting은 표준 `flutter_lints` 룰셋 (`analysis_options.yaml`), 커스텀 룰 없음. analyzer가 `build/**`를 제외한다 — iOS SwiftPM이 build/ 아래에 받는 플러그인 소스가 분석에 잡히는 것을 막기 위함.
- iOS 광고 초기화는 **ATT 팝업이 반드시 UMP·MobileAds보다 먼저** 떠야 한다(가이드라인 2.1). 앱 실행 직후에는 iOS가 팝업을 무시하므로 `AdService._requestTrackingAuthorization()`이 1초 지연 후 요청한다 — 이 지연을 지우지 말 것. `Info.plist`의 `NSUserTrackingUsageDescription`이 없으면 iOS에서 팝업 없이 거부 처리된다.
- 기록 수정 시트는 **기존 기록을 열 때 퇴근 시간을 기본값으로 채우지 않는다** — 근무 중인 기록을 열어 저장만 해도 퇴근이 찍히던 버그 때문. 새 기록을 만들 때만 `settings.workEnd`를 제안한다.
- AdMob App ID는 `AndroidManifest.xml`/`Info.plist`에, 배너 광고 단위 ID는 `AdService`에 있다(실제 발급 ID 적용됨). 디버그 빌드는 광고 단위만 구글 테스트 ID로 자동 전환된다 — 실광고를 개발 중 노출/클릭하면 계정 정지 위험. `google_mobile_ads` v9는 `AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation` 사용(무접미사·CurrentOrientation 변형은 deprecated).
- IAP 제품 ID `remove_ads`는 Play Console·App Store Connect 양쪽에 동일하게 등록해야 한다. 영수증 검증 서버 없음 — 스토어 결제 + `구매 복원`(iOS 심사 필수 요건)으로만 처리.
