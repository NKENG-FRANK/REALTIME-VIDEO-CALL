import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/services/webrtc_call_service.dart';
import 'signal_indicator.dart';
import 'voice_wave_indicator.dart';

/// A card showing a participant's avatar, name, speaking indicator, and signal strength.
/// Used in the call screen sidebar grid.
class ParticipantCard extends StatelessWidget {
  final String name;
  final String initials;
  final Color avatarColor;
  final int signalStrength;
  final bool isSpeaking;
  final double audioLevel;
  final NetworkQuality? networkQuality;

  const ParticipantCard({
    super.key,
    required this.name,
    required this.initials,
    required this.avatarColor,
    this.signalStrength = 4,
    this.isSpeaking = false,
    this.audioLevel = 0.0,
    this.networkQuality,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStrength = networkQuality?.bars ?? signalStrength;
    final isPoor = networkQuality?.isPoor ?? (effectiveStrength <= 1);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSpeaking
            ? const Color(0xFFECFDF5)
            : Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSpeaking
              ? const Color(0xFF10B981)
              : (isPoor
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFE0EAE2).withValues(alpha: 0.6)),
          width: isSpeaking ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (isSpeaking)
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 2),
            )
          else
            const BoxShadow(
              color: Color(0x08000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Avatar with speaking highlight ring
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: avatarColor,
              shape: BoxShape.circle,
              border: isSpeaking
                  ? Border.all(color: const Color(0xFF10B981), width: 2.5)
                  : null,
              boxShadow: isSpeaking
                  ? [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
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
          const SizedBox(height: 10),
          // Name, Voice Wave, and Signal
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSpeaking
                        ? const Color(0xFF065F46)
                        : AppColors.textMuted.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: isSpeaking ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (isSpeaking) ...[
                const SizedBox(width: 4),
                VoiceWaveIndicator(
                  isSpeaking: true,
                  audioLevel: audioLevel,
                  maxHeight: 12,
                  barWidth: 2,
                  barCount: 3,
                ),
              ],
              const SizedBox(width: 4),
              SignalIndicator(
                strength: effectiveStrength,
                barWidth: 2.5,
                maxBarHeight: 11,
                tooltip: networkQuality?.summaryText,
              ),
              if (isPoor) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: networkQuality != null
                      ? 'Poor network (Loss: ${networkQuality!.packetLossPercent}%, RTT: ${networkQuality!.rttMs.toStringAsFixed(0)}ms)'
                      : 'Poor network connection',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFEF4444), width: 0.8),
                    ),
                    child: const Text(
                      'POOR',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
