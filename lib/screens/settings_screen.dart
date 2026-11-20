import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database_helper.dart';
import '../models/medication.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/battery_guidance_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper();
  final _notifService = NotificationService();

  List<Medication> _medications = [];
  Map<String, TimeOfDay> _periodTimes = {};
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _loading = true;

  static const _periods = ['morning', 'afternoon', 'evening', 'before_bed'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    final meds = await _db.getAllMedications();
    final times = <String, TimeOfDay>{};
    for (final p in _periods) {
      times[p] = await _notifService.getPeriodTime(p);
    }
    final sound = await _notifService.getSoundEnabled();
    final vibration = await _notifService.getVibrationEnabled();

    if (!mounted) return;
    setState(() {
      _medications = meds;
      _periodTimes = times;
      _soundEnabled = sound;
      _vibrationEnabled = vibration;
      _loading = false;
    });
  }

  Future<void> _savePeriodTime(String period, TimeOfDay time) async {
    await _notifService.setPeriodTime(period, time);
    await _notifService.rescheduleAllAlarms();
    setState(() => _periodTimes[period] = time);
  }

  Future<void> _pickTime(String period) async {
    final current = _periodTimes[period] ?? const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        ),
      ),
    );
    if (picked != null) await _savePeriodTime(period, picked);
  }

  Future<void> _addMedication() async {
    final result = await _showMedicationDialog(null);
    if (result != null) {
      await _db.insertMedication(result);
      await _loadSettings();
    }
  }

  Future<void> _editMedication(Medication med) async {
    final result = await _showMedicationDialog(med);
    if (result != null) {
      await _db.updateMedication(result);
      await _loadSettings();
    }
  }

  Future<void> _deleteMedication(Medication med) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'تأكيد الحذف',
          style: GoogleFonts.cairo(
              fontSize: 24, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'هل أنت متأكد من حذف دواء\n"${med.name}"؟\n\nلا يمكن التراجع عن هذا الإجراء.',
          style: GoogleFonts.cairo(fontSize: 20, height: 1.6),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('نعم، احذف الدواء',
                  style: GoogleFonts.cairo(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('إلغاء',
                  style: GoogleFonts.cairo(
                      fontSize: 20, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.deleteMedication(med.id!);
      await _loadSettings();
    }
  }

  Future<Medication?> _showMedicationDialog(Medication? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final doseCtrl =
        TextEditingController(text: existing?.doseInstructions ?? '');
    String selectedPeriod = existing?.period ?? 'morning';
    String selectedFrequency = existing?.frequency ?? 'daily';
    final formKey = GlobalKey<FormState>();

    return showDialog<Medication>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          scrollable: true,
          title: Text(
            existing == null ? 'إضافة دواء جديد' : 'تعديل الدواء',
            style: GoogleFonts.cairo(
                fontSize: 24, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Name
                TextFormField(
                  controller: nameCtrl,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.cairo(fontSize: 20),
                  decoration: InputDecoration(
                    labelText: 'اسم الدواء',
                    labelStyle: GoogleFonts.cairo(fontSize: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'أدخل اسم الدواء' : null,
                ),
                const SizedBox(height: 14),

                // Dose instructions
                TextFormField(
                  controller: doseCtrl,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.cairo(fontSize: 20),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'تعليمات الجرعة',
                    labelStyle: GoogleFonts.cairo(fontSize: 18),
                    hintText: 'مثال: نصف حبة على الريق',
                    hintStyle: GoogleFonts.cairo(fontSize: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'أدخل تعليمات الجرعة'
                      : null,
                ),
                const SizedBox(height: 14),

                // Frequency selector
                Text('تكرار أخذ الدواء:',
                    style: GoogleFonts.cairo(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setInnerState(() => selectedFrequency = 'daily'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selectedFrequency == 'daily'
                                ? AppTheme.headerBg.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selectedFrequency == 'daily'
                                  ? AppTheme.headerBg
                                  : const Color(0xFFBDBDBD),
                              width: selectedFrequency == 'daily' ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text('يوميًا',
                                style: GoogleFonts.cairo(
                                    fontSize: 18,
                                    fontWeight: selectedFrequency == 'daily'
                                        ? FontWeight.w700
                                        : FontWeight.w500)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => setInnerState(() => selectedFrequency = 'alternate_days'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selectedFrequency == 'alternate_days'
                                ? AppTheme.headerBg.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selectedFrequency == 'alternate_days'
                                  ? AppTheme.headerBg
                                  : const Color(0xFFBDBDBD),
                              width: selectedFrequency == 'alternate_days' ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text('يوم بعد يوم',
                                style: GoogleFonts.cairo(
                                    fontSize: 18,
                                    fontWeight: selectedFrequency == 'alternate_days'
                                        ? FontWeight.w700
                                        : FontWeight.w500)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Period selector
                Text('وقت أخذ الدواء:',
                    style: GoogleFonts.cairo(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MedicationPeriod.values.map((p) {
                    final isSelected = selectedPeriod == p.key;
                    return InkWell(
                      onTap: () => setInnerState(() => selectedPeriod = p.key),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.headerBg.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppTheme.headerBg : const Color(0xFFBDBDBD),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          '${p.emoji} ${p.arabicLabel}',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('إلغاء',
                        style: GoogleFonts.cairo(
                            fontSize: 20, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(
                        ctx,
                        Medication(
                          id: existing?.id,
                          name: nameCtrl.text.trim(),
                          doseInstructions: doseCtrl.text.trim(),
                          period: selectedPeriod,
                          frequency: selectedFrequency,
                          isActive: true,
                          sortOrder: existing?.sortOrder ?? 99,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.headerBg,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      existing == null ? 'إضافة' : 'حفظ',
                      style: GoogleFonts.cairo(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'الإعدادات',
          style: GoogleFonts.cairo(
              fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: AppTheme.headerBg,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                // ─── Period Times ────────────────────────────────────────
                _SectionHeader(title: '🕐 مواعيد فترات الدواء'),
                ...MedicationPeriod.values.map((p) {
                  final time = _periodTimes[p.key];
                  final timeStr = time != null ? AppTheme.formatTime12H(time) : '--:--';
                  final style = AppTheme.styleForPeriod(p);
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: style.accentColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                            child: Text(p.emoji,
                                style: const TextStyle(fontSize: 24))),
                      ),
                      title: Text(p.arabicLabel,
                          style: GoogleFonts.cairo(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      subtitle: Text('الموعد الحالي: $timeStr',
                          style: GoogleFonts.cairo(
                              fontSize: 18, color: style.accentColor)),
                      trailing: Icon(Icons.edit_rounded,
                          color: style.accentColor, size: 28),
                      onTap: () => _pickTime(p.key),
                    ),
                  );
                }),

                const SizedBox(height: 16),

                // ─── Notifications ────────────────────────────────────────
                _SectionHeader(title: '🔔 إعدادات التنبيهات'),
                Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  child: Column(
                    children: [
                      _ToggleTile(
                        title: 'صوت التنبيه',
                        subtitle: 'تشغيل صوت عند موعد الدواء',
                        icon: Icons.volume_up_rounded,
                        value: _soundEnabled,
                        onChanged: (v) async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('notification_sound', v);
                          await _notifService.rescheduleAllAlarms();
                          setState(() => _soundEnabled = v);
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _ToggleTile(
                        title: 'الاهتزاز',
                        subtitle: 'اهتزاز الهاتف عند موعد الدواء',
                        icon: Icons.vibration_rounded,
                        value: _vibrationEnabled,
                        onChanged: (v) async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('notification_vibration', v);
                          await _notifService.rescheduleAllAlarms();
                          setState(() => _vibrationEnabled = v);
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.notifications_active_rounded,
                              size: 26),
                          label: Text(
                            '🔔 تجربة رنين التنبيه الآن',
                            style: GoogleFonts.cairo(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () async {
                            await _notifService.showInstantTestNotification();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تم إرسال التنبيه التجريبي الآن 🔔',
                                    style: GoogleFonts.cairo(fontSize: 18),
                                    textAlign: TextAlign.center,
                                  ),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE65100),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ─── Battery Settings ──────────────────────────────────────
                _SectionHeader(title: '🔋 إعدادات البطارية والخلفية'),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.battery_charging_full_rounded,
                        size: 26),
                    label: Text(
                      'إرشادات ضبط البطارية للهاتف',
                      style: GoogleFonts.cairo(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BatteryGuidanceScreen(
                            isFromSettings: true,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      minimumSize:
                          const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ─── Medications ─────────────────────────────────────────
                _SectionHeader(title: '💊 إدارة الأدوية'),
                ...MedicationPeriod.values.map((p) {
                  final meds =
                      _medications.where((m) => m.period == p.key).toList();
                  final style = AppTheme.styleForPeriod(p);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                        child: Text(
                          '${p.emoji} ${p.arabicLabel}',
                          style: GoogleFonts.cairo(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: style.accentColor,
                          ),
                        ),
                      ),
                      ...meds.map((med) => Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                              title: Text(med.name,
                                  style: GoogleFonts.cairo(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(med.doseInstructions,
                                  style: GoogleFonts.cairo(fontSize: 18)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_rounded,
                                        color: style.accentColor,
                                        size: 28),
                                    onPressed: () =>
                                        _editMedication(med),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_rounded,
                                        color: Color(0xFFC62828),
                                        size: 28),
                                    onPressed: () =>
                                        _deleteMedication(med),
                                  ),
                                ],
                              ),
                            ),
                          )),
                    ],
                  );
                }),

                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_circle_rounded, size: 28),
                    label: Text(
                      'إضافة دواء جديد',
                      style: GoogleFonts.cairo(
                          fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    onPressed: _addMedication,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.headerBg,
                      foregroundColor: Colors.white,
                      minimumSize:
                          const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF37474F),
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: Icon(icon, size: 30, color: AppTheme.headerBg),
      title: Text(title,
          style: GoogleFonts.cairo(
              fontSize: 22, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle,
          style: GoogleFonts.cairo(fontSize: 18)),
      trailing: Transform.scale(
        scale: 1.3,
        child: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}
