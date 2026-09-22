import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';

/// Connecting screen shown while establishing a WebRTC call.
/// Shows a spinning ring around a camera icon, status text,
/// encryption badge, and a cancel button.
class ConnectingPage extends StatefulWidget {
  final VoidCallback? onCancel;

  const ConnectingPage({
    Key? key,
    this.onCancel,
  }) : super(key: key);

  @override
  State<ConnectingPage> createState() => _ConnectingPageState();
}

class _ConnectingPageState extends State<ConnectingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.callBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Spinner + camera icon
            _buildSpinner(),
            const SizedBox(height: 28),
            // Connecting text
            const Text(
              'Connecting...',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            // Subtitle
            Text(
              'Establishing secure connection',
              style: TextStyle(
                color: AppColors.textMuted.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            // Status badge
            _buildStatusBadge(),
            const SizedBox(height: 28),
            // Cancel button
            TextButton(
              onPressed: () {
                if (widget.onCancel != null) {
                  widget.onCancel!();
                } else if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacementNamed('/calls');
                }
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.callDecline,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpinner() {
    return SizedBox(
      width: 80,
      height: 80,
      child: AnimatedBuilder(
        animation: _spinController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Spinning arc
              Transform.rotate(
                angle: _spinController.value * math.pi * 2,
                child: CustomPaint(
                  size: const Size(80, 80),
                  painter: _SpinnerPainter(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                ),
              ),
              // Camera icon circle
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.12),
                ),
                child: Icon(
                  Icons.videocam,
                  size: 24,
                  color: AppColors.primary.withOpacity(0.7),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFDCE7DF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.onlineGreen,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            'Encrypting media stream...',
            style: TextStyle(
              color: AppColors.textMuted.withOpacity(0.85),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the spinning arc around the camera icon.
class _SpinnerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _SpinnerPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw partial arc (~270 degrees)
    canvas.drawArc(rect.deflate(strokeWidth / 2), -math.pi / 2, math.pi * 1.5, false, paint);
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter old) =>
      color != old.color || strokeWidth != old.strokeWidth;
}
