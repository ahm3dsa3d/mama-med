import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/medication.dart';
import '../theme/app_theme.dart';

/// A single medication row card with large name, dose instructions, and big checkbox
class MedicationCard extends StatelessWidget {
  final Medication medication;
  final bool isTaken;
  final ValueChanged<bool> onToggle;

  const MedicationCard({
    super.key,
    required this.medication,
    required this.isTaken,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppTheme.styleFor(medication.period);
    final isAlternate = medication.frequency == 'alternate_days';
    final isDoseDay = medication.isDoseToday();
    final isRestDay = isAlternate && !isDoseDay;

    return GestureDetector(
      onTap: () {
        if (isRestDay) return; // Rest day, no action needed
        HapticFeedback.mediumImpact();
        onToggle(!isTaken);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isRestDay
              ? const Color(0xFFF0F4F8)
              : isTaken
                  ? style.accentColor.withValues(alpha: 0.06)
                  : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRestDay
                ? const Color(0xFFCFD8DC)
                : isTaken
                    ? style.accentColor.withValues(alpha: 0.3)
                    : const Color(0xFFE0E0E0),
            width: isTaken || isRestDay ? 1.5 : 1,
          ),
          boxShadow: isTaken || isRestDay
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ─── Big Checkbox / Rest Icon ───────────────────────────────
              if (isRestDay)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECEFF1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFB0BEC5), width: 2),
                  ),
                  child: const Center(
                    child: Text('🌿', style: TextStyle(fontSize: 26)),
                  ),
                )
              else
                _BigCheckbox(
                  isTaken: isTaken,
                  accentColor: style.accentColor,
                  onToggle: onToggle,
                ),
              const SizedBox(width: 14),

              // ─── Medication Name + Dose + Alternate Day Badge ───────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            medication.name,
                            style: AppTheme.medNameStyle.copyWith(
                              color: isRestDay
                                  ? const Color(0xFF78909C)
                                  : isTaken
                                      ? AppTheme.takenColor
                                      : style.textColor,
                              decoration: isTaken
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              decorationColor: AppTheme.takenColor,
                              decorationThickness: 2.5,
                            ),
                          ),
                        ),
                        if (isAlternate) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isRestDay
                                  ? const Color(0xFFE0E0E0)
                                  : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isRestDay
                                    ? const Color(0xFFBDBDBD)
                                    : const Color(0xFF81C784),
                              ),
                            ),
                            child: Text(
                              isRestDay ? '⚪ اليوم راحة' : '🟢 جرعة اليوم',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isRestDay
                                    ? const Color(0xFF616161)
                                    : const Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isRestDay ? 'لا توجد جرعة اليوم — موعدها غدًا' : medication.doseInstructions,
                      style: AppTheme.doseStyle.copyWith(
                        color: isRestDay
                            ? const Color(0xFF90A4AE)
                            : isTaken
                                ? AppTheme.takenColor.withValues(alpha: 0.7)
                                : const Color(0xFF555555),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Taken badge ─────────────────────────────────────────────
              if (isTaken && !isRestDay)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.check_circle,
                    color: AppTheme.takenColor,
                    size: 30,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigCheckbox extends StatelessWidget {
  final bool isTaken;
  final Color accentColor;
  final ValueChanged<bool> onToggle;

  const _BigCheckbox({
    required this.isTaken,
    required this.accentColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onToggle(!isTaken);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isTaken ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isTaken ? accentColor : const Color(0xFFBDBDBD),
            width: 2.5,
          ),
        ),
        child: isTaken
            ? const Icon(Icons.check, color: Colors.white, size: 32)
            : null,
      ),
    );
  }
}
