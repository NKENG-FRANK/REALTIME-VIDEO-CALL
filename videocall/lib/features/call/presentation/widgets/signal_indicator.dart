import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';

/// Displays signal strength as a series of vertical bars.
///
/// [strength] ranges from 1 (weak) to 3 (strong).
class SignalIndicator extends StatelessWidget {
  final int strength;
  final bool showLabel;
  final double barWidth;
  final double maxBarHeight;

  const SignalIndicator({
    Key? key,
    this.strength = 3,
    this.showLabel = false,
    this.barWidth = 3.0,
    this.maxBarHeight = 14.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildBars(),
        if (showLabel) ...[
          const SizedBox(width: 5),
          Text(
            _label,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  String get _label {
    if (strength >= 3) return 'Strong';
    if (strength == 2) return 'Medium';
    return 'Weak';
  }

  Widget _buildBars() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (index) {
        final barIndex = index + 1;
        final isActive = barIndex <= strength;
        final height = maxBarHeight * (barIndex / 3);

        return Padding(
          padding: EdgeInsets.only(right: index < 2 ? 2 : 0),
          child: Container(
            width: barWidth,
            height: height,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.signalStrong
                  : AppColors.signalWeak.withOpacity(0.4),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        );
      }),
    );
  }
}
