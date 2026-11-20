import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'services/notification_service.dart';
import 'services/battery_service.dart';
import 'screens/home_screen.dart';
import 'widgets/battery_guidance_screen.dart';
import 'theme/app_theme.dart';

/// Global navigator key so notification taps can push routes
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation — simpler for elderly users
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  } catch (_) {}

  // Initialize Arabic date formatting
  try {
    await initializeDateFormatting('ar', null);
    Intl.defaultLocale = 'ar';
  } catch (_) {}

  runApp(const MamaMedsApp());
}

class MamaMedsApp extends StatelessWidget {
  const MamaMedsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'دواء ماما',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,

      // ─── Full Arabic RTL Localization ─────────────────────────────────
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [
        Locale('ar', 'EG'),
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Clamp system text scale so the app stays readable but not overflowing.
      // RTL is automatically applied via locale + GlobalWidgetsLocalizations.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.2,
            ),
          ),
          child: child!,
        );
      },

      home: const _AppRoot(),
    );
  }
}

/// Root widget that shows battery guidance on first launch, then home screen
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Initialize notification service and schedule alarms
    try {
      final notifService = NotificationService();
      await notifService.initialize();
      await notifService.requestNotificationPermission();
      await notifService.requestExactAlarmPermission();
      await notifService.rescheduleAllAlarms();
      await notifService.scheduleMidnightReset();
    } catch (e) {
      debugPrint('Error initializing notification services: $e');
    }

    // 2. Check if first launch battery guidance should be shown
    try {
      final shouldShow = await BatteryService().shouldShowGuidance();
      if (shouldShow && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const BatteryGuidanceScreen(isFromSettings: false),
                fullscreenDialog: true,
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error checking battery guidance: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
