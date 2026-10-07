import 'package:flutter/material.dart';

/// An animated voice waveform indicator that displays dynamic bouncing bars
/// when a participant is speaking, scaled according to their real-time audio level.
class VoiceWaveIndicator extends StatefulWidget {
  final bool isSpeaking;
  final double audioLevel;
  final Color activeColor;
  final Color idleColor;
  final double maxHeight;
  final double barWidth;
  final int barCount;

  const VoiceWaveIndicator({
    super.key,
    required this.isSpeaking,
    this.audioLevel = 0.0,
    this.activeColor = const Color(0xFF10B981),
    this.idleColor = Colors.white38,
    this.maxHeight = 16.0,
    this.barWidth = 2.5,
    this.barCount = 3,
  });

  @override
  State<VoiceWaveIndicator> createState() => _VoiceWaveIndicatorState();
}

class _VoiceWaveIndicatorState extends State<VoiceWaveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    if (widget.isSpeaking) {
      _animCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(VoiceWaveIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !oldWidget.isSpeaking) {
      _animCtrl.repeat(reverse: true);
    } else if (!widget.isSpeaking && oldWidget.isSpeaking) {
      _animCtrl.stop();
      _animCtrl.animateTo(0.0, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveLevel = widget.isSpeaking
        ? widget.audioLevel.clamp(0.2, 1.0)
        : 0.0;

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(widget.barCount, (index) {
            // Stagger animation phase per bar
            final phase = (index + 1) / (widget.barCount + 1);
            final animVal = (_animCtrl.value + phase) % 1.0;
            final dynamicScale = (animVal * 0.6) + 0.4;

            final targetHeight = widget.isSpeaking
                ? (widget.maxHeight * effectiveLevel * dynamicScale).clamp(4.0, widget.maxHeight)
                : 3.0;

            return Container(
              margin: EdgeInsets.symmetric(horizontal: widget.barWidth * 0.4),
              width: widget.barWidth,
              height: targetHeight,
              decoration: BoxDecoration(
                color: widget.isSpeaking ? widget.activeColor : widget.idleColor,
                borderRadius: BorderRadius.circular(widget.barWidth),
                boxShadow: widget.isSpeaking
                    ? [
                        BoxShadow(
                          color: widget.activeColor.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        );
      },
    );
  }
}
