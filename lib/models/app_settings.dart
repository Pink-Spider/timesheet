/// 휴게시간 차감 방식.
enum BreakPolicy {
  /// 체류 4시간마다 30분 차감 (근로기준법 §54 근사) — 기본값.
  perFourHours,

  /// 체류가 기준 이상이면 설정된 휴게시간을 고정 차감.
  fixed;

  static BreakPolicy fromName(String? name) =>
      BreakPolicy.values.asNameMap()[name] ?? BreakPolicy.perFourHours;
}

/// 앱 전역 설정. SharedPreferences에 저장되며 백업 JSON에도 포함된다.
class AppSettings {
  const AppSettings({
    this.totalAnnualLeave = 15.0,
    this.leaveYearStartMonth = 1,
    this.leaveYearStartDay = 1,
    this.standardDailyMinutes = 480,
    this.breakPolicy = BreakPolicy.perFourHours,
    this.breakMinutes = 60,
    this.breakThresholdMinutes = 360,
    this.workStart = '09:00',
    this.workEnd = '18:00',
    this.reminderEnabled = false,
    this.reminderOffsetMinutes = 540,
  });

  /// 총 연차 (일 단위, 반차 지원을 위해 double)
  final double totalAnnualLeave;

  /// 연차년도 기준일 (회계연도면 1/1, 입사일 기준이면 해당 월/일)
  final int leaveYearStartMonth;
  final int leaveYearStartDay;

  /// 1일 소정근로시간(분). 초과근무 판정과 연차의 근무시간 인정에 사용.
  final int standardDailyMinutes;

  /// 휴게 차감 방식.
  final BreakPolicy breakPolicy;

  /// [BreakPolicy.fixed] 전용: 차감할 휴게시간(분).
  final int breakMinutes;

  /// [BreakPolicy.fixed] 전용: 총 체류시간이 이 값 이상이면 휴게를 차감.
  /// 0이면 항상 차감.
  final int breakThresholdMinutes;

  /// 기본 출퇴근 시각 'HH:mm' — 기록 수동 입력 시 초기값.
  final String workStart;
  final String workEnd;

  /// 퇴근 리마인더: 출근 시각 + [reminderOffsetMinutes] 뒤에 일회성 알림.
  /// (기본 9시간 = 소정근로 8시간 + 휴게 1시간)
  final bool reminderEnabled;
  final int reminderOffsetMinutes;

  AppSettings copyWith({
    double? totalAnnualLeave,
    int? leaveYearStartMonth,
    int? leaveYearStartDay,
    int? standardDailyMinutes,
    BreakPolicy? breakPolicy,
    int? breakMinutes,
    int? breakThresholdMinutes,
    String? workStart,
    String? workEnd,
    bool? reminderEnabled,
    int? reminderOffsetMinutes,
  }) {
    return AppSettings(
      totalAnnualLeave: totalAnnualLeave ?? this.totalAnnualLeave,
      leaveYearStartMonth: leaveYearStartMonth ?? this.leaveYearStartMonth,
      leaveYearStartDay: leaveYearStartDay ?? this.leaveYearStartDay,
      standardDailyMinutes: standardDailyMinutes ?? this.standardDailyMinutes,
      breakPolicy: breakPolicy ?? this.breakPolicy,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      breakThresholdMinutes:
          breakThresholdMinutes ?? this.breakThresholdMinutes,
      workStart: workStart ?? this.workStart,
      workEnd: workEnd ?? this.workEnd,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderOffsetMinutes:
          reminderOffsetMinutes ?? this.reminderOffsetMinutes,
    );
  }

  Map<String, Object?> toMap() => {
        'totalAnnualLeave': totalAnnualLeave,
        'leaveYearStartMonth': leaveYearStartMonth,
        'leaveYearStartDay': leaveYearStartDay,
        'standardDailyMinutes': standardDailyMinutes,
        'breakPolicy': breakPolicy.name,
        'breakMinutes': breakMinutes,
        'breakThresholdMinutes': breakThresholdMinutes,
        'workStart': workStart,
        'workEnd': workEnd,
        'reminderEnabled': reminderEnabled,
        'reminderOffsetMinutes': reminderOffsetMinutes,
      };

  factory AppSettings.fromMap(Map<String, Object?> map) {
    const defaults = AppSettings();
    return AppSettings(
      totalAnnualLeave:
          (map['totalAnnualLeave'] as num?)?.toDouble() ??
              defaults.totalAnnualLeave,
      leaveYearStartMonth:
          map['leaveYearStartMonth'] as int? ?? defaults.leaveYearStartMonth,
      leaveYearStartDay:
          map['leaveYearStartDay'] as int? ?? defaults.leaveYearStartDay,
      standardDailyMinutes:
          map['standardDailyMinutes'] as int? ?? defaults.standardDailyMinutes,
      breakPolicy: BreakPolicy.fromName(map['breakPolicy'] as String?),
      breakMinutes: map['breakMinutes'] as int? ?? defaults.breakMinutes,
      breakThresholdMinutes: map['breakThresholdMinutes'] as int? ??
          defaults.breakThresholdMinutes,
      workStart: map['workStart'] as String? ?? defaults.workStart,
      workEnd: map['workEnd'] as String? ?? defaults.workEnd,
      reminderEnabled:
          map['reminderEnabled'] as bool? ?? defaults.reminderEnabled,
      reminderOffsetMinutes: map['reminderOffsetMinutes'] as int? ??
          defaults.reminderOffsetMinutes,
    );
  }
}
