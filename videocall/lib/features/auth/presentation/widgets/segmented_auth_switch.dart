import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/l10n/app_localizations.dart';

class SegmentedAuthSwitch extends StatelessWidget {
  final bool isSignUp;
  final ValueChanged<bool> onModeChanged;

  const SegmentedAuthSwitch({
    Key? key,
    required this.isSignUp,
    required this.onModeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = AppColors.primary;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8E4)),
      ),
      child: Stack(
        children: [
          // Sliding active pill
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            alignment: isSignUp ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Two clickable text tabs
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (isSignUp) onModeChanged(false);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: !isSignUp ? FontWeight.w800 : FontWeight.w600,
                        color: !isSignUp ? primaryColor : const Color(0xFF64748B),
                        letterSpacing: 0.1,
                      ),
                      child: Text(l10n.signIn),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (!isSignUp) onModeChanged(true);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: isSignUp ? FontWeight.w800 : FontWeight.w600,
                        color: isSignUp ? primaryColor : const Color(0xFF64748B),
                        letterSpacing: 0.1,
                      ),
                      child: Text(l10n.signUp),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
