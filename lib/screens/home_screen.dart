import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/database_helper.dart';
import '../models/medication.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/period_section.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _db = DatabaseHelper();
  final _notifService = NotificationService();

  Map<String, List<Map<String, dynamic>>> _grouped = {};
  Map<String, String> _periodTimes = {};
  Map<String, TimeOfDay> _periodTimeOfDays = {};
  Map<String, int> _stats = {'total': 0, 'taken': 0};
  bool _loading = true;
  String? _lastLoadedDate;

  static const _periodOrder = ['morning', 'afternoon', 'evening', 'before_bed'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _scheduleAlarms();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Reload when app comes to foreground (handles midnight date change)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final today = _db.todayKey;
      if (_lastLoadedDate != null && _lastLoadedDate != today) {
        // Date changed (midnight crossed) — reload fresh state and re-schedule alarms
        _scheduleAlarms();
      }
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final grouped = await _db.getTodayMedicationsGrouped();
    final stats = await _db.getTodayStats();
    final times = <String, String>{};
    final timeOfDays = <String, TimeOfDay>{};

    for (final p in _periodOrder) {
      final t = await _notifService.getPeriodTime(p);
      timeOfDays[p] = t;
      times[p] = AppTheme.formatTime12H(t);
    }

    if (!mounted) return;
    setState(() {
      _grouped = grouped;
      _stats = stats;
      _periodTimes = times;
      _periodTimeOfDays = timeOfDays;
      _loading = false;
      _lastLoadedDate = _db.todayKey;
    });
  }

  Future<void> _scheduleAlarms() async {
    await _notifService.rescheduleAllAlarms();
    await _notifService.scheduleMidnightReset();
  }

  Future<void> _onToggle(String period, int medicationId, bool isTaken) async {
    await _db.toggleMedicationTaken(medicationId, isTaken);

    // Reload data for this period
    final updated = await _db.getTodayMedicationsGrouped();
    final stats = await _db.getTodayStats();

    if (!mounted) return;
    setState(() {
      _grouped = updated;
      _stats = stats;
    });

    // Check if period is now complete → cancel its remaining alarms
    final periodEnum = MedicationPeriod.fromKey(period);
    final isComplete = await _db.isPeriodComplete(period);
    if (isComplete) {
      await _notifService.onPeriodCompleted(periodEnum);
    } else {
      // Re-arm remaining alarms for this period (if we just unticked)
      await _notifService.rescheduleAllAlarms();
    }
  }

  String get _arabicDate {
    final now = DateTime.now();
    // Use Arabic locale for day/month names
    try {
      final formatter = DateFormat('EEEE، d MMMM', 'ar');
      return formatter.format(now);
    } catch (_) {
      // fallback
      return '${now.day}/${now.month}/${now.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // ─── App Header ───────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 175,
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.headerBg,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_rounded,
                      color: Colors.white, size: 30),
                  tooltip: 'الإعدادات',
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    );
                    _loadData(); // Reload in case settings changed
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A237E), Color(0xFF283593)],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('💊',
                                  style: TextStyle(fontSize: 36)),
                              const SizedBox(width: 12),
                              Text(
                                'دواء ماما',
                                style: AppTheme.appTitleStyle,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _arabicDate,
                            style: GoogleFonts.cairo(
                              fontSize: 20,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Progress bar
                          _DailyProgressBar(
                            taken: _stats['taken'] ?? 0,
                            total: _stats['total'] ?? 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ─── Period Sections ──────────────────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _periodOrder.length) {
                      return const SizedBox(height: 80); // bottom padding
                    }
                    final period = _periodOrder[index];
                    final periodEnum = MedicationPeriod.fromKey(period);
                    final meds = _grouped[period] ?? [];
                    final time = _periodTimes[period] ?? '';
                    final timeOfDay = _periodTimeOfDays[period];

                    // Auto-expand periods that are upcoming or incomplete
                    final now = DateTime.now();
                    bool initiallyExpanded = true;
                    if (timeOfDay != null) {
                      final periodDt = DateTime(
                        now.year,
                        now.month,
                        now.day,
                        timeOfDay.hour,
                        timeOfDay.minute,
                      );
                      // Collapse fully completed periods that are in the past
                      final isComplete = meds.isNotEmpty &&
                          meds.every((e) => e['isTaken'] as bool);
                      initiallyExpanded =
                          !isComplete || periodDt.isAfter(now);
                    }

                    return PeriodSection(
                      key: ValueKey(period),
                      period: periodEnum,
                      scheduledTime: time,
                      medicationsWithStatus: meds,
                      initiallyExpanded: initiallyExpanded,
                      onToggle: (medId, val) =>
                          _onToggle(period, medId, val),
                    );
                  },
                  childCount: _periodOrder.length + 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DailyProgressBar extends StatelessWidget {
  final int taken;
  final int total;
  const _DailyProgressBar({required this.taken, required this.total});

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : taken / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'تم أخذ $taken من $total دواء',
              style: GoogleFonts.cairo(
                fontSize: 17,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (taken == total && total > 0)
              Text(
                '🎉 أحسنتِ!',
                style: GoogleFonts.cairo(
                    fontSize: 17, color: Colors.white),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 10,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(
              taken == total && total > 0
                  ? const Color(0xFF69F0AE)
                  : const Color(0xFF90CAF9),
            ),
          ),
        ),
      ],
    );
  }
}
