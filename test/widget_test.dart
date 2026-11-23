import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mama_meds/data/database_helper.dart';
import 'package:mama_meds/main.dart';
import 'package:mama_meds/models/medication.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
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
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async {
        if (call.method == 'getNotificationAppLaunchDetails') {
          return {'notificationLaunchedApp': false};
        }
        return true;
      },
    );
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('mama_widget_');
    await databaseFactory.setDatabasesPath(directory.path);
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ar');
    // Optional local font for a readable private visual capture.
    final fontPath = Platform.environment['MAMA_TEST_FONT'];
    if (fontPath != null) {
      final loader = FontLoader('Cairo');
      loader.addFont(
        Future.value(ByteData.sublistView(await File(fontPath).readAsBytes())),
      );
      await loader.load();
    }
    final db = await DatabaseHelper().database;
    await db.delete('medications');
    await DatabaseHelper().insertMedication(
      const Medication(
        name: 'دواء تجريبي',
        doseInstructions: 'بيانات اختبار فقط',
        period: 'morning',
      ),
    );
  });
  tearDownAll(() async {
    await DatabaseHelper().close();
    await directory.delete(recursive: true);
  });

  testWidgets('home renders, toggles taken status and opens settings', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = (Platform.environment['MAMA_TEST_FONT'] == null
        ? const Size(800, 1200)
        : const Size(430, 932));
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MamaMedsApp());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('دواء ماما'), findsOneWidget);
    expect(find.text('دواء تجريبي'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('دواء ماما'))),
      TextDirection.rtl,
    );
    expect(find.text('تم أخذ 0 من 1 دواء'), findsOneWidget);

    if (Platform.environment['MAMA_CAPTURE'] == '1') {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home.png'),
      );
    }
    await tester.tap(find.text('دواء تجريبي'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('تم أخذ 1 من 1 دواء'), findsOneWidget);
    expect(
      (await tester.runAsync(
        () => DatabaseHelper().getTodayStatus(),
      ))!.values.single,
      isTrue,
    );
    await tester.tap(find.byTooltip('الإعدادات'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('الإعدادات'), findsWidgets);
    if (Platform.environment['MAMA_CAPTURE'] == '1') {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/settings.png'),
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 50));
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
