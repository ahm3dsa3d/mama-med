import 'package:flutter/material.dart';
import '../services/battery_service.dart';
import '../theme/app_theme.dart';

/// Full-screen first-launch guidance explaining battery optimization.
/// Shown once on first launch; accessible again from Settings.
class BatteryGuidanceScreen extends StatelessWidget {
  final bool isFromSettings;
  const BatteryGuidanceScreen({super.key, this.isFromSettings = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // Header icon
              const SizedBox(height: 20),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🔔', style: TextStyle(fontSize: 58)),
                ),
              ),
              const SizedBox(height: 28),

              // Title
              Text(
                'مهم: تفعيل التنبيهات',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'لكي تصل تنبيهات الدواء في موعدها حتى عندما يكون الهاتف مُقفلاً، '
                'يُرجى اتباع الخطوات التالية:',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),

              // Steps
              Expanded(
                child: ListView(
                  children: const [
                    _StepCard(
                      number: '١',
                      title: 'السماح بالبطارية',
                      body: 'اضغط على الزر الأخضر أدناه وسيظهر لك طلب للسماح للتطبيق بالعمل في الخلفية. اضغط "السماح".',
                      icon: '🔋',
                    ),
                    _StepCard(
                      number: '٢',
                      title: 'تفعيل البدء التلقائي (هواتف Xiaomi / Huawei / Samsung)',
                      body: 'اذهب إلى: إعدادات الهاتف ← التطبيقات ← دواء ماما ← البدء التلقائي → تفعيل.\n\n'
                          'أو: إعدادات الطاقة ← تحسين الطاقة ← ابحث عن دواء ماما → لا تحسّن.',
                      icon: '⚙️',
                    ),
                    _StepCard(
                      number: '٣',
                      title: 'الإشعارات',
                      body: 'تأكد من تفعيل الإشعارات لهذا التطبيق في إعدادات الهاتف.',
                      icon: '🔔',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Primary CTA
              _BigButton(
                label: '✅ فتح إعدادات البطارية',
                color: const Color(0xFF43A047),
                textColor: Colors.white,
                onTap: () async {
                  await BatteryService().requestIgnoreBatteryOptimizations();
                },
              ),

              const SizedBox(height: 12),

              // Dismiss
              _BigButton(
                label: isFromSettings ? 'إغلاق' : 'تم ✓ فهمت',
                color: Colors.white.withValues(alpha: 0.15),
                textColor: Colors.white,
                onTap: () async {
                  if (!isFromSettings) {
                    await BatteryService().markGuidanceShown();
                  }
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String body;
  final String icon;
  const _StepCard({
    required this.number,
    required this.title,
    required this.body,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number badge
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFFFD54F),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A237E),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  const _BigButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
