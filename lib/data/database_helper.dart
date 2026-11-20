import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/medication.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mama_meds.db');

    final db = await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute(
                "ALTER TABLE medications ADD COLUMN frequency TEXT NOT NULL DEFAULT 'daily'");
            // Update existing alternate-day seeds if present
            await db.execute(
                "UPDATE medications SET frequency = 'alternate_days' WHERE name LIKE '%اكسامايد%' OR name LIKE '%كوليروز%'");
          } catch (_) {}
        }
      },
    );

    // Safety check to ensure column exists
    try {
      await db.execute(
          "ALTER TABLE medications ADD COLUMN frequency TEXT NOT NULL DEFAULT 'daily'");
      await db.execute(
          "UPDATE medications SET frequency = 'alternate_days' WHERE name LIKE '%اكسامايد%' OR name LIKE '%كوليروز%'");
    } catch (_) {}

    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    // Medications table
    await db.execute('''
      CREATE TABLE medications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        dose_instructions TEXT NOT NULL,
        period TEXT NOT NULL,
        frequency TEXT NOT NULL DEFAULT 'daily',
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Daily logs table — one row per medication per day
    await db.execute('''
      CREATE TABLE medication_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        is_taken INTEGER NOT NULL DEFAULT 0,
        taken_at TEXT,
        UNIQUE(medication_id, date),
        FOREIGN KEY (medication_id) REFERENCES medications(id) ON DELETE CASCADE
      )
    ''');

    // Insert seed data
    await _insertSeedData(db);
  }

  Future<void> _insertSeedData(Database db) async {
    final seeds = [
      // Morning (08:00)
      {'name': 'ريفاروسبير 10', 'dose_instructions': 'حبة واحدة', 'period': 'morning', 'frequency': 'daily', 'sort_order': 0},
      {'name': 'كونترولوك 20', 'dose_instructions': 'حبة واحدة', 'period': 'morning', 'frequency': 'daily', 'sort_order': 1},
      {'name': 'اكسامايد 10', 'dose_instructions': 'نصف حبة، يوم بعد يوم، على الريق', 'period': 'morning', 'frequency': 'alternate_days', 'sort_order': 2},
      {'name': 'كونكور 2.5', 'dose_instructions': 'نصف حبة يوميًا، على الريق', 'period': 'morning', 'frequency': 'daily', 'sort_order': 3},

      // Afternoon (14:00)
      {'name': 'Vitamin D3 5000 (ليمتلس)', 'dose_instructions': 'حبة واحدة', 'period': 'afternoon', 'frequency': 'daily', 'sort_order': 0},
      {'name': 'نو-يوريك 100', 'dose_instructions': 'حبة واحدة', 'period': 'afternoon', 'frequency': 'daily', 'sort_order': 1},
      {'name': 'كلوبكس 75', 'dose_instructions': 'حبة واحدة', 'period': 'afternoon', 'frequency': 'daily', 'sort_order': 2},
      {'name': 'كوبال F', 'dose_instructions': 'حبة واحدة', 'period': 'afternoon', 'frequency': 'daily', 'sort_order': 3},

      // Evening (20:00)
      {'name': 'سريبروماب 200', 'dose_instructions': 'حبة (وحبة تانية صباحًا)', 'period': 'evening', 'frequency': 'daily', 'sort_order': 0},
      {'name': 'كلوكوفاج 500', 'dose_instructions': 'حبة واحدة', 'period': 'evening', 'frequency': 'daily', 'sort_order': 1},
      {'name': 'ثيوتكس فورت', 'dose_instructions': 'حبة واحدة', 'period': 'evening', 'frequency': 'daily', 'sort_order': 2},

      // Before Bed (22:30)
      {'name': 'كال ماج', 'dose_instructions': 'حبة واحدة', 'period': 'before_bed', 'frequency': 'daily', 'sort_order': 0},
      {'name': 'كوليروز بلس 20', 'dose_instructions': 'يوم بعد يوم', 'period': 'before_bed', 'frequency': 'alternate_days', 'sort_order': 1},
    ];

    final batch = db.batch();
    for (final seed in seeds) {
      batch.insert('medications', {
        ...seed,
        'is_active': 1,
      });
    }
    await batch.commit(noResult: true);
  }

  // ─── Today's date key ────────────────────────────────────────────────────

  String get todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ─── Medications CRUD ────────────────────────────────────────────────────

  Future<List<Medication>> getAllMedications() async {
    final db = await database;
    final maps = await db.query(
      'medications',
      where: 'is_active = 1',
      orderBy: 'period, sort_order',
    );
    return maps.map((m) => Medication.fromMap(m)).toList();
  }

  Future<List<Medication>> getMedicationsByPeriod(String period) async {
    final db = await database;
    final maps = await db.query(
      'medications',
      where: 'period = ? AND is_active = 1',
      whereArgs: [period],
      orderBy: 'sort_order',
    );
    return maps.map((m) => Medication.fromMap(m)).toList();
  }

  Future<int> insertMedication(Medication medication) async {
    final db = await database;
    return db.insert('medications', medication.toMap());
  }

  Future<void> updateMedication(Medication medication) async {
    final db = await database;
    await db.update(
      'medications',
      medication.toMap(),
      where: 'id = ?',
      whereArgs: [medication.id],
    );
  }

  Future<void> deleteMedication(int id) async {
    final db = await database;
    await db.delete('medications', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Daily Log / Taken Status ─────────────────────────────────────────────

  /// Returns a map of medicationId → isTaken for today
  Future<Map<int, bool>> getTodayStatus() async {
    final db = await database;
    final date = todayKey;
    final maps = await db.query(
      'medication_logs',
      where: 'date = ?',
      whereArgs: [date],
    );
    final result = <int, bool>{};
    for (final m in maps) {
      result[m['medication_id'] as int] = (m['is_taken'] as int) == 1;
    }
    return result;
  }

  /// Returns today's log entries for a specific period
  Future<Map<int, bool>> getTodayStatusForPeriod(String period) async {
    final db = await database;
    final date = todayKey;
    final meds = await getMedicationsByPeriod(period);
    final medIds = meds.map((m) => m.id!).toList();
    if (medIds.isEmpty) return {};

    final placeholders = List.filled(medIds.length, '?').join(',');
    final maps = await db.rawQuery(
      'SELECT * FROM medication_logs WHERE date = ? AND medication_id IN ($placeholders)',
      [date, ...medIds],
    );

    final result = <int, bool>{};
    for (final m in maps) {
      result[m['medication_id'] as int] = (m['is_taken'] as int) == 1;
    }
    return result;
  }

  /// Returns true if ALL active medications scheduled for TODAY in a period are marked taken
  Future<bool> isPeriodComplete(String period) async {
    final meds = await getMedicationsByPeriod(period);
    final todayMeds = meds.where((m) => m.isDoseToday()).toList();
    if (todayMeds.isEmpty) return true;
    final statusMap = await getTodayStatusForPeriod(period);
    return todayMeds.every((m) => statusMap[m.id] == true);
  }

  /// Mark all active medications scheduled for today in a period as taken
  Future<void> markPeriodAsTaken(String period) async {
    final meds = await getMedicationsByPeriod(period);
    for (final med in meds) {
      if (med.isDoseToday()) {
        await toggleMedicationTaken(med.id!, true);
      }
    }
  }

  /// Toggle the taken status of a medication for today
  Future<void> toggleMedicationTaken(int medicationId, bool isTaken) async {
    final db = await database;
    final date = todayKey;
    final takenAt = isTaken ? DateTime.now().toIso8601String() : null;

    await db.insert(
      'medication_logs',
      {
        'medication_id': medicationId,
        'date': date,
        'is_taken': isTaken ? 1 : 0,
        'taken_at': takenAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all medications with their taken status for today, grouped by period
  Future<Map<String, List<Map<String, dynamic>>>> getTodayMedicationsGrouped() async {
    final allMeds = await getAllMedications();
    final statusMap = await getTodayStatus();

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final period in ['morning', 'afternoon', 'evening', 'before_bed']) {
      grouped[period] = allMeds
          .where((m) => m.period == period)
          .map((m) => {
                'medication': m,
                'isTaken': statusMap[m.id] ?? false,
                'isDoseToday': m.isDoseToday(),
              })
          .toList();
    }
    return grouped;
  }

  /// Returns true if a period has any medications not yet taken today.
  /// Used by BOOT_COMPLETED rescheduling to know which alarms are still needed.
  Future<List<String>> getPendingPeriods() async {
    final pending = <String>[];
    for (final period in ['morning', 'afternoon', 'evening', 'before_bed']) {
      final complete = await isPeriodComplete(period);
      if (!complete) pending.add(period);
    }
    return pending;
  }

  // ─── Stats ────────────────────────────────────────────────────────────────

  Future<Map<String, int>> getTodayStats() async {
    final allMeds = await getAllMedications();
    final todayMeds = allMeds.where((m) => m.isDoseToday()).toList();
    final statusMap = await getTodayStatus();
    final taken = todayMeds.where((m) => statusMap[m.id] == true).length;
    return {'total': todayMeds.length, 'taken': taken};
  }
}
