import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 27),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF09120E)
        : const Color(0xFFEDF4EA);
    final ambientA = isDark ? const Color(0xFF0F3D2A) : const Color(0xFFBFE8CF);
    final ambientB = isDark ? const Color(0xFF3A2E0B) : const Color(0xFFFBE7A8);
    final ambientC = isDark ? const Color(0xFF3F1517) : const Color(0xFFFAC9C5);

    return IgnorePointer(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: background),
                _buildCircle(
                  size: 520,
                  color: ambientA,
                  left: -0.25,
                  top: -0.24,
                  blur: 90,
                  opacity: 0.52,
                  motion: _motion(27, 0),
                ),
                _buildCircle(
                  size: 400,
                  color: ambientB,
                  right: -0.18,
                  top: 0.05,
                  blur: 100,
                  opacity: 0.46,
                  motion: _motion(24, 1),
                ),
                _buildCircle(
                  size: 460,
                  color: ambientC,
                  right: 0.18,
                  bottom: -0.3,
                  blur: 110,
                  opacity: 0.4,
                  motion: _motion(25, 2),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCircle({
    required double size,
    required Color color,
    double? left,
    double? right,
    double? top,
    double? bottom,
    required double blur,
    required double opacity,
    required Offset motion,
  }) {
    return _buildShape(
      size: size,
      color: color,
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      blur: blur,
      opacity: opacity,
      rotate: 0,
      motion: motion,
    );
  }

  Widget _buildShape({
    required double size,
    required Color color,
    double? left,
    double? right,
    double? top,
    double? bottom,
    required double rotate,
    required double blur,
    required double opacity,
    required Offset motion,
  }) {
    final screen = MediaQuery.sizeOf(context);
    final progress = _controller.value * 2 * math.pi;
    final drift = Offset(
      motion.dx * (0.5 - 0.5 * math.cos(progress)),
      motion.dy * (0.5 - 0.5 * math.cos(progress)),
    );

    return Positioned(
      left: left == null ? null : screen.width * left + drift.dx,
      right: right == null ? null : screen.width * right - drift.dx,
      top: top == null ? null : screen.height * top + drift.dy,
      bottom: bottom == null ? null : screen.height * bottom - drift.dy,
      child: Transform.rotate(
        angle: rotate,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.rectangle,
                borderRadius: rotate == 0 ? BorderRadius.circular(size) : null,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.7),
                    blurRadius: 60,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset _motion(double seconds, int index) {
    const paths = [
      Offset(400, -300),
      Offset(-450, 300),
      Offset(-420, 350),
      Offset(400, -320),
      Offset(450, 250),
      Offset(-380, -300),
      Offset(420, 350),
    ];
    final scale = _controller.duration!.inSeconds / seconds;
    return paths[index] / scale;
  }
}
