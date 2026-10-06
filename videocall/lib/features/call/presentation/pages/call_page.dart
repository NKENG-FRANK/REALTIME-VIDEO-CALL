import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/webrtc_call_service.dart';
import '../widgets/call_controls.dart';
import '../widgets/participant_card.dart';
import '../widgets/signal_indicator.dart';
import 'call_ended_page.dart';

class CallPage extends StatefulWidget {
  final String callTitle;
  final String roomId;
  final String? userToken;
  final int participantCount;
  final bool isVideoCall;
  final bool isGroupCall;
  final WebRTCCallService? callService;

  const CallPage({
    Key? key,
    this.callTitle = '1-on-1 Call',
    this.roomId = 'demo-room-1',
    this.userToken,
    this.participantCount = 2,
    this.isVideoCall = true,
    this.isGroupCall = false,
    this.callService,
  }) : super(key: key);

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  late final WebRTCCallService _callService;
  bool _hasNavigatedToEnded = false;

  @override
  void initState() {
    super.initState();
    _callService = widget.callService ?? WebRTCCallService();
    _callService.addListener(_onCallStateChanged);
    if (widget.callService == null) {
      _initializeCall();
    }
  }

  Future<void> _initializeCall() async {
    // Get token: prefer passed token, fall back to stored token
    String? token = widget.userToken;
    token ??= await AuthService.getToken();

    if (token != null && token.isNotEmpty) {
      await _callService.initializeSocket(token);
    } else {
      debugPrint('[CallPage] No auth token found — cannot connect WebRTC socket');
    }

    await _callService.joinCallRoom(
      widget.roomId,
      isVideoCall: widget.isVideoCall,
      isGroupCall: widget.isGroupCall,
    );
  }

  void _navigateToEndedPage() {
    if (_hasNavigatedToEnded || !mounted) return;
    _hasNavigatedToEnded = true;

    final durationStr = _callService.formattedDuration;
    final callTitle = widget.callTitle;
    final participantCount = widget.participantCount;

    // Navigate using the current context while it's still valid
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (newContext) => CallEndedPage(
          callTitle: callTitle,
          participantCount: participantCount,
          duration: (durationStr == '00:00' || durationStr.isEmpty) ? '00:05' : durationStr,
          quality: 'Good',
          // Callbacks use newContext — the CallEndedPage's own context
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

  void _onCallStateChanged() {
    if (!mounted) return;
    setState(() {});
    if (_callService.callState == CallState.ended) {
      _navigateToEndedPage();
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
      _navigateToEndedPage();
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
                Text(
                  'Room: ${_formatRoomId(widget.roomId)} • ${_callService.callState.name}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            tooltip: 'Switch Camera',
            onPressed: () => _callService.switchCamera(),
          ),
          const SizedBox(width: 4),
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
          Text(
            'PARTICIPANTS (${widget.participantCount})',
            style: const TextStyle(
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
          ParticipantCard(
            name: widget.isGroupCall ? 'Member 1' : 'Remote Peer',
            initials: widget.isGroupCall ? 'M1' : 'RP',
            avatarColor: const Color(0xFF10A47D),
            signalStrength: 3,
          ),
          if (widget.isGroupCall && widget.participantCount > 2) ...[
            for (int i = 2; i < widget.participantCount; i++) ...[
              const SizedBox(height: 10),
              ParticipantCard(
                name: 'Member $i',
                initials: 'M$i',
                avatarColor: const Color(0xFF8752F4),
                signalStrength: 3,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMainVideoArea() {
    if (widget.isGroupCall || _callService.remoteRenderers.length > 1) {
      return _buildGroupVideoGrid();
    }
    return _buildOneOnOneVideoArea();
  }

  Widget _buildGroupVideoGrid() {
    final remoteEntries = _callService.remoteRenderers.entries.toList();
    final totalParticipants = 1 + remoteEntries.length; // Local user + remote peers

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = 1;
          if (totalParticipants == 2) {
            crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
          } else if (totalParticipants <= 4) {
            crossAxisCount = 2;
          } else if (totalParticipants <= 9) {
            crossAxisCount = 3;
          } else {
            crossAxisCount = 4;
          }

          return GridView.builder(
            itemCount: totalParticipants,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: constraints.maxWidth > 600 ? 1.33 : 1.0,
            ),
            itemBuilder: (context, index) {
              if (index == 0) {
                // Tile 0: Local User Video Stream
                return _buildVideoTile(
                  title: 'You (Local)',
                  isLocal: true,
                  renderer: _callService.localRenderer,
                  isMuted: _callService.isMicMuted,
                  isVideoOff: _callService.isVideoOff,
                );
              }

              // Tiles 1..N: Remote Peer Video Streams
              final peerEntry = remoteEntries[index - 1];
              final peerId = peerEntry.key;
              final peerRenderer = peerEntry.value;
              final shortPeerId = peerId.length > 8 ? peerId.substring(0, 8) : peerId;

              return _buildVideoTile(
                title: 'Participant $index ($shortPeerId)',
                isLocal: false,
                renderer: peerRenderer,
                isMuted: false,
                isVideoOff: false,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildVideoTile({
    required String title,
    required bool isLocal,
    required RTCVideoRenderer renderer,
    required bool isMuted,
    required bool isVideoOff,
  }) {
    final hasStream = renderer.srcObject != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLocal ? AppColors.primary.withOpacity(0.6) : Colors.white24,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Video View or Fallback Icon
          Positioned.fill(
            child: (isVideoOff || !hasStream)
                ? Container(
                    color: const Color(0xFF0F172A),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isVideoOff ? Icons.videocam_off : Icons.account_circle,
                            size: 48,
                            color: Colors.white38,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            !hasStream ? 'Connecting...' : 'Camera Off',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                : RTCVideoView(
                    renderer,
                    mirror: isLocal,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
          ),

          // Name Tag & Audio Status Overlay (Bottom Left)
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMuted ? Icons.mic_off : Icons.mic,
                    size: 14,
                    color: isMuted ? AppColors.callDecline : AppColors.onlineGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOneOnOneVideoArea() {
    return Stack(
      children: [
        // Main Remote Video Stream View (Full area)
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: _callService.remoteRenderer.srcObject != null
                ? RTCVideoView(
                    _callService.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
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
                : RTCVideoView(
                    _callService.localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
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

  static String _formatRoomId(String id) {
    if (id.length <= 16) return id;
    return '${id.substring(0, 8)}...${id.substring(id.length - 4)}';
  }
}
