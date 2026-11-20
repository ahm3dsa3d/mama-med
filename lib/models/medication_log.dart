/// A daily log entry tracking whether a medication was taken on a specific date
class MedicationLog {
  final int? id;
  final int medicationId;
  final String date; // 'YYYY-MM-DD'
  final bool isTaken;
  final String? takenAt; // ISO8601 timestamp or null

  const MedicationLog({
    this.id,
    required this.medicationId,
    required this.date,
    this.isTaken = false,
    this.takenAt,
  });

  MedicationLog copyWith({
    int? id,
    int? medicationId,
    String? date,
    bool? isTaken,
    String? takenAt,
  }) {
    return MedicationLog(
      id: id ?? this.id,
      medicationId: medicationId ?? this.medicationId,
      date: date ?? this.date,
      isTaken: isTaken ?? this.isTaken,
      takenAt: takenAt ?? this.takenAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'medication_id': medicationId,
      'date': date,
      'is_taken': isTaken ? 1 : 0,
      'taken_at': takenAt,
    };
  }

  factory MedicationLog.fromMap(Map<String, dynamic> map) {
    return MedicationLog(
      id: map['id'] as int?,
      medicationId: map['medication_id'] as int,
      date: map['date'] as String,
      isTaken: (map['is_taken'] as int) == 1,
      takenAt: map['taken_at'] as String?,
    );
  }
}
