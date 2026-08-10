/// 하루의 출퇴근 기록. [date]는 'yyyy-MM-dd' 키로, 하루에 하나만 존재한다.
/// 자정을 넘긴 퇴근은 출근한 날짜의 기록에 전체 타임스탬프로 저장된다.
class WorkRecord {
  const WorkRecord({
    this.id,
    required this.date,
    this.clockIn,
    this.clockOut,
    this.note,
  });

  final int? id;
  final String date;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final String? note;

  bool get isComplete => clockIn != null && clockOut != null;
  bool get isOpen => clockIn != null && clockOut == null;

  WorkRecord copyWith({
    int? id,
    String? date,
    DateTime? clockIn,
    DateTime? clockOut,
    String? note,
    bool clearClockOut = false,
  }) {
    return WorkRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      clockIn: clockIn ?? this.clockIn,
      clockOut: clearClockOut ? null : (clockOut ?? this.clockOut),
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'date': date,
        'clock_in': clockIn?.toIso8601String(),
        'clock_out': clockOut?.toIso8601String(),
        'note': note,
      };

  factory WorkRecord.fromMap(Map<String, Object?> map) => WorkRecord(
        id: map['id'] as int?,
        date: map['date'] as String,
        clockIn: map['clock_in'] != null
            ? DateTime.parse(map['clock_in'] as String)
            : null,
        clockOut: map['clock_out'] != null
            ? DateTime.parse(map['clock_out'] as String)
            : null,
        note: map['note'] as String?,
      );
}
