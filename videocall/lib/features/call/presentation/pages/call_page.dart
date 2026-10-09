import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/meeting_link_service.dart';
import '../../../../core/services/webrtc_call_service.dart';
import '../widgets/call_controls.dart';
import '../widgets/participant_card.dart';
import '../widgets/signal_indicator.dart';
import '../widgets/voice_wave_indicator.dart';
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
    super.key,
    this.callTitle = '1-on-1 Call',
    this.roomId = 'demo-room-1',
    this.userToken,
    this.participantCount = 2,
    this.isVideoCall = true,
    this.isGroupCall = false,
    this.callService,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  late final WebRTCCallService _callService;
  bool _hasNavigatedToEnded = false;

  // ── Speaker Spotlight & Tap-to-Pin Layout Mode ──
  bool _isSpotlightLayout = true;
  String? _pinnedPeerId;
  bool _isPipSwapped = false;

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
        color: Colors.white.withValues(alpha: 0.85),
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
                InkWell(
                  onTap: () => MeetingLinkService.showShareModal(
                    context,
                    roomId: widget.roomId,
                    isVideo: true,
                    title: widget.callTitle,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Room: ${_formatRoomId(widget.roomId)} • ${_callService.callState.name}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.link_rounded, size: 14, color: AppColors.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 20),
            tooltip: 'Share Meeting Link',
            color: AppColors.primary,
            onPressed: () => MeetingLinkService.showShareModal(
              context,
              roomId: widget.roomId,
              isVideo: true,
              title: widget.callTitle,
            ),
          ),
          if (widget.isGroupCall || _callService.remoteRenderers.length > 1) ...[
            IconButton(
              icon: Icon(
                _isSpotlightLayout ? Icons.grid_view_rounded : Icons.featured_video_outlined,
                color: _isSpotlightLayout ? AppColors.primary : AppColors.textPrimary,
              ),
              tooltip: _isSpotlightLayout ? 'Switch to Grid View' : 'Switch to Spotlight View',
              onPressed: () {
                setState(() {
                  _isSpotlightLayout = !_isSpotlightLayout;
                });
              },
            ),
          ],
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            tooltip: 'Switch Camera',
            onPressed: () => _callService.switchCamera(),
          ),
          const SizedBox(width: 4),
          SignalIndicator(
            strength: _callService.localNetworkQuality.bars,
            showLabel: true,
            tooltip: _callService.localNetworkQuality.summaryText,
          ),
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
    final remoteEntries = _callService.remoteRenderers.entries.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        border: const Border(right: BorderSide(color: Color(0xFFDCE7DF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PARTICIPANTS (${1 + remoteEntries.length})',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          // Local (you)
          ParticipantCard(
            name: 'You (Local)',
            initials: 'ME',
            avatarColor: AppColors.primary,
            signalStrength: _callService.localNetworkQuality.bars,
            networkQuality: _callService.localNetworkQuality,
            isSpeaking: _callService.isLocalSpeaking,
            audioLevel: _callService.getAudioLevel('local'),
          ),
          // Live remote participants from remoteRenderers
          ...remoteEntries.asMap().entries.map((mapEntry) {
            final index = mapEntry.key;
            final peerId = mapEntry.value.key;
            final shortId = peerId.length > 6 ? peerId.substring(0, 6) : peerId;
            final name = widget.isGroupCall
                ? 'Member ${index + 1} ($shortId)'
                : 'Remote Peer';
            final initials = widget.isGroupCall
                ? 'M${index + 1}'
                : 'RP';
            final avatarColors = [
              const Color(0xFF10A47D),
              const Color(0xFF8752F4),
              const Color(0xFFE85D04),
              const Color(0xFF0077B6),
              const Color(0xFFD62246),
            ];
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ParticipantCard(
                name: name,
                initials: initials,
                avatarColor: avatarColors[index % avatarColors.length],
                signalStrength: _callService.getNetworkQuality(peerId).bars,
                networkQuality: _callService.getNetworkQuality(peerId),
                isSpeaking: _callService.isSpeaking(peerId),
                audioLevel: _callService.getAudioLevel(peerId),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMainVideoArea() {
    if (widget.isGroupCall || _callService.remoteRenderers.length > 1) {
      if (_isSpotlightLayout) {
        return _buildSpotlightLayout();
      }
      return _buildGroupVideoGrid();
    }
    return _buildOneOnOneVideoArea();
  }

  String _determineSpotlightId() {
    // 1. Explicitly pinned participant
    if (_pinnedPeerId != null) {
      if (_pinnedPeerId == 'local') return 'local';
      if (_callService.remoteRenderers.containsKey(_pinnedPeerId)) {
        return _pinnedPeerId!;
      }
      _pinnedPeerId = null;
    }

    // 2. Auto-Spotlight active speaker
    final active = _callService.activeSpeakerId;
    if (active != null) {
      if (active == 'local') return 'local';
      if (_callService.remoteRenderers.containsKey(active)) return active;
    }

    // 3. Fallback: first remote peer with stream, then first remote peer, then local
    for (final entry in _callService.remoteRenderers.entries) {
      if (entry.value.srcObject != null) return entry.key;
    }
    final firstRemote = _callService.remoteRenderers.keys.firstOrNull;
    if (firstRemote != null) return firstRemote;
    return 'local';
  }

  String _getParticipantName(String peerId) {
    if (peerId == 'local') return 'You';
    final remoteList = _callService.remoteRenderers.keys.toList();
    final index = remoteList.indexOf(peerId);
    final shortId = peerId.length > 6 ? peerId.substring(0, 6) : peerId;
    if (index >= 0) {
      return 'Member ${index + 1} ($shortId)';
    }
    return 'Member ($shortId)';
  }

  Widget _buildSpotlightLayout() {
    final spotlightId = _determineSpotlightId();
    final remoteEntries = _callService.remoteRenderers.entries.toList();

    return Container(
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          // ── Large Hero Spotlight Frame (~75% height) ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: _buildSpotlightHeroTile(spotlightId),
            ),
          ),

          // ── Bottom Thumbnail Filmstrip Ribbon (~120px) ──
          Container(
            height: 122,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F17),
              border: const Border(
                top: BorderSide(color: Color(0xFF1E293B), width: 1),
              ),
            ),
            child: _buildThumbnailRibbon(spotlightId, remoteEntries),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotlightHeroTile(String spotlightId) {
    final isLocal = (spotlightId == 'local');
    final remoteRenderer = isLocal ? null : _callService.remoteRenderers[spotlightId];
    final renderer = isLocal ? _callService.localRenderer : remoteRenderer;
    final isMuted = isLocal ? _callService.isMicMuted : false;
    final isVideoOff = isLocal ? _callService.isVideoOff : false;
    final isSpeaking = isLocal ? _callService.isLocalSpeaking : _callService.isSpeaking(spotlightId);
    final audioLevel = isLocal ? _callService.getAudioLevel('local') : _callService.getAudioLevel(spotlightId);
    final isReconnecting = isLocal ? false : _callService.isPeerReconnecting(spotlightId);
    final quality = isLocal ? _callService.localNetworkQuality : _callService.getNetworkQuality(spotlightId);
    final isPinned = (_pinnedPeerId == spotlightId);

    final title = isLocal ? 'You (Local)' : _getParticipantName(spotlightId);
    final hasStream = renderer != null && renderer.srcObject != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSpeaking
              ? const Color(0xFF10B981)
              : (isPinned
                  ? const Color(0xFFF59E0B)
                  : (isLocal ? AppColors.primary.withValues(alpha: 0.6) : Colors.white24)),
          width: isSpeaking || isPinned ? 3.0 : 1.5,
        ),
        boxShadow: [
          if (isSpeaking)
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
            )
          else if (isPinned)
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 1,
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Main Hero Video View
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
                            size: 64,
                            color: Colors.white38,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            !hasStream ? 'Connecting video...' : 'Camera Off',
                            style: const TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                : RTCVideoView(
                    renderer,
                    key: ValueKey(
                      'spotlight_${renderer.textureId}_${_callService.videoRefreshEpoch}',
                    ),
                    mirror: isLocal,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
          ),

          // Reconnecting Overlay
          if (isReconnecting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.75),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF10B981)),
                      SizedBox(height: 10),
                      Text(
                        'Reconnecting peer stream...',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Top Left Status Badge (Pinned / Active Speaker / Poor Network)
          Positioned(
            top: 12,
            left: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPinned)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _pinnedPeerId = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xE678350F),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.push_pin, color: Color(0xFFFDE68A), size: 13),
                          SizedBox(width: 5),
                          Text(
                            'Pinned • Tap to Unpin',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (isSpeaking)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xE6064E3B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.record_voice_over, color: Color(0xFF6EE7B7), size: 13),
                        SizedBox(width: 5),
                        Text(
                          'Speaking • Auto-Spotlight',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (quality.isPoor && !isReconnecting) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: const Color(0xE67F1D1D),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEF4444), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          quality.packetLossPercent > 0
                              ? 'Poor • ${quality.packetLossPercent}% loss'
                              : 'Latency ${quality.rttMs.toStringAsFixed(0)}ms',
                          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Top Right: Layout Switcher + Signal Strength
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSpotlightLayout = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.grid_view_rounded, color: Colors.white, size: 13),
                        SizedBox(width: 4),
                        Text(
                          'Grid',
                          style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: quality.isPoor ? const Color(0xFFEF4444) : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: SignalIndicator(
                    strength: quality.bars,
                    maxBars: 4,
                    barWidth: 2.2,
                    maxBarHeight: 11,
                    tooltip: quality.summaryText,
                  ),
                ),
              ],
            ),
          ),

          // Bottom Left: Name Tag & Voice Wave
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSpeaking
                    ? const Color(0xE6064E3B)
                    : Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSpeaking ? const Color(0xFF10B981) : Colors.white24,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMuted ? Icons.mic_off : Icons.mic,
                    size: 14,
                    color: isMuted ? AppColors.callDecline : AppColors.onlineGreen,
                  ),
                  if (isSpeaking) ...[
                    const SizedBox(width: 6),
                    VoiceWaveIndicator(
                      isSpeaking: true,
                      audioLevel: audioLevel,
                      maxHeight: 13,
                      barWidth: 2.2,
                      barCount: 4,
                    ),
                  ],
                  const SizedBox(width: 7),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: isSpeaking ? FontWeight.w800 : FontWeight.w600,
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

  Widget _buildThumbnailRibbon(
    String spotlightId,
    List<MapEntry<String, RTCVideoRenderer>> remoteEntries,
  ) {
    final allPeerIds = ['local', ...remoteEntries.map((e) => e.key)];

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: allPeerIds.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final peerId = allPeerIds[index];
        final isLocal = (peerId == 'local');
        final isSpotlighted = (peerId == spotlightId);
        final isPinned = (_pinnedPeerId == peerId);
        final isSpeaking = isLocal ? _callService.isLocalSpeaking : _callService.isSpeaking(peerId);
        final audioLevel = isLocal ? _callService.getAudioLevel('local') : _callService.getAudioLevel(peerId);
        final isMuted = isLocal ? _callService.isMicMuted : false;
        final isVideoOff = isLocal ? _callService.isVideoOff : false;
        final quality = isLocal ? _callService.localNetworkQuality : _callService.getNetworkQuality(peerId);
        final title = isLocal ? 'You' : _getParticipantName(peerId);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (_pinnedPeerId == peerId) {
                _pinnedPeerId = null;
              } else {
                _pinnedPeerId = peerId;
              }
            });
          },
          child: Container(
            width: 140,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSpotlighted
                    ? (isPinned ? const Color(0xFFF59E0B) : const Color(0xFF10B981))
                    : (isSpeaking ? const Color(0xFF10B981) : Colors.white12),
                width: isSpotlighted || isSpeaking ? 2.2 : 1.0,
              ),
              boxShadow: [
                if (isSpotlighted || isSpeaking)
                  BoxShadow(
                    color: (isPinned ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                if (isSpotlighted)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPinned
                            ? [const Color(0xFF451A03), const Color(0xFF1E293B)]
                            : [const Color(0xFF064E3B), const Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isPinned ? Icons.push_pin : Icons.featured_video_rounded,
                            color: isPinned ? const Color(0xFFFBBF24) : const Color(0xFF34D399),
                            size: 26,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPinned ? 'PINNED' : 'ON STAGE',
                            style: TextStyle(
                              color: isPinned ? const Color(0xFFFDE68A) : const Color(0xFF6EE7B7),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Positioned.fill(
                    child: (isVideoOff ||
                            (isLocal
                                ? _callService.localRenderer.srcObject == null
                                : _callService.remoteRenderers[peerId]?.srcObject == null))
                        ? Container(
                            color: const Color(0xFF0F172A),
                            child: Center(
                              child: Icon(
                                isVideoOff ? Icons.videocam_off : Icons.account_circle,
                                size: 30,
                                color: Colors.white38,
                              ),
                            ),
                          )
                        : RTCVideoView(
                            isLocal ? _callService.localRenderer : _callService.remoteRenderers[peerId]!,
                            key: ValueKey('thumb_${peerId}_${_callService.videoRefreshEpoch}'),
                            mirror: isLocal,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          ),
                  ),

                // Top Pin Icon Indicator
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isPinned
                          ? const Color(0xFFF59E0B)
                          : Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 11,
                      color: isPinned ? Colors.black : Colors.white70,
                    ),
                  ),
                ),

                // Bottom Overlay Bar (Name + Mic + Wave)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isMuted ? Icons.mic_off : Icons.mic,
                          size: 11,
                          color: isMuted ? AppColors.callDecline : AppColors.onlineGreen,
                        ),
                        if (isSpeaking) ...[
                          const SizedBox(width: 3),
                          VoiceWaveIndicator(
                            isSpeaking: true,
                            audioLevel: audioLevel,
                            maxHeight: 9,
                            barWidth: 1.6,
                            barCount: 2,
                          ),
                        ],
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SignalIndicator(
                          strength: quality.bars,
                          maxBars: 4,
                          barWidth: 1.8,
                          maxBarHeight: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupVideoGrid() {
    final remoteEntries = _callService.remoteRenderers.entries.toList();
    final totalParticipants = 1 + remoteEntries.length;

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
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSpotlightLayout = true;
                      _pinnedPeerId = 'local';
                    });
                  },
                  child: _buildVideoTile(
                    title: 'You (Local)',
                    isLocal: true,
                    renderer: _callService.localRenderer,
                    isMuted: _callService.isMicMuted,
                    isVideoOff: _callService.isVideoOff,
                    isSpeaking: _callService.isLocalSpeaking,
                    audioLevel: _callService.getAudioLevel('local'),
                    networkQuality: _callService.localNetworkQuality,
                    onPinTap: () {
                      setState(() {
                        _isSpotlightLayout = true;
                        _pinnedPeerId = 'local';
                      });
                    },
                    isPinned: _pinnedPeerId == 'local',
                  ),
                );
              }

              // Tiles 1..N: Remote Peer Video Streams
              final peerEntry = remoteEntries[index - 1];
              final peerId = peerEntry.key;
              final peerRenderer = peerEntry.value;
              final isPeerSpeaking = _callService.isSpeaking(peerId);
              final peerAudioLevel = _callService.getAudioLevel(peerId);
              final isPeerReconnecting = _callService.isPeerReconnecting(peerId);
              final peerQuality = _callService.getNetworkQuality(peerId);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _isSpotlightLayout = true;
                    _pinnedPeerId = peerId;
                  });
                },
                child: _buildVideoTile(
                  title: _getParticipantName(peerId),
                  isLocal: false,
                  renderer: peerRenderer,
                  isMuted: false,
                  isVideoOff: false,
                  isSpeaking: isPeerSpeaking,
                  audioLevel: peerAudioLevel,
                  isReconnecting: isPeerReconnecting,
                  networkQuality: peerQuality,
                  onPinTap: () {
                    setState(() {
                      _isSpotlightLayout = true;
                      _pinnedPeerId = peerId;
                    });
                  },
                  isPinned: _pinnedPeerId == peerId,
                ),
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
    bool isSpeaking = false,
    double audioLevel = 0.0,
    bool isReconnecting = false,
    NetworkQuality? networkQuality,
    VoidCallback? onPinTap,
    bool isPinned = false,
  }) {
    final hasStream = renderer.srcObject != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSpeaking
              ? const Color(0xFF10B981)
              : (isPinned
                  ? const Color(0xFFF59E0B)
                  : (isLocal ? AppColors.primary.withValues(alpha: 0.6) : Colors.white24)),
          width: isSpeaking || isPinned ? 3.0 : 2.0,
        ),
        boxShadow: [
          if (isSpeaking)
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.55),
              blurRadius: 18,
              spreadRadius: 2,
            )
          else if (isPinned)
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 1,
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
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
                    key: ValueKey(
                      'tile_${renderer.textureId}_${_callService.videoRefreshEpoch}',
                    ),
                    mirror: isLocal,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
          ),

          // Live Signal Indicator (Top Right)
          if (networkQuality != null)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: networkQuality.isPoor
                        ? const Color(0xFFEF4444)
                        : Colors.white24,
                    width: 0.8,
                  ),
                ),
                child: SignalIndicator(
                  strength: networkQuality.bars,
                  maxBars: 4,
                  barWidth: 2.2,
                  maxBarHeight: 11,
                  tooltip: networkQuality.summaryText,
                ),
              ),
            ),

          // Poor Network Warning Banner (Top Left)
          if (networkQuality != null && networkQuality.isPoor && !isReconnecting)
            Positioned(
              top: 10,
              left: 10,
              right: 50,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xE67F1D1D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF4444), width: 1),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 12),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        networkQuality.packetLossPercent > 0
                            ? 'Poor Network • Loss: ${networkQuality.packetLossPercent}%'
                            : 'Poor Network • Latency: ${networkQuality.rttMs.toStringAsFixed(0)}ms',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Reconnecting Overlay (if network drops and ICE restarts)
          if (isReconnecting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.72),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xE6064E3B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981), width: 1),
                        ),
                        child: const Text(
                          'Reconnecting...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Tap to Pin / Pinned Badge (Bottom Right)
          if (onPinTap != null)
            Positioned(
              right: 10,
              bottom: 10,
              child: GestureDetector(
                onTap: onPinTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPinned ? const Color(0xFFF59E0B) : Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isPinned ? const Color(0xFFFDE68A) : Colors.white24,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                        size: 11,
                        color: isPinned ? Colors.black : Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPinned ? 'Pinned' : 'Pin',
                        style: TextStyle(
                          color: isPinned ? Colors.black : Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Name Tag & Audio Status Overlay (Bottom Left)
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSpeaking
                    ? const Color(0xE6064E3B)
                    : Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSpeaking ? const Color(0xFF10B981) : Colors.white24,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMuted ? Icons.mic_off : Icons.mic,
                    size: 14,
                    color: isMuted ? AppColors.callDecline : AppColors.onlineGreen,
                  ),
                  if (isSpeaking) ...[
                    const SizedBox(width: 5),
                    VoiceWaveIndicator(
                      isSpeaking: true,
                      audioLevel: audioLevel,
                      maxHeight: 12,
                      barWidth: 2,
                      barCount: 3,
                    ),
                  ],
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: isSpeaking ? FontWeight.w700 : FontWeight.w600,
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
    final isRemoteSpeaking = _callService.activeSpeakerId != null &&
        _callService.activeSpeakerId != 'local';
    final remoteAudioLevel = isRemoteSpeaking
        ? _callService.getAudioLevel(_callService.activeSpeakerId!)
        : 0.0;
    final remotePeerId = _callService.remoteRenderers.keys.firstOrNull ?? '';
    final remoteQuality = _callService.getNetworkQuality(remotePeerId);

    final mainRenderer = _isPipSwapped ? _callService.localRenderer : _callService.remoteRenderer;
    final pipRenderer = _isPipSwapped ? _callService.remoteRenderer : _callService.localRenderer;
    final isMainLocal = _isPipSwapped;
    final isPipLocal = !_isPipSwapped;

    return Stack(
      children: [
        // Main Video Stream View (Full area)
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: mainRenderer.srcObject != null
                ? RTCVideoView(
                    mainRenderer,
                    key: ValueKey(
                      'main_${mainRenderer.textureId}_${_callService.videoRefreshEpoch}',
                    ),
                    mirror: isMainLocal,
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

        // Reconnecting Notice Banner (Top Left)
        if (_callService.isAnyReconnecting)
          Positioned(
            top: 20,
            left: 20,
            right: 175,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xE678350F),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Network unstable • Reconnecting...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (remoteQuality.isPoor)
          Positioned(
            top: 20,
            left: 20,
            right: 175,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xE67F1D1D),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      remoteQuality.packetLossPercent > 0
                          ? 'Poor network • ${remoteQuality.packetLossPercent}% packet loss'
                          : 'Poor network • Latency ${remoteQuality.rttMs.toStringAsFixed(0)}ms',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SignalIndicator(
                    strength: remoteQuality.bars,
                    maxBars: 4,
                    barWidth: 2.5,
                    maxBarHeight: 11,
                    tooltip: remoteQuality.summaryText,
                  ),
                ],
              ),
            ),
          ),

        // Remote Active Speaker Floating Pill (Bottom Left)
        if (isRemoteSpeaking)
          Positioned(
            left: 20,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xE6064E3B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VoiceWaveIndicator(
                    isSpeaking: true,
                    audioLevel: remoteAudioLevel,
                    maxHeight: 14,
                    barWidth: 2.2,
                    barCount: 4,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.callTitle} is speaking',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Floating Video Preview (Picture-in-Picture) • Tap to Swap
        Positioned(
          right: 20,
          top: 20,
          width: 140,
          height: 190,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isPipSwapped = !_isPipSwapped;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (isPipLocal && _callService.isLocalSpeaking) ||
                          (!isPipLocal && isRemoteSpeaking)
                      ? const Color(0xFF10B981)
                      : Colors.white38,
                  width: (isPipLocal && _callService.isLocalSpeaking) ||
                          (!isPipLocal && isRemoteSpeaking)
                      ? 3
                      : 2,
                ),
                boxShadow: [
                  if ((isPipLocal && _callService.isLocalSpeaking) ||
                      (!isPipLocal && isRemoteSpeaking))
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.55),
                      blurRadius: 16,
                      spreadRadius: 2,
                    )
                  else
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: (isPipLocal && _callService.isVideoOff)
                        ? const Center(
                            child: Icon(Icons.videocam_off, color: Colors.white54, size: 36),
                          )
                        : (pipRenderer.srcObject == null)
                            ? const Center(
                                child: Icon(Icons.account_circle, color: Colors.white38, size: 36),
                              )
                            : RTCVideoView(
                                pipRenderer,
                                key: ValueKey(
                                  'pip_${pipRenderer.textureId}_${_callService.videoRefreshEpoch}',
                                ),
                                mirror: isPipLocal,
                                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                              ),
                  ),

                  // Bottom Tag
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xE6064E3B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPipLocal && _callService.isLocalSpeaking) ...[
                            VoiceWaveIndicator(
                              isSpeaking: true,
                              audioLevel: _callService.getAudioLevel('local'),
                              maxHeight: 10,
                              barWidth: 1.8,
                              barCount: 3,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            isPipLocal ? 'You' : 'Peer',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top Right Swap Icon & Signal Indicator
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.swap_horiz, color: Colors.white70, size: 12),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: SignalIndicator(
                            strength: isPipLocal
                                ? _callService.localNetworkQuality.bars
                                : remoteQuality.bars,
                            maxBars: 4,
                            barWidth: 2.0,
                            maxBarHeight: 9,
                            tooltip: isPipLocal
                                ? _callService.localNetworkQuality.summaryText
                                : remoteQuality.summaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
