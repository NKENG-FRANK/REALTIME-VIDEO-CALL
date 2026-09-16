import 'package:flutter/material.dart';
import 'package:videocall/config/theme/app_colors.dart';

/// Builder widget that cleanly renders child without hover scaling or elevation shifts.
class HoverBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, bool isHovered, bool isPressed) builder;
  final VoidCallback? onTap;
  final MouseCursor cursor;

  const HoverBuilder({
    Key? key,
    required this.builder,
    this.onTap,
    this.cursor = SystemMouseCursors.click,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: builder(context, false, false),
    );
  }
}

/// A smooth action button with static styling and tap feedback.
class SmoothActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onPressed;

  const SmoothActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: foregroundColor),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Static card container with clean rounded borders and optional click feedback.
class SmoothHoverCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? normalColor;
  final Color? hoverColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Border? border;

  const SmoothHoverCard({
    Key? key,
    required this.child,
    this.onTap,
    this.normalColor,
    this.hoverColor,
    this.borderRadius = 8,
    this.padding,
    this.border,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveBg = normalColor ?? Colors.transparent;

    return Container(
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: AppColors.primary.withOpacity(0.08),
          highlightColor: AppColors.primary.withOpacity(0.04),
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Custom scrollbar container with smooth physics.
class SmoothScrollView extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  const SmoothScrollView({
    Key? key,
    required this.child,
    this.controller,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveController = controller ?? PrimaryScrollController.of(context);
    return RawScrollbar(
      controller: effectiveController,
      thumbColor: AppColors.primary.withOpacity(0.25),
      radius: const Radius.circular(6),
      thickness: 6,
      fadeDuration: const Duration(milliseconds: 400),
      timeToFade: const Duration(milliseconds: 1200),
      child: SingleChildScrollView(
        controller: effectiveController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: padding,
        child: child,
      ),
    );
  }
}
