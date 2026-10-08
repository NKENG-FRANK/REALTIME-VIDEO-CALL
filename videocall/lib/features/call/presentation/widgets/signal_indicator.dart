import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';

/// Displays real-time signal strength as 1–4 vertical bars with color-coding:
/// - 4 bars: Emerald Green (Excellent)
/// - 3 bars: Lime Green (Good)
/// - 2 bars: Amber / Orange (Fair)
/// - 1 bar: Red (Poor)
class SignalIndicator extends StatelessWidget {
  final int strength;
  final int maxBars;
  final bool showLabel;
  final double barWidth;
  final double maxBarHeight;
  final Color? activeColor;
  final String? tooltip;

  const SignalIndicator({
    super.key,
    this.strength = 4,
    this.maxBars = 4,
    this.showLabel = false,
    this.barWidth = 3.0,
    this.maxBarHeight = 14.0,
    this.activeColor,
    this.tooltip,
  });

  Color get _color {
    if (activeColor != null) return activeColor!;
    switch (strength) {
      case 4:
        return AppColors.signalExcellent;
      case 3:
        return AppColors.signalGood;
      case 2:
        return AppColors.signalFair;
      case 1:
        return AppColors.signalPoor;
      default:
        return strength > 4 ? AppColors.signalExcellent : Colors.grey;
    }
  }

  String get _label {
    switch (strength) {
      case 4:
        return 'Excellent';
      case 3:
        return 'Good';
      case 2:
        return 'Fair';
      case 1:
        return 'Poor';
      default:
        return strength > 4 ? 'Excellent' : 'No Signal';
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildBars(),
        if (showLabel) ...[
          const SizedBox(width: 5),
          Text(
            _label,
            style: TextStyle(
              color: _color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(
        message: tooltip!,
        preferBelow: false,
        textStyle: const TextStyle(color: Colors.white, fontSize: 11),
        decoration: BoxDecoration(
          color: const Color(0xE61E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: content,
      );
    }

    return content;
  }

  Widget _buildBars() {
    final effectiveMax = maxBars.clamp(1, 5);
    final effectiveStrength = strength.clamp(0, effectiveMax);
    final barColor = _color;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(effectiveMax, (index) {
        final barIndex = index + 1;
        final isActive = barIndex <= effectiveStrength;
        final height = maxBarHeight * (barIndex / effectiveMax);

        return Padding(
          padding: EdgeInsets.only(right: index < effectiveMax - 1 ? 2 : 0),
          child: Container(
            width: barWidth,
            height: height,
            decoration: BoxDecoration(
              color: isActive
                  ? barColor
                  : (barColor.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        );
      }),
    );
  }
}
