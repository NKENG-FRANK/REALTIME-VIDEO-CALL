import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/services/webrtc_call_service.dart';
import '../widgets/call_controls.dart';
import '../widgets/participant_card.dart';
import '../widgets/signal_indicator.dart';

class CallPage extends StatefulWidget {
  final String callTitle;
  final String roomId;
  final String? userToken;
  final int participantCount;

  const CallPage({
    Key? key,
    this.callTitle = '1-on-1 Call',
    this.roomId = 'demo-room-1',
    this.userToken,
    this.participantCount = 2,
  }) : super(key: key);

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  late final WebRTCCallService _callService;

  @override
  void initState() {
    super.initState();
    _callService = WebRTCCallService();
    _callService.addListener(_onCallStateChanged);
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    if (widget.userToken != null) {
      await _callService.initializeSocket(widget.userToken!);
    }
    await _callService.joinCallRoom(widget.roomId, isVideoCall: true);
  }

  void _onCallStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _callService.removeListener(_onCallStateChanged);
    _callService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.callBackground,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 760;
                return isMobile ? _buildMobileLayout() : _buildDesktopLayout();
              },
            ),
          ),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Future<void> _hangUpAndExit() async {
    await _callService.endCall();
    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacementNamed('/calls');
      }
    }
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        border: const Border(bottom: BorderSide(color: Color(0xFFDCE7DF))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _hangUpAndExit,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.callTitle,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Room: ${widget.roomId} • ${_callService.callState.name}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            tooltip: 'Switch Camera',
            onPressed: () => _callService.switchCamera(),
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
        SizedBox(width: 320, child: _buildParticipantSidebar()),
        Expanded(child: _buildMainVideoArea()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(child: _buildMainVideoArea()),
      ],
    );
  }

  Widget _buildParticipantSidebar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        border: const Border(right: BorderSide(color: Color(0xFFDCE7DF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PARTICIPANTS (2)',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          const ParticipantCard(
            name: 'You (Local)',
            initials: 'ME',
            avatarColor: AppColors.primary,
            signalStrength: 3,
          ),
          const SizedBox(height: 10),
          const ParticipantCard(
            name: 'Remote Peer',
            initials: 'RP',
            avatarColor: Color(0xFF10A47D),
            signalStrength: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildMainVideoArea() {
    return Stack(
      children: [
        // Main Remote Video Stream View (Full area)
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: _callService.remoteRenderer.srcObject != null
                ? RTCVideoView(_callService.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Waiting for peer video stream...',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
          ),
        ),

        // Floating Local Video Camera Preview (Picture-in-Picture)
        Positioned(
          right: 20,
          top: 20,
          width: 140,
          height: 190,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white38, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _callService.isVideoOff
                ? const Center(
                    child: Icon(Icons.videocam_off, color: Colors.white54, size: 36),
                  )
                : RTCVideoView(_callService.localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return CallControls(
      userName: 'You',
      userInitials: 'ME',
      elapsed: '00:00',
      participantCount: widget.participantCount,
      controls: [
        CallControlItem(
          icon: _callService.isMicMuted ? Icons.mic_off : Icons.mic,
          label: _callService.isMicMuted ? 'Unmute' : 'Mute',
          isActive: _callService.isMicMuted,
          onTap: () => _callService.toggleMic(),
        ),
        CallControlItem(
          icon: _callService.isVideoOff ? Icons.videocam_off : Icons.videocam,
          label: _callService.isVideoOff ? 'Start Video' : 'Stop Video',
          isActive: _callService.isVideoOff,
          onTap: () => _callService.toggleCamera(),
        ),
        CallControlItem(
          icon: Icons.cameraswitch,
          label: 'Flip',
          onTap: () => _callService.switchCamera(),
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
}
