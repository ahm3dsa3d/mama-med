# Follow-up reminder reliability fix

## Problem

Each 25-minute follow-up reminder was a one-shot alarm scheduled only when
the app ran (app launch, foregrounding, or toggling a dose). The base alarm
repeated daily, but the follow-up chain covered only the rest of that day. On
any day mama did not open the app, the base alarm could ring but no follow-up
reminders were scheduled at all. The 00:01 "midnight reset" notification only
displayed a message; it never rescheduled anything.

## Change

Follow-up reminders (slots 1..7 per period) now repeat daily
(`DateTimeComponents.time`), like the base alarm. When today's period is
already complete or a slot's time has passed, that slot's recurring chain
starts tomorrow. Confirming a dose therefore silences today's remaining
reminders and re-arms the chain for tomorrow without anyone opening the app.
Reboot handling is unchanged: the plugin's boot receiver re-arms scheduled
alarms, including recurring ones.

Doses, dose instructions, period times, saved frequencies, taken logs and
seed data are untouched. Alarm IDs, the base alarm, the midnight reset
notification, and sound/vibration settings are unchanged. If the exact-alarm
permission or battery exemptions are missing, Android can still delay or
suppress alarms; that is a device setting, not changed by this patch.

## Validation

Tested with Flutter 3.41.9 and Dart 3.11.5, without increasing the project's
Dart minimum.

- `flutter test`: nine tests passed (six existing, three new).
- `flutter analyze`: no issues found.
- The two new scheduling tests fail when the old one-shot/cancel behavior is
  restored, then pass with the fix.
- New tests capture the real notification plugin channel calls and assert
  every follow-up repeats daily, a pending period's chain fires from today,
  and a confirmed period's chain resumes tomorrow.
- Notification, timezone and audio native calls are mocked. Test data is
  synthetic.

These are headless Flutter tests, not Android device tests. No APK was built
or installed. Real alarm sound, lock-screen wake, exact-alarm permission
handling, battery restrictions, reboot delivery and actual next-day ringing
remain unverified until tested on a real Android phone.
