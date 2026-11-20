import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BatteryService {
  static final BatteryService _instance = BatteryService._internal();
  factory BatteryService() => _instance;
  BatteryService._internal();

  static const String _prefKey = 'battery_optimization_prompted';

  /// Returns true if we should show the battery guidance screen on this launch.
  Future<bool> shouldShowGuidance() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool(_prefKey) ?? false;
    return !alreadyShown;
  }

  /// Mark the guidance as having been shown so we don't nag every launch.
  Future<void> markGuidanceShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  /// Reset the flag so the guidance can be shown again (from settings).
  Future<void> resetGuidanceFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  /// Request the system to ignore battery optimizations for this app.
  Future<void> requestIgnoreBatteryOptimizations() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await Permission.ignoreBatteryOptimizations.request();
    } catch (_) {
      await openBatterySettings();
    }
  }

  /// Open Android battery optimization and auto-start settings for this app.
  Future<void> openBatterySettings() async {
    if (kIsWeb || !Platform.isAndroid) return;

    // 1. Try Huawei App Launch / Startup Manager (EMUI)
    try {
      const huaweiIntent1 = AndroidIntent(
        action: 'android.intent.action.MAIN',
        componentName: 'com.huawei.systemmanager/.appcontrol.activity.StartupAppControlActivity',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await huaweiIntent1.launch();
      return;
    } catch (_) {}

    try {
      const huaweiIntent2 = AndroidIntent(
        action: 'android.intent.action.MAIN',
        componentName: 'com.huawei.systemmanager/.startupmgr.ui.StartupNormalAppListActivity',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await huaweiIntent2.launch();
      return;
    } catch (_) {}

    // 2. Try Xiaomi MIUI Autostart
    try {
      const xiaomiIntent = AndroidIntent(
        action: 'miui.intent.action.OP_AUTO_START',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await xiaomiIntent.launch();
      return;
    } catch (_) {}

    // 3. Try standard Android REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
    try {
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:com.mamameds.app.mama_meds',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
      return;
    } catch (_) {}

    // 4. Fall back to app details settings
    try {
      const fallback = AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:com.mamameds.app.mama_meds',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await fallback.launch();
    } catch (_) {}
  }
}
