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

/// Regression tests for follow-up reminder reliability.
///
/// The follow-up chain (25-minute reminders after a period's base alarm) must
/// repeat daily on its own. Previously each reminder was a one-shot alarm
/// scheduled only when the app was opened, so the chain stopped on any day the
/// app was not opened. Native notification, timezone and audio calls are
/// mocked; these tests verify what the app asks the plugin to schedule, not
/// real Android alarm delivery.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final captured = <MethodCall>[];
  late Directory directory;

  // Period time chosen so every slot today is far from the current wall-clock
  // time: 23:58 + up to 175 minutes always lands late tonight or just after
  // midnight, never near "now" at ordinary test times.
  const morningHour = 23;
  const morningMinute = 58;

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
    SharedPreferences.setMockInitialValues({
      'period_time_morning': '23:58',
    });
    final db = await DatabaseHelper().database;
    await db.delete('medication_logs');
  });

  tearDownAll(() async {
    await DatabaseHelper().close();
    await directory.delete(recursive: true);
  });

  List<MethodCall> schedulesFor(List<int> ids) => captured
      .where(
        (c) =>
            c.method == 'zonedSchedule' &&
            ids.contains((c.arguments as Map)['id'] as int),
      )
      .toList();

  List<MethodCall> cancelsFor(List<int> ids) => captured
      .where(
        (c) =>
            c.method == 'cancel' &&
            ids.contains((c.arguments as Map)['id'] as int),
      )
      .toList();

  DateTime scheduledInstant(MethodCall call) =>
      DateTime.parse((call.arguments as Map)['scheduledDateTime'] as String);

  tz.TZDateTime expectedSlot(
    DateTime now,
    int offsetMinutes, {
    required bool pendingToday,
  }) {
    var dt = DateTime(now.year, now.month, now.day, morningHour, morningMinute)
        .add(Duration(minutes: offsetMinutes));
    if (!pendingToday || dt.isBefore(now)) {
      dt = dt.add(const Duration(days: 1));
    }
    return tz.TZDateTime(
      tz.local,
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
    );
  }

  const slotIds = [1, 2, 3, 4, 5, 6, 7];
  const offsets = [25, 50, 75, 100, 125, 150, 175];

  test(
    'pending period: every 25-minute follow-up repeats daily, none are '
    'one-shot or cancelled',
    () async {
      final now = DateTime.now();
      await NotificationService().rescheduleAllAlarms();

      final schedules = schedulesFor(slotIds);
      expect(schedules, hasLength(7));
      expect(cancelsFor(slotIds), isEmpty);
      for (var i = 0; i < 7; i++) {
        final call = schedules.firstWhere(
          (c) => (c.arguments as Map)['id'] == slotIds[i],
        );
        final args = call.arguments as Map;
        expect(
          args['matchDateTimeComponents'],
          DateTimeComponents.time.index,
          reason: 'slot ${slotIds[i]} must repeat daily, not fire once',
        );
        expect(
          scheduledInstant(call).isAtSameMomentAs(
            expectedSlot(now, offsets[i], pendingToday: true),
          ),
          isTrue,
        );
      }
    },
  );

  test(
    'taken confirmation: today\'s remaining reminders are silenced and the '
    'daily chain resumes tomorrow without opening the app',
    () async {
      await DatabaseHelper().markPeriodAsTaken('morning');
      final now = DateTime.now();
      await NotificationService().onPeriodCompleted(MedicationPeriod.morning);

      final schedules = schedulesFor(slotIds);
      expect(
        schedules,
        hasLength(7),
        reason: 'follow-ups must be re-armed for tomorrow, not dropped',
      );
      for (var i = 0; i < 7; i++) {
        final call = schedules.firstWhere(
          (c) => (c.arguments as Map)['id'] == slotIds[i],
        );
        final args = call.arguments as Map;
        expect(args['matchDateTimeComponents'], DateTimeComponents.time.index);
        final instant = scheduledInstant(call);
        final expected = expectedSlot(now, offsets[i], pendingToday: false);
        expect(
          instant.isAtSameMomentAs(expected),
          isTrue,
          reason: 'slot ${slotIds[i]} must not ring again today',
        );
        final tomorrowStart = DateTime(now.year, now.month, now.day + 1);
        expect(instant.isAfter(tomorrowStart), isTrue);
      }
    },
  );

  test(
    'period with no medications cancels all of its alarms',
    () async {
      // evening seeds exist; remove them for this test only
      final evening =
          await DatabaseHelper().getMedicationsByPeriod('evening');
      for (final med in evening) {
        await DatabaseHelper().deleteMedication(med.id!);
      }
      addTearDown(() async {
        var order = 0;
        for (final med in evening) {
          await DatabaseHelper().insertMedication(
            med.copyWith(sortOrder: order++),
          );
        }
      });

      await NotificationService().rescheduleAllAlarms();

      final eveningIds = List.generate(8, (i) => 200 + i);
      expect(cancelsFor(eveningIds), hasLength(8));
      expect(schedulesFor(eveningIds), isEmpty);
    },
  );
}
