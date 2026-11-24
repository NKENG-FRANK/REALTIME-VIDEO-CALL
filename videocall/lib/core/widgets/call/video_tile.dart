import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../features/call/presentation/widgets/voice_wave_indicator.dart';

class VideoTile extends StatelessWidget {
  const VideoTile({
    super.key,
    required this.renderer,
    required this.name,
    required this.initials,
    this.isLocal = false,
    this.isCameraOff = false,
    this.isMicMuted = false,
    this.isActiveSpeaker = false,
    this.audioLevel = 0,
    this.borderRadius = 0,
    this.showName = true,
    this.mirror = false,
  });

  final RTCVideoRenderer? renderer;
  final String name;
  final String initials;
  final bool isLocal;
  final bool isCameraOff;
  final bool isMicMuted;
  final bool isActiveSpeaker;
  final double audioLevel;
  final double borderRadius;
  final bool showName;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final hasVideo = !isCameraOff && renderer?.srcObject != null;
    final radius = BorderRadius.circular(borderRadius);
    final mutedDescription = AppLocalizations.of(context)
        .text(fr: 'Microphone coupé', en: 'Microphone muted');

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: Palette.callGradient),
          ),
          if (hasVideo)
            RTCVideoView(
              renderer!,
              mirror: mirror,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else
            Center(
              child: Container(
                width: 120,
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.19),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Text(
                  initials.isEmpty ? (isLocal ? 'ME' : 'CW') : initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (isActiveSpeaker)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ),
          if (showName)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _NamePill(
                  name: name,
                  isMuted: isMicMuted,
                  isSpeaking: isActiveSpeaker,
                  audioLevel: audioLevel,
                  mutedDescription: mutedDescription,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NamePill extends StatelessWidget {
  const _NamePill({
    required this.name,
    required this.isMuted,
    required this.isSpeaking,
    required this.audioLevel,
    required this.mutedDescription,
  });

  final String name;
  final bool isMuted;
  final bool isSpeaking;
  final double audioLevel;
  final String mutedDescription;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMuted)
                Tooltip(
                  message: mutedDescription,
                  child: const Icon(
                    Icons.mic_off_rounded,
                    color: AppColors.error,
                    size: 15,
                  ),
                )
              else if (isSpeaking)
                VoiceWaveIndicator(
                  isSpeaking: true,
                  audioLevel: audioLevel,
                  maxHeight: 14,
                  barWidth: 2,
                  barCount: 4,
                ),
              if (isMuted || isSpeaking) const SizedBox(width: 7),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
