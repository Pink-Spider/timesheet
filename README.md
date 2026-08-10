# 출퇴근기록장 (timesheet)

버튼 한 번으로 출퇴근을 기록하고 근무시간과 연차를 자동으로 계산하는 **100% 오프라인** Flutter 앱.

서버 없이 동작하며 모든 데이터는 기기 내부(sqlite, SharedPreferences)에만 저장됩니다.
회원가입도, 데이터 수집도, 광고도 없습니다.

| 홈 | 달력 | 통계 | 설정 |
|---|---|---|---|
| <img src="store/ss1_home.png" width="180"> | <img src="store/ss2_calendar.png" width="180"> | <img src="store/ss3_stats.png" width="180"> | <img src="store/ss4_settings.png" width="180"> |

## 주요 기능

- **원터치 출퇴근 기록** — 출근/퇴근 버튼 한 번, 앱 아이콘 길게 눌러 바로 기록(퀵 액션)
- **오프라인 달력** — 지난 기록 확인, 놓친 기록 추가·수정
- **주간·월간 통계** — 실근무시간, 초과근무, 근무일수 자동 집계
- **연차 관리** — 반차 지원, 연차년도 기준일 설정, 남은 연차 자동 계산
- **휴게시간 자동 차감** — 근로기준법 기준(4시간마다 30분) 또는 고정 차감 선택
- **퇴근 리마인더** — 출근 시각 + 설정한 시간이 지나면 알림
- **CSV 내보내기 / JSON 백업·복원**

## 개발

```sh
flutter pub get
flutter run
flutter test
```

빌드·배포 명령과 아키텍처 설명은 [CLAUDE.md](CLAUDE.md)를 참고하세요.

- Flutter (Dart SDK ^3.12.2), Android / iOS 타겟
- 데이터: sqflite + SharedPreferences (외부 통신 없음)
- 알림: flutter_local_notifications, 달력: table_calendar
- 도메인 규칙(휴게 차감, 주 경계, 연차년도 등)은 `lib/utils/time_calculator.dart` 순수 함수 계층에 집약

## 개인정보

이 앱은 어떠한 개인정보도 수집하지 않습니다. — [개인정보처리방침](https://pink-spider.github.io/timesheet-privacy/)