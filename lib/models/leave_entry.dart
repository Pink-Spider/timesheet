/// 연차 사용 기록. 하루에 하나만 존재하며 [amount]는 1.0(연차) 또는 0.5(반차).
class LeaveEntry {
  const LeaveEntry({
    this.id,
    required this.date,
    required this.amount,
    this.note,
  });

  final int? id;
  final String date;
  final double amount;
  final String? note;

  bool get isHalfDay => amount == 0.5;

  Map<String, Object?> toMap() => {
        'id': id,
        'date': date,
        'amount': amount,
        'note': note,
      };

  factory LeaveEntry.fromMap(Map<String, Object?> map) => LeaveEntry(
        id: map['id'] as int?,
        date: map['date'] as String,
        amount: (map['amount'] as num).toDouble(),
        note: map['note'] as String?,
      );
}
