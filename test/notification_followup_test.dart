import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mama_meds/data/database_helper.dart';
import 'package:mama_meds/models/medication.dart';
import 'package:mama_meds/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/timezone.dart' as tz;

/// Regression tests for alarm reliability (base + follow-up reminders).
///
/// The base alarm and its follow-up reminders (every 25 minutes) must be
/// armed as per-dose-day one-shots for upcoming dose days without depending
/// on the app being opened the same day, must never fire on rest days of
/// alternate-day medications, and must stop after the day's dose is
/// confirmed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final captured = <MethodCall>[];
  late Directory directory;

  // Morning period time 23:58 keeps every follow-up slot (23:58 + up to
  // 175 min) in the future at ordinary test times, for deterministic counts.
  const morningHour = 23;
  const morningMinute = 58;

  // Morning index2 is 0, so alarm ids are dayOffset * 10 + slot with
  // slot 0 the base alarm and slots 1..7 the follow-ups; day 0 reuses the
  // legacy id range 0..7.
  int followupId(int dayOffset, int slot) => dayOffset * 10 + slot;
  bool isFollowupId(int id) {
    final day = id ~/ 10;
    final slot = id % 10;
    return id >= 0 && id <= 67 && day <= 6 && slot >= 0 && slot <= 7;
  }

  const alternateProbe = Medication(
    name: 'probe',
    doseInstructions: 'probe',
    period: 'morning',
    frequency: 'alternate_days',
  );

  setUpAll(() async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        if (call.method == 'create') {
          final id = (call.arguments as Map)['playerId'];
          messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null,
          );
        }
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('be.tramckrijte.workmanager/foreground_channel'),
      (_) async => true,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.mamameds.app/timezone'),
      (call) async {
        if (call.method == 'getLocalTimezone') return 'Africa/Cairo';
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async {
        captured.add(call);
        if (call.method == 'getNotificationAppLaunchDetails') {
          return {'notificationLaunchedApp': false};
        }
        return true;
      },
    );
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('mama_notif_test_');
    await databaseFactory.setDatabasesPath(directory.path);
    await NotificationService().initialize();
  });

  setUp(() async {
    captured.clear();
    SharedPreferences.setMockInitialValues({'period_time_morning': '23:58'});
    final db = await DatabaseHelper().database;
    await db.delete('medication_logs');
    await db.delete('medications');
  });

  tearDownAll(() async {
    await DatabaseHelper().close();
    await directory.delete(recursive: true);
  });

  Future<void> seedMorning({required String frequency}) async {
    await DatabaseHelper().insertMedication(
      Medication(
        name: 'دواء تجريبي',
        doseInstructions: 'بيانات اختبار فقط',
        period: 'morning',
        frequency: frequency,
      ),
    );
  }

  List<MethodCall> followupSchedules() => captured
      .where(
        (c) =>
            c.method == 'zonedSchedule' &&
            isFollowupId((c.arguments as Map)['id'] as int),
      )
      .toList();

  List<MethodCall> cancelsFor(bool Function(int) test) => captured
      .where(
        (c) => c.method == 'cancel' && test((c.arguments as Map)['id'] as int),
      )
      .toList();

  DateTime scheduledInstant(MethodCall call) =>
      DateTime.parse((call.arguments as Map)['scheduledDateTime'] as String);

  tz.TZDateTime expectedSlot(DateTime now, int dayOffset, int slot) {
    final day = DateTime(now.year, now.month, now.day + dayOffset);
    final dt = DateTime(
      day.year,
      day.month,
      day.day,
      morningHour,
      morningMinute,
    ).add(Duration(minutes: slot * 25));
    return tz.TZDateTime(
      tz.local,
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
    );
  }

  void expectOneShot(MethodCall call) {
    expect(
      (call.arguments as Map)['matchDateTimeComponents'],
      isNull,
      reason:
          'every alarm must be a per-day one-shot so rest days stay silent, id '
          '${(call.arguments as Map)['id']}',
    );
  }

  test('daily-dose period: base alarm and every follow-up slot are armed '
      'one-shot for each of the next 7 days, without needing the app that '
      'day', () async {
    await seedMorning(frequency: 'daily');
    final now = DateTime.now();
    await NotificationService().rescheduleAllAlarms();

    final schedules = followupSchedules();
    expect(schedules, hasLength(7 * 8));
    for (var d = 0; d < 7; d++) {
      for (var slot = 0; slot <= 7; slot++) {
        final id = followupId(d, slot);
        final call = schedules.firstWhere(
          (c) => (c.arguments as Map)['id'] == id,
          orElse: () => throw StateError('missing schedule for id $id'),
        );
        expectOneShot(call);
        expect(
          scheduledInstant(call).isAtSameMomentAs(expectedSlot(now, d, slot)),
          isTrue,
        );
      }
    }
  });

  test('alternate-day-only period: fully silent on rest days (no base alarm '
      'and no reminders), fully armed on dose days', () async {
    await seedMorning(frequency: 'alternate_days');
    final now = DateTime.now();
    await NotificationService().rescheduleAllAlarms();

    final schedules = followupSchedules();
    final scheduledDays = schedules
        .map((c) => ((c.arguments as Map)['id'] as int) ~/ 10)
        .toSet();
    for (var d = 0; d < 7; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      final doseDue = alternateProbe.isDoseToday(day);
      expect(
        scheduledDays.contains(d),
        doseDue,
        reason:
            'day offset $d ${doseDue ? "has a dose due and must be armed" : "is a rest day and must stay silent"}',
      );
      if (doseDue) {
        for (var slot = 0; slot <= 7; slot++) {
          final id = followupId(d, slot);
          final call = schedules.firstWhere(
            (c) => (c.arguments as Map)['id'] == id,
            orElse: () => throw StateError('missing schedule for id $id'),
          );
          expectOneShot(call);
          expect(
            scheduledInstant(call).isAtSameMomentAs(expectedSlot(now, d, slot)),
            isTrue,
          );
        }
      }
    }
  });

  test('taken confirmation: today is silenced and the chain resumes from the '
      'next day without opening the app again', () async {
    await seedMorning(frequency: 'daily');
    await DatabaseHelper().markPeriodAsTaken('morning');
    final now = DateTime.now();
    await NotificationService().onPeriodCompleted(MedicationPeriod.morning);

    final schedules = followupSchedules();
    final scheduledDays = schedules
        .map((c) => ((c.arguments as Map)['id'] as int) ~/ 10)
        .toSet();
    expect(
      scheduledDays.contains(0),
      isFalse,
      reason: 'today must be silent after confirmation',
    );
    expect(schedules, hasLength(6 * 8));
    final tomorrowStart = DateTime(now.year, now.month, now.day + 1);
    for (final call in schedules) {
      expectOneShot(call);
      expect(scheduledInstant(call).isAfter(tomorrowStart), isTrue);
    }
  });

  test(
    'period with no medications cancels its base alarm and all follow-ups',
    () async {
      // setUp leaves every period empty; morning gets a med for contrast.
      await seedMorning(frequency: 'daily');
      await NotificationService().rescheduleAllAlarms();

      // evening index2 is 2: legacy ids 200..207, horizon ids
      // 2000 + d * 10 + slot (slot 0..7).
      bool isEveningId(int id) =>
          (id >= 200 && id <= 207) ||
          (id >= 2000 && id <= 2067 && id % 10 <= 7);
      expect(cancelsFor(isEveningId), isNotEmpty);
      expect(
        captured.where(
          (c) =>
              c.method == 'zonedSchedule' &&
              isEveningId((c.arguments as Map)['id'] as int),
        ),
        isEmpty,
      );
    },
  );

  test('no daily-recurring alarm remains: every scheduled alarm is a '
      'one-shot (rest-day silence cannot leak through repetition)', () async {
    await seedMorning(frequency: 'daily');
    await NotificationService().rescheduleAllAlarms();

    final schedules = captured
        .where((c) => c.method == 'zonedSchedule')
        .toList();
    expect(schedules, isNotEmpty);
    for (final call in schedules) {
      expect(
        (call.arguments as Map)['matchDateTimeComponents'],
        isNull,
        reason: 'id ${(call.arguments as Map)['id']} must not repeat daily',
      );
    }
  });
}
