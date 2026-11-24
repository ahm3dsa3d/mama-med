# Follow-up reminder reliability fix

## Problem

Each 25-minute follow-up reminder was a one-shot alarm scheduled only when
the app ran (app launch, foregrounding, or toggling a dose). The base alarm
repeated daily, but the follow-up chain covered only the rest of that day. On
any day mama did not open the app, the base alarm could ring but no follow-up
reminders were scheduled at all. The 00:01 "midnight reset" notification only
displayed a message; it never rescheduled anything.

## Change

Follow-up reminders are now armed as one-shot alarms for each of the next 7
days, and are topped up every time the app runs (launch, foregrounding after
a date change, dose toggle, settings change, or a taken confirmation, which
opens the app). The chain therefore no longer depends on opening the app the
same day.

Reminders are scheduled only for days with a dose due:

- Rest days of alternate-day medications stay silent. (A daily-repeating
  reminder was considered and rejected: it would ring on rest days.)
- Confirming a dose silences today's remaining reminders; the chain resumes
  on the next dose day without opening the app again.

The base alarm is unchanged and still repeats daily, including on rest days;
that pre-existing behavior is out of scope here. Reboot handling is
unchanged: the plugin's boot receiver re-arms scheduled alarms.

Horizon: 7 days. If the app is never opened and no notification is tapped for
more than 7 days, follow-ups stop after the armed horizon (the base alarm
still rings). Any app open or taken confirmation re-arms the next 7 days.

Doses, dose instructions, period times, saved frequencies, taken logs and
seed data are untouched. The base alarm ID, the midnight reset notification,
and sound/vibration settings are unchanged. If the exact-alarm permission or
battery exemptions are missing, Android can still delay or suppress alarms;
that is a device setting, not changed by this patch.

## Validation

Tested with Flutter 3.41.9 and Dart 3.11.5, without increasing the project's
Dart minimum.

- `flutter test`: ten tests passed (six existing, four new).
- `flutter analyze`: no issues found.
- Three of the four new tests fail when the old behavior (one-shot only when
  the app runs, or daily-repeating reminders) is restored, then pass with the
  fix. This covers the rest-day edge case.
- New tests capture the real notification plugin channel calls and assert:
  every follow-up slot is armed as a one-shot for each of the next 7 days; an
  alternate-day-only period gets reminders only on dose days and stays silent
  on rest days; a taken confirmation silences today and re-arms from the next
  day; an empty period's alarms are cancelled.
- Notification, timezone and audio native calls are mocked. Test data is
  synthetic.

These are headless Flutter tests, not Android device tests. No APK was built
or installed. Real alarm sound, lock-screen wake, exact-alarm permission
handling, battery restrictions, reboot delivery and actual next-day ringing
remain unverified until tested on a real Android phone.
