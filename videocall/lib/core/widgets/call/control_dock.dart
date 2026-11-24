import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';

class CallDockAction {
  const CallDockAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isOff = false,
    this.isEnd = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isOff;
  final bool isEnd;
}

class ControlDock extends StatelessWidget {
  const ControlDock({super.key, required this.actions});

  final List<CallDockAction> actions;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xB30B1F16),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < actions.length; index++) ...[
                  if (index > 0) const SizedBox(width: 6),
                  _DockButton(action: actions[index]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({required this.action});

  final CallDockAction action;

  @override
  Widget build(BuildContext context) {
    final foreground = action.isEnd || !action.isOff
        ? Colors.white
        : const Color(0xFF10231A);
    final background = action.isEnd
        ? AppColors.error
        : action.isOff
        ? Colors.white
        : Colors.white.withValues(alpha: 0.14);

    return Semantics(
      button: true,
      label: action.label,
      child: Tooltip(
        message: action.label,
        child: Material(
          color: background,
          borderRadius: action.isEnd ? BorderRadius.circular(999) : null,
          shape: action.isEnd
              ? null
              : const CircleBorder(side: BorderSide(color: Color(0x24FFFFFF))),
          child: InkWell(
            onTap: action.onPressed,
            borderRadius: action.isEnd ? BorderRadius.circular(999) : null,
            customBorder: action.isEnd ? null : const CircleBorder(),
            child: SizedBox(
              width: action.isEnd
                  ? 90.0 + (action.label.length * 4).clamp(0, 72).toDouble()
                  : 50,
              height: 50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(action.icon, color: foreground, size: 21),
                  if (action.isEnd) ...[
                    const SizedBox(width: 3),
                    Text(
                      action.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
