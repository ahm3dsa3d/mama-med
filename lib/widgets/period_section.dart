import 'package:flutter/material.dart';
import '../models/medication.dart';
import '../theme/app_theme.dart';
import 'medication_card.dart';

/// Collapsible period section header + medication cards for one time period
class PeriodSection extends StatefulWidget {
  final MedicationPeriod period;
  final String scheduledTime; // e.g. "08:00"
  final List<Map<String, dynamic>> medicationsWithStatus;
  final bool initiallyExpanded;
  final Future<void> Function(int medicationId, bool isTaken) onToggle;

  const PeriodSection({
    super.key,
    required this.period,
    required this.scheduledTime,
    required this.medicationsWithStatus,
    required this.onToggle,
    this.initiallyExpanded = true,
  });

  @override
  State<PeriodSection> createState() => _PeriodSectionState();
}

class _PeriodSectionState extends State<PeriodSection>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: _isExpanded ? 1.0 : 0.0,
    );
    _expandAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  bool get _isComplete {
    if (widget.medicationsWithStatus.isEmpty) return false;
    return widget.medicationsWithStatus
        .every((e) => (e['isTaken'] as bool) == true);
  }

  int get _takenCount =>
      widget.medicationsWithStatus.where((e) => e['isTaken'] as bool).length;

  @override
  Widget build(BuildContext context) {
    final style = AppTheme.styleForPeriod(widget.period);
    final total = widget.medicationsWithStatus.length;
    final taken = _takenCount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _isComplete
            ? style.accentColor.withValues(alpha: 0.08)
            : style.backgroundColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _isComplete
              ? style.accentColor.withValues(alpha: 0.5)
              : style.accentColor.withValues(alpha: 0.25),
          width: _isComplete ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: style.accentColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ─── Period Header (tap to collapse) ────────────────────────────
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  // Emoji icon in circle
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: style.accentColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.period.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Period name + time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.period.arabicLabel,
                          style: AppTheme.periodHeaderStyle.copyWith(
                            color: style.textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.scheduledTime,
                          style: GoogleFonts.cairo(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: style.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Progress badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _isComplete
                          ? AppTheme.takenColor
                          : style.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$taken / $total',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _isComplete
                            ? Colors.white
                            : style.accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Expand/Collapse chevron
                  AnimatedRotation(
                    turns: _isExpanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: style.accentColor,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Completion Banner ───────────────────────────────────────────
          if (_isComplete)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: AppTheme.takenColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppTheme.takenColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🌸', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'أحسنتِ يا ماما! تم أخذ كل الأدوية',
                      style: GoogleFonts.cairo(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.takenColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

          // ─── Medication Cards ────────────────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnim,
            child: Column(
              children: [
                const Divider(height: 1),
                const SizedBox(height: 6),
                ...widget.medicationsWithStatus.map((entry) {
                  final med = entry['medication'] as Medication;
                  final taken2 = entry['isTaken'] as bool;
                  return MedicationCard(
                    medication: med,
                    isTaken: taken2,
                    onToggle: (val) async {
                      await widget.onToggle(med.id!, val);
                    },
                  );
                }),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
