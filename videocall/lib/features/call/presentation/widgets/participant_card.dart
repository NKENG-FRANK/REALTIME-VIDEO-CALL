import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import 'signal_indicator.dart';

/// A card showing a participant's avatar, name, and signal strength.
/// Used in the call screen sidebar grid.
class ParticipantCard extends StatelessWidget {
  final String name;
  final String initials;
  final Color avatarColor;
  final int signalStrength;

  const ParticipantCard({
    Key? key,
    required this.name,
    required this.initials,
    required this.avatarColor,
    this.signalStrength = 3,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE0EAE2).withOpacity(0.6),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Avatar
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: avatarColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Spacer(),
          // Name and signal
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMuted.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SignalIndicator(
                strength: signalStrength,
                barWidth: 2.5,
                maxBarHeight: 11,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
