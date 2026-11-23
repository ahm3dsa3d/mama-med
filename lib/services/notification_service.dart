import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/medication.dart';
import '../data/database_helper.dart';

/// Notification IDs follow the scheme: periodIndex * 100 + slotIndex
/// periodIndex: morning=0, afternoon=1, evening=2, beforeBed=3
/// slotIndex: 0 = base alarm, 1..7 = repeating reminders every ~25 min (up to 3h)
///
/// Both the base alarm and every follow-up reminder repeat daily
/// (DateTimeComponents.time), so alarms keep firing without the app being
/// opened. This gives us deterministic, cancellable IDs for each reminder.

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final DatabaseHelper _db = DatabaseHelper();
  final AudioPlayer _audioPlayer = AudioPlayer();

  static const String _channelId = 'mama_meds_alarm_channel_v9';
  static const String _channelName = 'منبه دواء ماما (صوت عالي مستمر)';
  static const String _channelDesc = 'تنبيهات مواعيد دواء ماما بصوت المنبه المرتفع المستمر';

  // Reminder slots: 0 min, 25 min, 50 min, ..., 175 min (7 reminders over 3 hours)
  static const List<int> _reminderOffsetMinutes = [0, 25, 50, 75, 100, 125, 150, 175];
  static const int _maxSlot = 7;

  Future<void> initialize() async {
    tz.initializeTimeZones();
    await _setLocalTimezone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _notifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _createNotificationChannel();
  }

  Future<void> _setLocalTimezone() async {
    // 1. Try fetching exact native IANA timezone from Android via MethodChannel
    try {
      const channel = MethodChannel('com.mamameds.app/timezone');
      final String? nativeTimezone = await channel.invokeMethod<String>('getLocalTimezone');
      if (nativeTimezone != null && nativeTimezone.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(nativeTimezone));
        return;
      }
    } catch (_) {}

    // 2. Fallback to standard timezone lookup
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      final timeZoneName = now.timeZoneName;

      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        return;
      } catch (_) {}

      // Match timezone by device UTC offset
      if (offset.inHours == 2) {
        tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
      } else if (offset.inHours == 3) {
        tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
      } else if (offset.inHours == 4) {
        tz.setLocalLocation(tz.getLocation('Asia/Dubai'));
      } else if (offset.inHours == 1) {
        tz.setLocalLocation(tz.getLocation('Africa/Algiers'));
      } else {
        tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
      }
    } catch (_) {
      // Fall back
    }
  }

  Future<void> _createNotificationChannel() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    try {
      for (int i = 1; i <= 8; i++) {
        await android?.deleteNotificationChannel('mama_meds_alarm_channel_v$i');
      }
    } catch (_) {}

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('mama'),
      enableVibration: true,
      enableLights: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    await android?.createNotificationChannel(channel);
  }

  /// Wakes up and lights the device screen even if locked or asleep
  Future<void> wakeUpScreen() async {
    try {
      const channel = MethodChannel('com.mamameds.app/timezone');
      await channel.invokeMethod('wakeScreen');
    } catch (_) {}
  }

  /// Play the alarm sound file directly through the ALARM audio stream at max volume in a continuous loop
  Future<void> playAlarmSound() async {
    try {
      await wakeUpScreen();
      await _audioPlayer.stop();
      await _audioPlayer.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransientExclusive,
        ),
      ));
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('audio/mama.mp4'));
    } catch (e) {
      debugPrint('Error playing alarm sound: $e');
    }
  }

  Future<void> stopAlarmSound() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  /// Show an instant test notification immediately and play loud alarm sound
  Future<void> showInstantTestNotification() async {
    final soundEnabled = await getSoundEnabled();
    final vibrationEnabled = await getVibrationEnabled();

    // 1. Light up screen
    await wakeUpScreen();

    // 2. Play loud alarm sound on Alarm stream continuously
    if (soundEnabled) {
      await playAlarmSound();
    }

    const String title = '💊 تنبيه: موعد دواء ماما';
    const String body = 'حان موعد تناول الدواء يا ماما 🌸 اضغطي هنا لتأكيد تناول الدواء';

    // 3. Display notification banner with insistent loop and action button
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: false, // Handled cleanly by playAlarmSound() to avoid echo
      enableVibration: vibrationEnabled,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      ticker: title,
      ongoing: true,
      autoCancel: false,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'action_taken',
          'تم تناول الدواء ✅',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
      styleInformation: const BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'دواء ماما 💊',
      ),
    );

    final notifDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: soundEnabled,
      ),
    );

    await _notifications.show(
      888,
      title,
      body,
      notifDetails,
      payload: 'test',
    );
  }

  /// Check if the app was launched by a notification action while terminated
  Future<void> checkLaunchNotification() async {
    try {
      final details = await _notifications.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp) {
        final response = details.notificationResponse;
        if (response != null) {
          await _onNotificationTapped(response);
        }
      }
    } catch (e) {
      debugPrint('Error checking launch notification: $e');
    }
  }

  Future<void> _onNotificationTapped(NotificationResponse response) async {
    await stopAlarmSound();
    final periodKey = response.payload;
    if (periodKey != null && periodKey.isNotEmpty && periodKey != 'test') {
      if (response.actionId == 'action_taken') {
        await _db.markPeriodAsTaken(periodKey);
        final periodEnum = MedicationPeriod.fromKey(periodKey);
        await onPeriodCompleted(periodEnum);
      }
    }
  }

  // ─── Permission Requests ──────────────────────────────────────────────────

  Future<bool> requestNotificationPermission() async {
    try {
      final android = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        if (granted == true) return true;
      }
    } catch (_) {}

    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {}
    return true;
  }

  Future<bool> requestExactAlarmPermission() async {
    try {
      final android = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestExactAlarmsPermission();
        return granted ?? true;
      }
    } catch (_) {}
    return true;
  }

  // ─── Period Time Preferences ──────────────────────────────────────────────

  Future<TimeOfDay> getPeriodTime(String period) async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = {
      'morning': '08:00',
      'afternoon': '14:00',
      'evening': '20:00',
      'before_bed': '22:30',
    };
    final stored = prefs.getString('period_time_$period') ?? defaults[period]!;
    final parts = stored.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> setPeriodTime(String period, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    final formatted = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    await prefs.setString('period_time_$period', formatted);
  }

  Future<bool> getSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notification_sound') ?? true;
  }

  Future<bool> getVibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notification_vibration') ?? true;
  }

  // ─── Alarm Scheduling ─────────────────────────────────────────────────────

  /// Schedule all alarms for all 4 periods.
  /// Called on app launch, settings change, and BOOT_COMPLETED.
  Future<void> rescheduleAllAlarms() async {
    final pendingPeriods = await _db.getPendingPeriods();
    final allPeriods = ['morning', 'afternoon', 'evening', 'before_bed'];

    for (final period in allPeriods) {
      final periodEnum = MedicationPeriod.fromKey(period);
      final meds = await _db.getMedicationsByPeriod(period);
      if (meds.isEmpty) {
        // No medications configured for this period — cancel any alarms
        await cancelPeriodAlarms(periodEnum);
        continue;
      }
      final isPending = pendingPeriods.contains(period);
      await _schedulePeriodAlarms(periodEnum, isPeriodPendingToday: isPending);
    }
  }

  /// Schedule alarms for a single period.
  /// - Slot 0: Primary recurring daily base alarm (rings at period time every day).
  /// - Slots 1..7: Recurring daily reminders every 25 min. If today's period is
  ///   already complete or a slot's time has passed, that slot starts tomorrow;
  ///   otherwise it also fires today. The chain does not depend on the app
  ///   being opened again.
  Future<void> _schedulePeriodAlarms(
    MedicationPeriod period, {
    bool isPeriodPendingToday = true,
  }) async {
    final periodTime = await getPeriodTime(period.key);
    final soundEnabled = await getSoundEnabled();
    final vibrationEnabled = await getVibrationEnabled();
    final now = DateTime.now();

    final String title = '${period.emoji} ${period.arabicLabel}';

    // ─── 1. Primary Daily Base Alarm (Slot 0) ──────────────────────────────
    final alarmId0 = period.index2 * 100 + 0;
    var baseDt = DateTime(
      now.year,
      now.month,
      now.day,
      periodTime.hour,
      periodTime.minute,
    );

    // If today's period is already complete or its time passed, schedule for tomorrow
    if (!isPeriodPendingToday || baseDt.isBefore(now)) {
      baseDt = baseDt.add(const Duration(days: 1));
    }

    final baseTz = tz.TZDateTime(
      tz.local,
      baseDt.year,
      baseDt.month,
      baseDt.day,
      baseDt.hour,
      baseDt.minute,
    );

    final String baseBody = 'حان وقت دواء ${period.arabicLabel} يا ماما 💊';

    final baseDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: soundEnabled,
        sound: soundEnabled ? const RawResourceAndroidNotificationSound('mama') : null,
        enableVibration: vibrationEnabled,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        visibility: NotificationVisibility.public,
        ticker: title,
        autoCancel: false,
        ongoing: true,
        additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT: loops sound continuously
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'action_taken',
            'تم تناول الدواء ✅',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
        styleInformation: BigTextStyleInformation(
          baseBody,
          contentTitle: title,
          summaryText: 'دواء ماما 💊',
        ),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: soundEnabled,
      ),
    );

    try {
      await _notifications.zonedSchedule(
        alarmId0,
        title,
        baseBody,
        baseTz,
        baseDetails,
        payload: period.key,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      try {
        await _notifications.zonedSchedule(
          alarmId0,
          title,
          baseBody,
          baseTz,
          baseDetails,
          payload: period.key,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (_) {}
    }

    // ─── 2. Follow-up Reminders (Slots 1..7) ────────────────────────────────
    for (int i = 1; i <= _maxSlot; i++) {
      final alarmId = period.index2 * 100 + i;

      final offsetMinutes = _reminderOffsetMinutes[i];
      var reminderDt = DateTime(
        now.year,
        now.month,
        now.day,
        periodTime.hour,
        periodTime.minute,
      ).add(Duration(minutes: offsetMinutes));

      // Today's occurrence fires only if the period is still pending and the
      // slot's time has not passed. Otherwise the recurring chain starts
      // tomorrow: after mama confirms today's dose, reminders must not ring
      // again today, but they must ring tomorrow without the app being opened.
      if (!isPeriodPendingToday || reminderDt.isBefore(now)) {
        reminderDt = reminderDt.add(const Duration(days: 1));
      }

      final reminderTz = tz.TZDateTime(
        tz.local,
        reminderDt.year,
        reminderDt.month,
        reminderDt.day,
        reminderDt.hour,
        reminderDt.minute,
      );

      final String reminderBody = 'تذكير: لم يتم أخذ أدوية ${period.arabicLabel} بعد 💊';
      final reminderDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          playSound: soundEnabled,
          sound: soundEnabled ? const RawResourceAndroidNotificationSound('mama') : null,
          enableVibration: vibrationEnabled,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          visibility: NotificationVisibility.public,
          ticker: title,
          autoCancel: false,
          ongoing: true,
          additionalFlags: Int32List.fromList([4]),
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'action_taken',
              'تم تناول الدواء ✅',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
          styleInformation: BigTextStyleInformation(
            reminderBody,
            contentTitle: title,
            summaryText: 'دواء ماما 💊',
          ),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: soundEnabled,
        ),
      );

      try {
        await _notifications.zonedSchedule(
          alarmId,
          title,
          reminderBody,
          reminderTz,
          reminderDetails,
          payload: period.key,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (_) {
        try {
          await _notifications.zonedSchedule(
            alarmId,
            title,
            reminderBody,
            reminderTz,
            reminderDetails,
            payload: period.key,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
          );
        } catch (_) {}
      }
    }
  }

  /// Cancel ALL pending alarms for a specific period (slots 0..7)
  Future<void> cancelPeriodAlarms(MedicationPeriod period) async {
    for (int i = 0; i <= _maxSlot; i++) {
      await _notifications.cancel(period.index2 * 100 + i);
    }
  }

  /// Called when mama marks all meds in a period as taken.
  /// Dismisses active notification, stops today's remaining reminders from
  /// ringing, and re-arms the recurring chain so it resumes tomorrow.
  Future<void> onPeriodCompleted(MedicationPeriod period) async {
    await stopAlarmSound();
    await _notifications.cancel(period.index2 * 100);
    await _schedulePeriodAlarms(period, isPeriodPendingToday: false);
  }

  /// Shows the midnight reset notification at 00:01 daily.
  /// This is only a quiet notification; alarms no longer depend on it,
  /// because every alarm repeats daily on its own.
  Future<void> scheduleMidnightReset() async {
    final now = DateTime.now();
    var midnight = DateTime(now.year, now.month, now.day + 1, 0, 1);
    final midnightTz = tz.TZDateTime.from(midnight, tz.local);

    const notifDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
      ),
    );

    // ID 999 = midnight reset marker
    await _notifications.zonedSchedule(
      999,
      'إعادة تشغيل تنبيهات الدواء',
      'تم تجديد قائمة أدوية ماما ليوم جديد',
      midnightTz,
      notifDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
