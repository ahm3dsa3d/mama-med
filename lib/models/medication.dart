// Medication model — represents a single medication in the database
class Medication {
  final int? id;
  final String name;
  final String doseInstructions;
  final String period; // 'morning' | 'afternoon' | 'evening' | 'before_bed'
  final String frequency; // 'daily' | 'alternate_days'
  final bool isActive;
  final int sortOrder;

  const Medication({
    this.id,
    required this.name,
    required this.doseInstructions,
    required this.period,
    this.frequency = 'daily',
    this.isActive = true,
    this.sortOrder = 0,
  });

  bool isDoseToday([DateTime? date]) {
    if (frequency != 'alternate_days') return true;
    final target = date ?? DateTime.now();
    // Reference date (2026-01-01) for stable alternating day calculation
    final diff = DateTime(target.year, target.month, target.day)
        .difference(DateTime(2026, 1, 1))
        .inDays;
    return diff % 2 == 0;
  }

  Medication copyWith({
    int? id,
    String? name,
    String? doseInstructions,
    String? period,
    String? frequency,
    bool? isActive,
    int? sortOrder,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      doseInstructions: doseInstructions ?? this.doseInstructions,
      period: period ?? this.period,
      frequency: frequency ?? this.frequency,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'dose_instructions': doseInstructions,
      'period': period,
      'frequency': frequency,
      'is_active': isActive ? 1 : 0,
      'sort_order': sortOrder,
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      id: map['id'] as int?,
      name: map['name'] as String,
      doseInstructions: map['dose_instructions'] as String,
      period: map['period'] as String,
      frequency: (map['frequency'] as String?) ?? 'daily',
      isActive: (map['is_active'] as int) == 1,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Medication && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The 4 daily medication periods
enum MedicationPeriod {
  morning,
  afternoon,
  evening,
  beforeBed;

  String get key {
    switch (this) {
      case MedicationPeriod.morning:
        return 'morning';
      case MedicationPeriod.afternoon:
        return 'afternoon';
      case MedicationPeriod.evening:
        return 'evening';
      case MedicationPeriod.beforeBed:
        return 'before_bed';
    }
  }

  String get arabicLabel {
    switch (this) {
      case MedicationPeriod.morning:
        return 'صباحًا';
      case MedicationPeriod.afternoon:
        return 'بعد الظهر';
      case MedicationPeriod.evening:
        return 'المساء';
      case MedicationPeriod.beforeBed:
        return 'قبل النوم';
    }
  }

  String get emoji {
    switch (this) {
      case MedicationPeriod.morning:
        return '🌅';
      case MedicationPeriod.afternoon:
        return '☀️';
      case MedicationPeriod.evening:
        return '🌙';
      case MedicationPeriod.beforeBed:
        return '🛌';
    }
  }

  /// Index used for deterministic alarm ID calculation: p * 100 + i
  int get index2 {
    switch (this) {
      case MedicationPeriod.morning:
        return 0;
      case MedicationPeriod.afternoon:
        return 1;
      case MedicationPeriod.evening:
        return 2;
      case MedicationPeriod.beforeBed:
        return 3;
    }
  }

  static MedicationPeriod fromKey(String key) {
    switch (key) {
      case 'morning':
        return MedicationPeriod.morning;
      case 'afternoon':
        return MedicationPeriod.afternoon;
      case 'evening':
        return MedicationPeriod.evening;
      case 'before_bed':
        return MedicationPeriod.beforeBed;
      default:
        throw ArgumentError('Unknown period key: $key');
    }
  }
}
