import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';

/// Incoming call screen showing caller info with pulsing avatar,
/// decline/accept buttons, and audio waveform animation.
class IncomingCallPage extends StatefulWidget {
  final String callerName;
  final String callerMatricule;
  final String callerInitials;
  final Color callerColor;
  final bool isVideoCall;

  const IncomingCallPage({
    Key? key,
    this.callerName = 'Sarah Chen',
    this.callerMatricule = 'S00847102',
    this.callerInitials = 'SC',
    this.callerColor = const Color(0xFF8752F4),
    this.isVideoCall = true,
  }) : super(key: key);

  @override
  State<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.callBackground,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              // Pulsing avatar
              _buildPulsingAvatar(),
              const SizedBox(height: 18),
              // Call type label
              Text(
                widget.isVideoCall
                    ? 'INCOMING VIDEO CALL'
                    : 'INCOMING AUDIO CALL',
                style: TextStyle(
                  color: AppColors.primary.withOpacity(0.55),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 10),
              // Caller name
              Text(
                widget.callerName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              // Caller matricule
              Text(
                widget.callerMatricule,
                style: TextStyle(
                  color: AppColors.textMuted.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 28),
              // Audio waveform
              _buildWaveform(),
              const SizedBox(height: 40),
              // Action buttons
              _buildActionButtons(),
              const SizedBox(height: 32),
              // Remind me link
              TextButton(
                onPressed: () {},
                child: Text(
                  'Remind me in 5 minutes',
                  style: TextStyle(
                    color: AppColors.textMuted.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPulsingAvatar() {
    return SizedBox(
      width: 160,
      height: 160,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = math.sin(_pulseController.value * math.pi * 2) * 0.5 + 0.5;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              Container(
                width: 150 + pulse * 12,
                height: 150 + pulse * 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.textMuted.withOpacity(0.06 + pulse * 0.04),
                ),
              ),
              // Inner ring
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.textMuted.withOpacity(0.08),
                ),
              ),
              // Avatar
              Container(
                width: 100,
                height: 100,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.callerColor,
                  boxShadow: [
                    BoxShadow(
                      color: widget.callerColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  widget.callerInitials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              // Camera badge
              Positioned(
                bottom: 22,
                right: 36,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.8),
                    border: Border.all(
                      color: AppColors.callBackground,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.videocam,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWaveform() {
    return SizedBox(
      height: 24,
      width: 160,
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(24, (index) {
              final phase = _waveController.value * math.pi * 2;
              final offset = index * 0.35;
              final height = 4.0 +
                  (math.sin(phase + offset) * 0.5 + 0.5) * 16.0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  width: 2.5,
                  height: height,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Decline button
        _CallActionButton(
          icon: Icons.phone,
          label: 'Decline',
          color: AppColors.callDecline,
          rotateIcon: true,
          onTap: () {},
        ),
        const SizedBox(width: 50),
        // Accept button
        _CallActionButton(
          icon: Icons.videocam,
          label: 'Accept',
          color: AppColors.callAccept,
          onTap: () {},
        ),
      ],
    );
  }
}

class _CallActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool rotateIcon;
  final VoidCallback onTap;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.rotateIcon = false,
    required this.onTap,
  });

  @override
  State<_CallActionButton> createState() => _CallActionButtonState();
}

class _CallActionButtonState extends State<_CallActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(_hovering ? 0.45 : 0.25),
                    blurRadius: _hovering ? 20 : 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Transform.rotate(
                angle: widget.rotateIcon ? 2.36 : 0,
                child: Icon(
                  widget.icon,
                  size: 26,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
