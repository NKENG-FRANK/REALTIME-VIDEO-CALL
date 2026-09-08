import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({Key? key}) : super(key: key);

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
    return IgnorePointer(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFFFFFFFF)),
                _buildCircle(
                  size: 300,
                  color: const Color(0xFF2D5016),
                  left: 0.05,
                  top: -0.10,
                  blur: 80,
                  opacity: 0.25,
                  motion: _motion(20, 0),
                ),
                _buildCircle(
                  size: 250,
                  color: const Color(0xFF3A6B1F),
                  right: 0.10,
                  bottom: 0.05,
                  blur: 80,
                  opacity: 0.25,
                  motion: _motion(25, 1),
                ),
                _buildCircle(
                  size: 280,
                  color: const Color(0xFFFFD700),
                  right: 0.05,
                  top: 0.15,
                  blur: 80,
                  opacity: 0.25,
                  motion: _motion(22, 2),
                ),
                _buildCircle(
                  size: 200,
                  color: const Color(0xFFFFD700),
                  left: 0.08,
                  bottom: 0.20,
                  blur: 80,
                  opacity: 0.25,
                  motion: _motion(26, 3),
                ),
                _buildShape(
                  size: 220,
                  color: const Color(0xFFDC143C),
                  left: -0.05,
                  top: 0.40,
                  rotate: 0.785,
                  blur: 80,
                  opacity: 0.25,
                  motion: _motion(24, 4),
                ),
                _buildShape(
                  size: 260,
                  color: const Color(0xFF2D5016),
                  right: 0.03,
                  top: 0.60,
                  rotate: 0.785,
                  blur: 80,
                  opacity: 0.25,
                  motion: _motion(23, 5),
                ),
                _buildShape(
                  size: 180,
                  color: const Color(0xFFFFD700),
                  right: 0.20,
                  bottom: 0.30,
                  rotate: 0.785,
                  blur: 80,
                  opacity: 0.25,
                  motion: _motion(21, 6),
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
                  BoxShadow(color: color.withOpacity(0.7), blurRadius: 60),
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
