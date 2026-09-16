import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../widgets/call_controls.dart';
import '../widgets/participant_card.dart';
import '../widgets/signal_indicator.dart';

/// Data model for a call participant.
class _Participant {
  final String name;
  final String initials;
  final Color color;
  final int signal;

  const _Participant({
    required this.name,
    required this.initials,
    required this.color,
    this.signal = 3,
  });
}

/// Active call screen with participant sidebar, main call view,
/// audio/video toggle, and bottom control bar.
class CallPage extends StatefulWidget {
  final String callTitle;
  final int participantCount;

  const CallPage({
    Key? key,
    this.callTitle = 'Design Team',
    this.participantCount = 5,
  }) : super(key: key);

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  bool _isAudioMode = true;

  static const _participants = [
    _Participant(name: 'Sarah Chen', initials: 'SC', color: Color(0xFF8752F4)),
    _Participant(
        name: 'Marcus Webb', initials: 'MW', color: Color(0xFF10A47D)),
    _Participant(
        name: 'Priya Nair', initials: 'PN', color: Color(0xFFE31845),
        signal: 3),
    _Participant(
        name: 'James Liu', initials: 'JL', color: Color(0xFF6B6B6B),
        signal: 1),
    _Participant(
        name: 'Design Team', initials: 'DT', color: Color(0xFFFFA00D),
        signal: 3),
    _Participant(
        name: 'Engineering', initials: 'ES', color: Color(0xFF10A47D),
        signal: 2),
    _Participant(
        name: 'Alex Morgan', initials: 'AM', color: Color(0xFFFFA00D),
        signal: 3),
    _Participant(
        name: 'Ryan Kim', initials: 'RK', color: Color(0xFFE31845),
        signal: 2),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.callBackground,
      body: Column(
        children: [
          // Top bar
          _buildTopBar(),
          // Main content
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 760;
                if (isMobile) {
                  return _buildMobileLayout();
                }
                return _buildDesktopLayout();
              },
            ),
          ),
          // Bottom control bar
          CallControls(
            userName: 'You',
            userInitials: 'ME',
            elapsed: '00:11',
            participantCount: widget.participantCount,
            controls: [
              CallControlItem(icon: Icons.mic, label: 'Mute'),
              CallControlItem(icon: Icons.videocam_off_outlined, label: 'Camera'),
              CallControlItem(icon: Icons.screen_share_outlined, label: 'Share'),
              CallControlItem(
                icon: Icons.call_end,
                label: 'End',
                isDestructive: true,
              ),
              CallControlItem(icon: Icons.fiber_manual_record, label: 'Record'),
              CallControlItem(icon: Icons.chat_bubble_outline, label: 'Chat'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFDCE7DF)),
        ),
      ),
      child: Row(
        children: [
          // Online dot
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.onlineGreen,
            ),
          ),
          const SizedBox(width: 10),
          // Call title
          Text(
            '${widget.callTitle} · ${widget.participantCount} participants',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          // Timer
          Text(
            '00:11',
            style: TextStyle(
              color: AppColors.textMuted.withOpacity(0.8),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 14),
          // Signal strength
          const SignalIndicator(
            strength: 3,
            showLabel: true,
            barWidth: 3,
            maxBarHeight: 13,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Sidebar with participants
        SizedBox(
          width: 360,
          child: _buildParticipantSidebar(),
        ),
        // Main call area
        Expanded(child: _buildMainCallArea()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Main call area (takes priority on mobile)
        Expanded(flex: 3, child: _buildMainCallArea()),
        // Compact participants row
        SizedBox(
          height: 100,
          child: _buildMobileParticipants(),
        ),
      ],
    );
  }

  Widget _buildParticipantSidebar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        border: const Border(
          right: BorderSide(color: Color(0xFFDCE7DF)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'OTHER PARTICIPANTS',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                '${_participants.length}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Participant grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.0,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _participants.length,
              itemBuilder: (context, index) {
                final p = _participants[index];
                return ParticipantCard(
                  name: p.name,
                  initials: p.initials,
                  avatarColor: p.color,
                  signalStrength: p.signal,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileParticipants() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        border: const Border(
          top: BorderSide(color: Color(0xFFDCE7DF)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _participants.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final p = _participants[index];
          return SizedBox(
            width: 80,
            child: ParticipantCard(
              name: p.name,
              initials: p.initials,
              avatarColor: p.color,
              signalStrength: p.signal,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainCallArea() {
    return Stack(
      children: [
        // Main content
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Audio/Video toggle
              _buildModeToggle(),
              const SizedBox(height: 40),
              // Self avatar
              Container(
                width: 120,
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Text(
                  'ME',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Name
              const Text(
                'You',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              // Status
              Text(
                _isAudioMode
                    ? 'Connected · Audio call'
                    : 'Connected · Video call',
                style: TextStyle(
                  color: AppColors.textMuted.withOpacity(0.75),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        // "You" tag (bottom-left)
        Positioned(
          left: 18,
          bottom: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.85),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'You',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        // Signal strength (bottom-right)
        const Positioned(
          right: 18,
          bottom: 14,
          child: SignalIndicator(
            strength: 3,
            showLabel: true,
            barWidth: 3,
            maxBarHeight: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE7DF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleButton('Audio', _isAudioMode, () {
            setState(() => _isAudioMode = true);
          }),
          _toggleButton('Video', !_isAudioMode, () {
            setState(() => _isAudioMode = false);
          }),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
