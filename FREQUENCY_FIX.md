# Frequency-preservation fix

## Change

Database upgrades no longer choose alternate-day frequency by matching a medication's name. Existing frequency choices are preserved. Fresh-install seed values, dose instructions, period times and taken logs are unchanged.

The database migration now checks the schema before adding the missing column instead of swallowing all database errors. Concurrent startup calls share one pending database open.

No attempt is made to reverse any frequency chosen by an older version. There is no reliable way to distinguish an older automatic choice from an intentional user choice. Review the installed settings against confirmed clinician or pharmacist instructions if needed.

## Validation

Tested with Flutter 3.41.9 and Dart 3.11.5, without increasing the project's Dart minimum.

- `flutter test --coverage`: six tests passed.
- `flutter analyze`: no issues found.
- The name-inference regression test fails when the removed SQL UPDATE is reintroduced, then passes with the fix restored.
- SQLite tests use real temporary databases, including version-1 upgrades and repeated version-2 reopens.
- The widget test renders the Arabic RTL home screen, taps a synthetic medication to save taken status, and opens settings. Native notification and audio calls are mocked. Test data is synthetic.

These are headless Flutter and SQLite tests, not Android device tests. No APK was built or installed. Real alarm sound, lock-screen wake, exact-alarm permissions, battery restrictions, restart behavior and next-day follow-up delivery remain unverified. The separate follow-up reminder scheduling concern is not changed by this patch.

## Apply locally if needed

From a clean checkout at base commit `d6e213b`, apply the accompanying patch with `git apply mama-med-frequency-fix.patch`, then run `flutter pub get`, `flutter test`, and `flutter analyze`.

For SQLite test setup on Linux, the added `sqflite_common_ffi` dev dependency supplies the test database backend. It is not used by the installed Android app.
