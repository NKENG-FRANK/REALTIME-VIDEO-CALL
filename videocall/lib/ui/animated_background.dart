import 'package:flutter/material.dart';
import 'package:videocall/config/theme/app_colors.dart';

/// A placeholder for the animated background that matches the CSS
/// `.animated-bg` from `preview.html`. It simply fills the entire screen
/// with a transparent container (you can later replace it with actual
/// animations or gradients).
class AnimatedBackground extends StatelessWidget {
  const AnimatedBackground({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      // The container expands to fill the available space.
      width: double.infinity,
      height: double.infinity,
      // Use the same background colour as the preview's page background.
      color: AppColors.background,
    );
  }
}
