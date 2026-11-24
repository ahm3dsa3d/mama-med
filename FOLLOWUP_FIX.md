# Alarm reliability fix (base + follow-up reminders)

## Problems

1. Each 25-minute follow-up reminder was a one-shot alarm scheduled only when
   the app ran (app launch, foregrounding, or toggling a dose). The base
   alarm repeated daily, but the follow-up chain covered only the rest of
   that day. On any day mama did not open the app, the base alarm could ring
   but no follow-up reminders were scheduled at all. The 00:01 "midnight
   reset" notification only displayed a message; it never rescheduled
   anything.
2. The base alarm repeated daily at the period time, so it also rang on rest
   days of alternate-day medications, when no dose is due.
3. Arming one-shots for a fixed horizon only moves problem 1: after the
   horizon passed without an app interaction, all alarms stopped.

## Change

All alarms (the base alarm at the period time, slot 0, and the follow-up
reminders every 25 minutes afterward, slots 1..7) are now armed as one-shot
alarms for each of the next 7 days, and only for days with a dose due:

- Rest days of alternate-day medications are fully silent: no base alarm and
  no reminders. (A daily-repeating reminder was considered and rejected: it
  would ring on rest days.)
- Confirming a dose silences today's remaining alarms; the chain resumes on
  the next dose day without opening the app again.

The armed set is topped up on every app run (launch, foregrounding after a
date change, dose toggle, settings change, or a taken confirmation) and by a
daily WorkManager background task (`alarmRefreshCallback`, registered in
`main.dart` with a 24-hour periodic task, `ExistingPeriodicWorkPolicy.keep`).
The background task recomputes all dose-day alarms without any user
interaction, so the one-shot set keeps covering upcoming dose days even when
the app is not opened for a while, and a stale horizon cannot leave future
dose days unarmed. Android may delay the daily task (Doze, battery
restrictions, force-stop); the 7-day armed horizon plus the ~daily task gives
several days of slack, but an indefinitely force-stopped app cannot be
re-armed, and no implementation can promise that.

The old daily-recurring base alarm id (`periodIndex * 100`) is cancelled and
superseded; base and follow-up alarms now share the id space
`periodIndex * 1000 + dayOffset * 10 + slotIndex`.

Doses, dose instructions, period times, saved frequencies, taken logs and
seed data are untouched. The midnight reset notification and sound/vibration
settings are unchanged. Reboot handling is unchanged: the plugin's boot
receiver re-arms scheduled alarms. If the exact-alarm permission or battery
exemptions are missing, Android can still delay or suppress alarms; that is a
device setting, not changed by this patch.

## Validation

Tested with Flutter 3.41.9 and Dart 3.11.5, without increasing the project's
Dart minimum.

- `flutter test`: eleven tests passed (six existing, five new).
- `flutter analyze`: no issues found.
- Four of the five new tests fail when the previous behavior (daily-recurring
  base alarm plus follow-ups armed only while the app runs) is restored, then
  pass with the fix. This covers both rest-day silence and horizon coverage.
- New tests capture the real notification plugin channel calls and assert:
  the base alarm and every follow-up slot are armed as one-shots for each of
  the next 7 days; an alternate-day-only period is fully silent on rest days
  (no base alarm, no reminders) and fully armed on dose days; a taken
  confirmation silences today and re-arms from the next day; an empty
  period's alarms are cancelled; and no daily-recurring alarm remains.
- Notification, timezone, audio and WorkManager native calls are mocked. Test
  data is synthetic.

These are headless Flutter tests, not Android device tests. No APK was built
or installed. Real alarm sound, lock-screen wake, exact-alarm permission
handling, battery restrictions, reboot delivery, background-task timing and
actual next-day ringing remain unverified until tested on a real Android
phone.
