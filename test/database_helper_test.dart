import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mama_meds/data/database_helper.dart';
import 'package:mama_meds/models/medication.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory directory;
  late String path;
  late DatabaseHelper helper;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mama_meds_test_');
    path = '${directory.path}/test.db';
    helper = DatabaseHelper.forTesting(path);
  });
  tearDown(() async {
    await helper.close();
    await directory.delete(recursive: true);
  });

  Future<void> createLegacyDatabase({bool hasFrequency = false}) async {
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE medications ('
          'id INTEGER PRIMARY KEY, name TEXT NOT NULL, '
          'dose_instructions TEXT NOT NULL, period TEXT NOT NULL, '
          '${hasFrequency ? "frequency TEXT NOT NULL DEFAULT 'daily', " : ""}'
          'is_active INTEGER NOT NULL DEFAULT 1, '
          'sort_order INTEGER NOT NULL DEFAULT 0)',
        );
        for (final name in [
          'اكسامايد اختبار',
          'كوليروز اختبار',
          'دواء تجريبي',
        ]) {
          await db.insert('medications', {
            'name': name,
            'dose_instructions': 'تعليمات تجريبية',
            'period': 'morning',
            if (hasFrequency)
              'frequency': name == 'دواء تجريبي' ? 'alternate_days' : 'daily',
          });
        }
      },
    );
    await db.close();
  }

  test(
    'v1 migration does not infer alternate-day frequency from names',
    () async {
      await createLegacyDatabase();
      final meds = await helper.getAllMedications();
      expect(meds, hasLength(3));
      expect(meds.every((m) => m.frequency == 'daily'), isTrue);
      expect(
        meds.every((m) => m.doseInstructions == 'تعليمات تجريبية'),
        isTrue,
      );
      expect(meds.every((m) => m.period == 'morning'), isTrue);
      final db = await helper.database;
      expect(await db.getVersion(), 2);
    },
  );

  test('v1 database with frequency preserves all stored choices', () async {
    await createLegacyDatabase(hasFrequency: true);
    final meds = await helper.getAllMedications();
    expect(meds.map((m) => m.frequency), ['daily', 'daily', 'alternate_days']);
  });

  test('fresh installation keeps existing seed values unchanged', () async {
    final meds = await helper.getAllMedications();
    expect(meds, hasLength(13));
    expect(meds.where((m) => m.frequency == 'alternate_days').length, 2);
    expect(meds.where((m) => m.frequency == 'daily').length, 11);
  });

  test(
    'editing and reopening never overwrites saved frequencies or logs',
    () async {
      final db = await helper.database;
      await db.delete('medications');
      for (final name in ['اكسامايد اختبار', 'كوليروز اختبار']) {
        final id = await helper.insertMedication(
          Medication(
            name: name,
            doseInstructions: 'test only',
            period: 'evening',
            frequency: 'alternate_days',
          ),
        );
        final saved = (await helper.getAllMedications()).firstWhere(
          (m) => m.id == id,
        );
        await helper.updateMedication(saved.copyWith(frequency: 'daily'));
        await helper.toggleMedicationTaken(id, true);
      }
      final before = await db.query('medications', orderBy: 'id');
      final logs = await db.query('medication_logs', orderBy: 'id');
      for (var i = 0; i < 3; i++) {
        await helper.close();
        final reopened = await helper.database;
        expect(await reopened.query('medications', orderBy: 'id'), before);
        expect(await reopened.query('medication_logs', orderBy: 'id'), logs);
      }
    },
  );

  test('concurrent startup queries share the same database handle', () async {
    final databases = await Future.wait(
      List.generate(8, (_) => helper.database),
    );
    expect(databases.every((db) => identical(db, databases.first)), isTrue);
  });
}
