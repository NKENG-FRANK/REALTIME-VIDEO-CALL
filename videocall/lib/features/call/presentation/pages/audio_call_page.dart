import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/webrtc_call_service.dart';
import '../widgets/call_controls.dart';
import '../widgets/participant_card.dart';
import '../widgets/signal_indicator.dart';
import '../widgets/voice_wave_indicator.dart';
import 'call_ended_page.dart';

/// Dedicated Audio Call screen designed specifically for voice-only calls.
/// Features a stunning animated voice ripple pulse, participant avatar,
/// audio output routing, encryption details, and responsive desktop/mobile layout.
class AudioCallPage extends StatefulWidget {
  final String callTitle;
  final String roomId;
  final String contactName;
  final String contactMatricule;
  final String? userToken;
  final int participantCount;
  final bool isGroupCall;
  final WebRTCCallService? callService;

  const AudioCallPage({
    Key? key,
    this.callTitle = 'Audio Call',
    required this.roomId,
    this.contactName = 'Peer',
    this.contactMatricule = '',
    this.userToken,
    this.participantCount = 2,
    this.isGroupCall = false,
    this.callService,
  }) : super(key: key);

  @override
  State<AudioCallPage> createState() => _AudioCallPageState();
}

class _AudioCallPageState extends State<AudioCallPage>
    with SingleTickerProviderStateMixin {
  late final WebRTCCallService _callService;
  bool _hasNavigatedToEnded = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _callService = widget.callService ?? WebRTCCallService();
    _callService.addListener(_onCallStateChanged);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    if (widget.callService == null) {
      _initializeCall();
    }
  }

  Future<void> _initializeCall() async {
    String? token = widget.userToken;
    token ??= await AuthService.getToken();

    if (token != null && token.isNotEmpty) {
      await _callService.initializeSocket(token);
    } else {
      debugPrint('[AudioCallPage] No auth token found');
    }

    await _callService.joinCallRoom(
      widget.roomId,
      isVideoCall: false,
      isGroupCall: widget.isGroupCall,
    );
  }

  void _onCallStateChanged() {
    if (!mounted) return;
    setState(() {});
    if (_callService.callState == CallState.ended) {
      _navigateToEndedPage();
    }
  }

  void _navigateToEndedPage() {
    if (_hasNavigatedToEnded || !mounted) return;
    _hasNavigatedToEnded = true;

    final durationStr = _callService.formattedDuration;
    final callTitle = widget.callTitle;
    final participantCount = widget.participantCount;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (newContext) => CallEndedPage(
          callTitle: callTitle,
          participantCount: participantCount,
          duration: (durationStr == '00:00' || durationStr.isEmpty)
              ? '00:05'
              : durationStr,
          quality: 'HD Voice',
          onBackToHome: () {
            Navigator.of(newContext).pushNamedAndRemoveUntil(
              '/calls',
              (route) => false,
            );
          },
          onCallAgain: () {
            Navigator.of(newContext).pushNamedAndRemoveUntil(
              '/calls',
              (route) => false,
            );
          },
        ),
      ),
    );
  }

  Future<void> _hangUpAndExit() async {
    await _callService.endCall();
    if (mounted) {
      _navigateToEndedPage();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _callService.removeListener(_onCallStateChanged);
    _callService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.callBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 760;
                  return isMobile
                      ? _buildHeroAudioArea()
                      : _buildDesktopLayout();
                },
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        border: const Border(bottom: BorderSide(color: Color(0xFFDCE7DF))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            color: AppColors.textPrimary,
            tooltip: 'End Call',
            onPressed: _hangUpAndExit,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.callTitle,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      size: 11,
                      color: AppColors.onlineGreen,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Room: ${_formatRoomId(widget.roomId)} • Encrypted Audio',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SignalIndicator(strength: 3, showLabel: true),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(width: 300, child: _buildParticipantSidebar()),
        Expanded(child: _buildHeroAudioArea()),
      ],
    );
  }

  Widget _buildParticipantSidebar() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        border: const Border(right: BorderSide(color: Color(0xFFDCE7DF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PARTICIPANTS (${widget.participantCount})',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          ParticipantCard(
            name: 'You (Local)',
            initials: 'ME',
            avatarColor: AppColors.primary,
            signalStrength: 3,
            isSpeaking: _callService.isLocalSpeaking,
            audioLevel: _callService.getAudioLevel('local'),
          ),
          const SizedBox(height: 10),
          ParticipantCard(
            name: widget.contactName,
            initials: _deriveInitials(widget.contactName),
            avatarColor: const Color(0xFF10A47D),
            signalStrength: 3,
            isSpeaking: _callService.activeSpeakerId != null &&
                _callService.activeSpeakerId != 'local',
            audioLevel: _callService.activeSpeakerId != null &&
                    _callService.activeSpeakerId != 'local'
                ? _callService.getAudioLevel(_callService.activeSpeakerId!)
                : 0.0,
          ),
          if (widget.isGroupCall && widget.participantCount > 2) ...[
            for (int i = 2; i < widget.participantCount; i++) ...[
              const SizedBox(height: 10),
              ParticipantCard(
                name: 'Member $i',
                initials: 'M$i',
                avatarColor: const Color(0xFF8752F4),
                signalStrength: 3,
                isSpeaking: false,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHeroAudioArea() {
    final initials = _deriveInitials(widget.contactName);
    final isPeerSpeaking = _callService.activeSpeakerId != null &&
        _callService.activeSpeakerId != 'local';
    final peerAudioLevel = isPeerSpeaking
        ? _callService.getAudioLevel(_callService.activeSpeakerId!)
        : 0.0;
    final currentAudioLevel = isPeerSpeaking
        ? peerAudioLevel
        : (_callService.isLocalSpeaking ? _callService.getAudioLevel('local') : 0.0);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Concentric pulsing audio ripple rings
            SizedBox(
              width: 240,
              height: 240,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _AudioRipplePainter(
                      progress: _pulseController.value,
                      color: isPeerSpeaking || _callService.isLocalSpeaking
                          ? const Color(0xFF10B981)
                          : AppColors.primary,
                      audioLevel: currentAudioLevel,
                    ),
                    child: Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 124,
                            height: 124,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2D5016), Color(0xFF1E380E)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.25),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Icon(
                              _callService.isMicMuted
                                  ? Icons.mic_off
                                  : Icons.mic,
                              size: 18,
                              color: _callService.isMicMuted
                                  ? AppColors.callDecline
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            // Contact Name
            Text(
              widget.contactName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            // Matricule / Subtitle
            if (widget.contactMatricule.isNotEmpty)
              Text(
                widget.contactMatricule,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            // Speaking status badge
            if (isPeerSpeaking || _callService.isLocalSpeaking)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VoiceWaveIndicator(
                      isSpeaking: true,
                      audioLevel: currentAudioLevel,
                      maxHeight: 12,
                      barWidth: 2,
                      barCount: 3,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPeerSpeaking
                          ? '${widget.contactName} is speaking'
                          : 'You are speaking',
                      style: const TextStyle(
                        color: Color(0xFF065F46),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            // Live Timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFDCE7DF)),
              ),
              child: Text(
                _callService.formattedDuration,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Connection Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFDCE7DF)),
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
                  const SizedBox(width: 8),
                  const Text(
                    'Connected • HD Voice (Opus 48kHz)',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return CallControls(
      userName: 'You',
      userInitials: 'ME',
      elapsed: _callService.formattedDuration,
      participantCount: widget.participantCount,
      controls: [
        CallControlItem(
          icon: _callService.isMicMuted ? Icons.mic_off : Icons.mic,
          label: _callService.isMicMuted ? 'Unmute' : 'Mute',
          isActive: _callService.isMicMuted,
          onTap: () => _callService.toggleMic(),
        ),
        CallControlItem(
          icon: _callService.isSpeakerOn
              ? Icons.volume_up_rounded
              : Icons.volume_down_rounded,
          label: _callService.isSpeakerOn ? 'Speaker On' : 'Speaker Off',
          isActive: _callService.isSpeakerOn,
          onTap: () => _callService.toggleSpeaker(),
        ),
        CallControlItem(
          icon: Icons.call_end,
          label: 'End',
          isDestructive: true,
          onTap: _hangUpAndExit,
        ),
      ],
    );
  }

  static String _deriveInitials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static String _formatRoomId(String id) {
    if (id.length <= 16) return id;
    return '${id.substring(0, 8)}...${id.substring(id.length - 4)}';
  }
}

/// Custom painter that draws soft concentric audio ripple rings radiating outward.
class _AudioRipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double audioLevel;

  _AudioRipplePainter({
    required this.progress,
    required this.color,
    this.audioLevel = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const baseRadius = 66.0;
    final extraSpread = audioLevel.clamp(0.0, 1.0) * 35.0;
    final maxRadius = 115.0 + extraSpread;

    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + (i * 0.33)) % 1.0;
      final radius = baseRadius + (maxRadius - baseRadius) * ringProgress;
      final boost = audioLevel > 0.04 ? 0.35 : 0.22;
      final opacity = (1.0 - ringProgress) * boost;

      final paint = Paint()
        ..color = color.withOpacity(opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = audioLevel > 0.04 ? 2.5 : 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AudioRipplePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.audioLevel != audioLevel;
}
