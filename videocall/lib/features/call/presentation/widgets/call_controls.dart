import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';

/// A control button definition for the call controls bar.
class CallControlItem {
  final IconData icon;
  final String label;
  final bool isDestructive;
  final bool isActive;
  final VoidCallback? onTap;

  const CallControlItem({
    required this.icon,
    required this.label,
    this.isDestructive = false,
    this.isActive = false,
    this.onTap,
  });
}

/// Bottom control bar used during an active call.
/// Shows Mute, Camera, Share, End, Record, Chat buttons.
class CallControls extends StatelessWidget {
  final String userName;
  final String userInitials;
  final String elapsed;
  final int participantCount;
  final List<CallControlItem> controls;

  const CallControls({
    Key? key,
    required this.userName,
    required this.userInitials,
    required this.elapsed,
    required this.participantCount,
    required this.controls,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        border: const Border(
          top: BorderSide(color: Color(0xFFDCE7DF)),
        ),
      ),
      child: Row(
        children: [
          // Left: user info
          _buildUserInfo(),
          const Spacer(),
          // Center: control buttons
          _buildControlButtons(),
          const Spacer(),
          // Right: participant count
          _buildParticipantCount(),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            userInitials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userName,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              elapsed,
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: controls.map((control) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _ControlButton(item: control),
        );
      }).toList(),
    );
  }

  Widget _buildParticipantCount() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.people_alt,
          size: 14,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 5),
        Text(
          '$participantCount',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 3),
        const Icon(
          Icons.chevron_right,
          size: 14,
          color: AppColors.textMuted,
        ),
      ],
    );
  }
}

class _ControlButton extends StatefulWidget {
  final CallControlItem item;

  const _ControlButton({required this.item});

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isEnd = widget.item.isDestructive;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.item.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: isEnd ? 48 : 44,
          height: isEnd ? 48 : 44,
          decoration: BoxDecoration(
            color: isEnd
                ? AppColors.callDecline
                : _hovering
                    ? const Color(0xFFE0EAE2)
                    : const Color(0xFFF0F5F1),
            shape: BoxShape.circle,
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: (isEnd
                              ? AppColors.callDecline
                              : AppColors.primary)
                          .withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.item.icon,
                size: isEnd ? 20 : 17,
                color: isEnd ? Colors.white : AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
