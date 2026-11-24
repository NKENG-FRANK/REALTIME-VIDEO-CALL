import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/meeting_link_service.dart';
import '../../../../core/services/webrtc_call_service.dart';
import '../../../../core/widgets/call/control_dock.dart';
import '../../../../core/widgets/call/video_tile.dart';
import '../../../../features/settings/presentation/controllers/settings_controller.dart';
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
    required this.roomId,
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
  bool _mobileChromeVisible = true;
  Offset? _mobileSelfViewPosition;
  bool _showWeakSignalToast = false;
  bool _weakSignalToastDismissed = false;
  Timer? _weakSignalToastTimer;

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
      debugPrint(
        '[CallPage] No auth token found — cannot connect WebRTC socket',
      );
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
          duration: (durationStr == '00:00' || durationStr.isEmpty)
              ? '00:05'
              : durationStr,
          quality: 'Good',
          // Callbacks use newContext — the CallEndedPage's own context
          onBackToHome: () {
            Navigator.of(newContext)
                .pushNamedAndRemoveUntil('/calls', (route) => false);
          },
          onCallAgain: () {
            Navigator.of(newContext)
                .pushNamedAndRemoveUntil('/calls', (route) => false);
          },
        ),
      ),
    );
  }

  void _updateWeakSignalToast() {
    final weak =
        _callService.localNetworkQuality.isPoor ||
        _callService.remotePeerIds.any(
          (peerId) => _callService.getNetworkQuality(peerId).isPoor,
        );
    if (!weak) {
      _weakSignalToastTimer?.cancel();
      _weakSignalToastTimer = null;
      _showWeakSignalToast = false;
      _weakSignalToastDismissed = false;
      return;
    }
    if (_showWeakSignalToast || _weakSignalToastDismissed) return;
    _showWeakSignalToast = true;
    _weakSignalToastTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _showWeakSignalToast = false;
        _weakSignalToastDismissed = true;
      });
    });
  }

  void _onCallStateChanged() {
    if (!mounted) return;
    _updateWeakSignalToast();
    setState(() {});
    if (_callService.callState == CallState.ended) {
      _navigateToEndedPage();
    }
  }

  bool _reduceMotion(BuildContext context) {
    final systemSetting =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final appSetting =
        Provider.of<SettingsController?>(
          context,
          listen: false,
        )?.settings.reduceMotion ??
        false;
    return systemSetting || appSetting;
  }

  @override
  void dispose() {
    _weakSignalToastTimer?.cancel();
    _callService.removeListener(_onCallStateChanged);
    _callService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 760 &&
        widget.isVideoCall &&
        widget.isGroupCall) {
      return Theme(data: AppTheme.lightTheme(), child: _buildMobileGroupCall());
    }
    final isMobileOneToOne =
        MediaQuery.sizeOf(context).width < 760 &&
        widget.isVideoCall &&
        !widget.isGroupCall;
    if (isMobileOneToOne) {
      return Theme(
        data: AppTheme.lightTheme(),
        child: _buildMobileOneToOneCall(),
      );
    }

    return Theme(
      data: AppTheme.lightTheme(),
      child: Scaffold(
        backgroundColor: const Color(0xFF4E8F72),
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: Palette.callGradient),
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 760;
                      return isMobile
                          ? _buildMobileLayout()
                          : _buildDesktopLayout();
                    },
                  ),
                ),
                _buildBottomControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileGroupCall() {
    final l10n = AppLocalizations.of(context);
    final safe = MediaQuery.paddingOf(context);
    final duration = _reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 350);
    final spotlight = _determineSpotlightId();
    final participants = [..._callService.remoteRenderers.keys, 'local'];
    Widget tile(String peerId, {required double radius}) {
      final local = peerId == 'local';
      final name = _getParticipantName(peerId);
      return VideoTile(
        renderer: local
            ? _callService.localRenderer
            : _callService.remoteRenderers[peerId],
        name: name,
        initials: _initialsForName(name),
        isLocal: local,
        mirror: local,
        isCameraOff: local && _callService.isVideoOff,
        isMicMuted: local && _callService.isMicMuted,
        isActiveSpeaker: local
            ? _callService.isLocalSpeaking
            : _callService.isSpeaking(peerId),
        audioLevel: _callService.getAudioLevel(peerId),
        borderRadius: radius,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF4E8F72),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: Palette.callGradient),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  safe.top + 92,
                  12,
                  safe.bottom + 108,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _toggleMobileChrome,
                        child: tile(spotlight, radius: 28),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 84,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: participants.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final peerId = participants[index];
                          return Semantics(
                            button: true,
                            selected: peerId == spotlight,
                            label: _getParticipantName(peerId),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _pinnedPeerId = peerId),
                              onLongPress: () =>
                                  setState(() => _pinnedPeerId = null),
                              child: Container(
                                width: 116,
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: peerId == spotlight
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: tile(peerId, radius: 14),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildMobileTopChrome(
              l10n: l10n,
              duration: duration,
              reduceMotion: _reduceMotion(context),
            ),
            _buildMobileControlChrome(
              l10n: l10n,
              duration: duration,
              reduceMotion: _reduceMotion(context),
              bottomInset: safe.bottom,
            ),
          ],
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

  void _toggleMobileChrome() {
    setState(() => _mobileChromeVisible = !_mobileChromeVisible);
  }

  Widget _buildMobileOneToOneCall() {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF4E8F72),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final safe = MediaQuery.paddingOf(context);
          final reduceMotion = _reduceMotion(context);
          final chromeDuration = reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 350);
          final remotePeerId = _callService.remotePeerIds.firstOrNull ?? '';
          final remoteRenderer =
              _callService.remoteRenderers[remotePeerId] ??
              _callService.remoteRenderer;
          final isRemoteSpeaking =
              _callService.activeSpeakerId != null &&
              _callService.activeSpeakerId != 'local';
          final leftLimit = math.max(12.0, constraints.maxWidth - 110);
          final topLimit = safe.top + 76;
          final bottomLimit = math.max(
            topLimit,
            constraints.maxHeight - safe.bottom - 138 - 112,
          );
          final currentPosition =
              _mobileSelfViewPosition ?? Offset(leftLimit, topLimit);
          final selfViewLeft = currentPosition.dx
              .clamp(12.0, leftLimit)
              .toDouble();
          final selfViewTop = currentPosition.dy
              .clamp(topLimit, bottomLimit)
              .toDouble();

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleMobileChrome,
                  child: VideoTile(
                    renderer: remoteRenderer,
                    name: remotePeerId.isEmpty
                        ? l10n.text(fr: 'Participant', en: 'Participant')
                        : _getParticipantName(remotePeerId),
                    initials: _initialsForName(
                      remotePeerId.isEmpty
                          ? widget.callTitle
                          : _getParticipantName(remotePeerId),
                    ),
                    isActiveSpeaker: isRemoteSpeaking,
                    audioLevel: isRemoteSpeaking
                        ? _callService.getAudioLevel(
                            _callService.activeSpeakerId!,
                          )
                        : 0,
                  ),
                ),
              ),
              Positioned(
                left: selfViewLeft,
                top: selfViewTop,
                width: 98,
                height: 138,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    final previous =
                        _mobileSelfViewPosition ?? Offset(leftLimit, topLimit);
                    setState(() {
                      _mobileSelfViewPosition = Offset(
                        (previous.dx + details.delta.dx)
                            .clamp(12.0, leftLimit)
                            .toDouble(),
                        (previous.dy + details.delta.dy)
                            .clamp(topLimit, bottomLimit)
                            .toDouble(),
                      );
                    });
                  },
                  onPanEnd: (_) {
                    final current =
                        _mobileSelfViewPosition ?? Offset(leftLimit, topLimit);
                    final left = current.dx < constraints.maxWidth / 2
                        ? 12.0
                        : leftLimit;
                    final top = current.dy < (topLimit + bottomLimit) / 2
                        ? topLimit
                        : bottomLimit;
                    setState(() {
                      _mobileSelfViewPosition = Offset(left, top);
                    });
                  },
                  child: VideoTile(
                    renderer: _callService.localRenderer,
                    name: l10n.text(fr: 'Vous', en: 'You'),
                    initials: _initialsForName(
                      l10n.text(fr: 'Vous', en: 'You'),
                    ),
                    isLocal: true,
                    isCameraOff: _callService.isVideoOff,
                    isMicMuted: _callService.isMicMuted,
                    isActiveSpeaker: _callService.isLocalSpeaking,
                    audioLevel: _callService.getAudioLevel('local'),
                    borderRadius: 22,
                    mirror: true,
                  ),
                ),
              ),
              _buildMobileTopChrome(
                l10n: l10n,
                duration: chromeDuration,
                reduceMotion: reduceMotion,
              ),
              _buildMobileControlChrome(
                l10n: l10n,
                duration: chromeDuration,
                reduceMotion: reduceMotion,
                bottomInset: safe.bottom,
              ),
              if (_showWeakSignalToast)
                Positioned(
                  top: safe.top + 74,
                  left: 20,
                  right: 20,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xD90B1F16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 9,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.text(
                                fr: 'Signal faible. Réduction de la qualité vidéo.',
                                en: 'Weak signal. Lowering video quality.',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobileTopChrome({
    required AppLocalizations l10n,
    required Duration duration,
    required bool reduceMotion,
  }) {
    final callState = _callService.callState == CallState.connected
        ? l10n.text(fr: 'Chiffré', en: 'Encrypted')
        : l10n.connecting;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_mobileChromeVisible,
        child: AnimatedSlide(
          duration: duration,
          curve: const Cubic(0.2, 0.8, 0.2, 1),
          offset: _mobileChromeVisible ? Offset.zero : const Offset(0, -0.12),
          child: AnimatedOpacity(
            duration: duration,
            opacity: _mobileChromeVisible ? 1 : 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                8,
                MediaQuery.paddingOf(context).top + 8,
                12,
                34,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x8C07110C), Color(0x0007110C)],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _toggleMobileChrome,
                    tooltip: l10n.text(
                      fr: 'Masquer les commandes',
                      en: 'Hide controls',
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    color: Colors.white,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.callTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.lock_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              callState,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Text(
                              _callService.formattedDuration,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'HD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SignalIndicator(
                    strength: _callService.localNetworkQuality.bars,
                    tooltip: _callService.localNetworkQuality.summaryText,
                    maxBars: 4,
                    barWidth: 2,
                    maxBarHeight: 11,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileControlChrome({
    required AppLocalizations l10n,
    required Duration duration,
    required bool reduceMotion,
    required double bottomInset,
  }) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: bottomInset + 12,
      child: IgnorePointer(
        ignoring: !_mobileChromeVisible,
        child: AnimatedSlide(
          duration: duration,
          curve: const Cubic(0.2, 0.8, 0.2, 1),
          offset: _mobileChromeVisible ? Offset.zero : const Offset(0, 0.18),
          child: AnimatedOpacity(
            duration: duration,
            opacity: _mobileChromeVisible ? 1 : 0,
            child: Center(
              child: ControlDock(
                actions: [
                  CallDockAction(
                    icon: _callService.isMicMuted
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                    label: _callService.isMicMuted ? l10n.unmute : l10n.mute,
                    isOff: _callService.isMicMuted,
                    onPressed: _callService.toggleMic,
                  ),
                  CallDockAction(
                    icon: _callService.isVideoOff
                        ? Icons.videocam_off_rounded
                        : Icons.videocam_rounded,
                    label: _callService.isVideoOff
                        ? l10n.text(
                            fr: 'Activer la caméra',
                            en: 'Turn camera on',
                          )
                        : l10n.text(
                            fr: 'Désactiver la caméra',
                            en: 'Turn camera off',
                          ),
                    isOff: _callService.isVideoOff,
                    onPressed: _callService.toggleCamera,
                  ),
                  CallDockAction(
                    icon: widget.isGroupCall
                        ? Icons.people_outline_rounded
                        : Icons.cameraswitch_rounded,
                    label: widget.isGroupCall
                        ? l10n.participants
                        : l10n.flipCamera,
                    onPressed: widget.isGroupCall
                        ? _showMobileParticipants
                        : _callService.switchCamera,
                  ),
                  CallDockAction(
                    icon: Icons.more_horiz_rounded,
                    label: l10n.text(fr: 'Plus d’options', en: 'More'),
                    onPressed: _showMobileMoreActions,
                  ),
                  CallDockAction(
                    icon: Icons.call_end_rounded,
                    label: l10n.text(fr: 'Fin', en: 'End'),
                    isEnd: true,
                    onPressed: _hangUpAndExit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMobileParticipants() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: Column(
            children: [
              Text(
                '${l10n.participants} · ${_callService.remoteRenderers.length + 1}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Expanded(
                child: ListView(
                  children: [..._callService.remoteRenderers.keys, 'local']
                      .map(
                        (peerId) => ListTile(
                          leading: const Icon(Icons.person_outline_rounded),
                          title: Text(_getParticipantName(peerId)),
                          trailing: Icon(
                            peerId == 'local' && _callService.isMicMuted
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: Text(l10n.addParticipants),
                  onPressed: () {
                    Navigator.pop(context);
                    MeetingLinkService.showShareModal(
                      this.context,
                      roomId: widget.roomId,
                      isVideo: true,
                      title: widget.callTitle,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMobileMoreActions() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Widget actionTile({
            required IconData icon,
            required String title,
            VoidCallback? onTap,
          }) => Material(
            color: AppTheme.lightTheme().colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(24),
              child: Opacity(
                opacity: onTap == null ? 0.42 : 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: AppColors.textPrimary),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          void notReady(String name) {
            Navigator.pop(sheetContext);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  l10n.text(
                    fr: '$name n’est pas encore disponible',
                    en: '$name is not available yet',
                  ),
                ),
              ),
            );
          }

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF4EA),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          l10n.text(fr: 'Plus d’options', en: 'More options'),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1,
                      children: [
                        actionTile(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: l10n.text(fr: 'Discussion', en: 'Chat'),
                          onTap: () => notReady(
                            l10n.text(fr: 'La discussion', en: 'Chat'),
                          ),
                        ),
                        actionTile(
                          icon: Icons.screen_share_outlined,
                          title: l10n.screenShare,
                          onTap: () => notReady(l10n.screenShare),
                        ),
                        actionTile(
                          icon: Icons.fiber_manual_record_rounded,
                          title: l10n.text(fr: 'Enregistrer', en: 'Record'),
                        ),
                        actionTile(
                          icon: Icons.person_add_alt_1_rounded,
                          title: l10n.addParticipants,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            MeetingLinkService.showShareModal(
                              context,
                              roomId: widget.roomId,
                              isVideo: true,
                              title: widget.callTitle,
                            );
                          },
                        ),
                        actionTile(
                          icon: Icons.blur_on_rounded,
                          title: l10n.text(
                            fr: 'Flouter l’arrière-plan',
                            en: 'Blur background',
                          ),
                        ),
                        actionTile(
                          icon: Icons.pause_circle_outline_rounded,
                          title: l10n.text(fr: 'Mettre en attente', en: 'Hold'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _initialsForName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    if (parts.isEmpty) return 'CW';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  Widget _buildTopBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final l10n = AppLocalizations.of(context);
        final isMobile = constraints.maxWidth < 600;
        final callState = switch (_callService.callState) {
          CallState.idle => l10n.text(fr: 'Inactif', en: 'Idle'),
          CallState.connecting => l10n.connecting,
          CallState.connected => l10n.text(fr: 'Connecté', en: 'Connected'),
          CallState.ended => l10n.callEnded,
        };

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 20,
            vertical: isMobile ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: const Color(0xE613241C),
            border: const Border(bottom: BorderSide(color: Color(0x1FFFFFFF))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                padding: EdgeInsets.zero,
                constraints: isMobile
                    ? const BoxConstraints(minWidth: 36, minHeight: 36)
                    : null,
                onPressed: _hangUpAndExit,
              ),
              SizedBox(width: isMobile ? 4 : 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.callTitle,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 14 : 16,
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
                          Flexible(
                            child: Text(
                              l10n.text(
                                fr: 'Salle : ${_formatRoomId(widget.roomId)} • $callState',
                                en: 'Room: ${_formatRoomId(widget.roomId)} • $callState',
                              ),
                              style: const TextStyle(
                                color: Color(0xFF8DA69A),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.link_rounded,
                            size: 13,
                            color: Color(0xFF3DDC97),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded, size: 19),
                padding: EdgeInsets.zero,
                constraints: isMobile
                    ? const BoxConstraints(minWidth: 34, minHeight: 34)
                    : null,
                tooltip: l10n.text(
                  fr: 'Partager le lien',
                  en: 'Share meeting link',
                ),
                color: const Color(0xFF3DDC97),
                onPressed: () => MeetingLinkService.showShareModal(
                  context,
                  roomId: widget.roomId,
                  isVideo: true,
                  title: widget.callTitle,
                ),
              ),
              if (widget.isGroupCall ||
                  _callService.remoteRenderers.length > 1) ...[
                IconButton(
                  icon: Icon(
                    _isSpotlightLayout
                        ? Icons.grid_view_rounded
                        : Icons.featured_video_outlined,
                    color: _isSpotlightLayout
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: isMobile
                      ? const BoxConstraints(minWidth: 34, minHeight: 34)
                      : null,
                  tooltip: _isSpotlightLayout
                      ? l10n.text(
                          fr: 'Passer en vue grille',
                          en: 'Switch to grid view',
                        )
                      : l10n.text(
                          fr: 'Passer en vue projecteur',
                          en: 'Switch to spotlight view',
                        ),
                  onPressed: () {
                    setState(() {
                      _isSpotlightLayout = !_isSpotlightLayout;
                    });
                  },
                ),
              ],
              IconButton(
                icon: const Icon(Icons.cameraswitch, size: 20),
                padding: EdgeInsets.zero,
                constraints: isMobile
                    ? const BoxConstraints(minWidth: 34, minHeight: 34)
                    : null,
                tooltip: l10n.flipCamera,
                onPressed: () => _callService.switchCamera(),
              ),
              const SizedBox(width: 2),
              SignalIndicator(
                strength: _callService.localNetworkQuality.bars,
                showLabel: !isMobile,
                tooltip: _callService.localNetworkQuality.summaryText,
              ),
            ],
          ),
        );
      },
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
    return Column(children: [Expanded(child: _buildMainVideoArea())]);
  }

  Widget _buildParticipantSidebar() {
    final l10n = AppLocalizations.of(context);
    final remoteEntries = _callService.remoteRenderers.entries.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xE613241C),
        border: const Border(right: BorderSide(color: Color(0x1FFFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.participants.toUpperCase()} (${1 + remoteEntries.length})',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          // Local (you)
          ParticipantCard(
            name: l10n.text(fr: 'Vous (local)', en: 'You (local)'),
            initials: l10n.text(fr: 'MO', en: 'ME'),
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
                ? l10n.text(
                    fr: 'Membre ${index + 1} ($shortId)',
                    en: 'Member ${index + 1} ($shortId)',
                  )
                : l10n.text(fr: 'Participant distant', en: 'Remote peer');
            final initials = widget.isGroupCall ? 'M${index + 1}' : 'RP';
            final avatarColors = [
              AppColors.primary,
              AppColors.accent,
              AppColors.error,
              AppColors.primaryLight,
              const Color(0xFF8DA69A),
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
    final l10n = AppLocalizations.of(context);
    if (peerId == 'local') return l10n.text(fr: 'Vous', en: 'You');
    final remoteList = _callService.remoteRenderers.keys.toList();
    final index = remoteList.indexOf(peerId);
    final shortId = peerId.length > 6 ? peerId.substring(0, 6) : peerId;
    if (index >= 0) {
      return l10n.text(
        fr: 'Membre ${index + 1} ($shortId)',
        en: 'Member ${index + 1} ($shortId)',
      );
    }
    return l10n.text(fr: 'Membre ($shortId)', en: 'Member ($shortId)');
  }

  Widget _buildSpotlightLayout() {
    final spotlightId = _determineSpotlightId();
    final remoteEntries = _callService.remoteRenderers.entries.toList();

    return Container(
      decoration: const BoxDecoration(gradient: Palette.callGradient),
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
            decoration: const BoxDecoration(
              gradient: Palette.callGradient,
              border: Border(
                top: BorderSide(color: Color(0xFF1B3A2C), width: 1),
              ),
            ),
            child: _buildThumbnailRibbon(spotlightId, remoteEntries),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotlightHeroTile(String spotlightId) {
    final l10n = AppLocalizations.of(context);
    final isLocal = (spotlightId == 'local');
    final remoteRenderer = isLocal
        ? null
        : _callService.remoteRenderers[spotlightId];
    final renderer = isLocal ? _callService.localRenderer : remoteRenderer;
    final isMuted = isLocal ? _callService.isMicMuted : false;
    final isVideoOff = isLocal ? _callService.isVideoOff : false;
    final isSpeaking = isLocal
        ? _callService.isLocalSpeaking
        : _callService.isSpeaking(spotlightId);
    final audioLevel = isLocal
        ? _callService.getAudioLevel('local')
        : _callService.getAudioLevel(spotlightId);
    final isReconnecting = isLocal
        ? false
        : _callService.isPeerReconnecting(spotlightId);
    final quality = isLocal
        ? _callService.localNetworkQuality
        : _callService.getNetworkQuality(spotlightId);
    final isPinned = (_pinnedPeerId == spotlightId);

    final title = isLocal
        ? l10n.text(fr: 'Vous (local)', en: 'You (local)')
        : _getParticipantName(spotlightId);
    final hasStream = renderer != null && renderer.srcObject != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13231A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSpeaking
              ? AppColors.signalExcellent
              : (isPinned
                    ? AppColors.accent
                    : (isLocal
                          ? AppColors.primary.withValues(alpha: 0.6)
                          : Colors.white24)),
          width: isSpeaking || isPinned ? 3.0 : 1.5,
        ),
        boxShadow: [
          if (isSpeaking)
            BoxShadow(
              color: AppColors.signalExcellent.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
            )
          else if (isPinned)
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.4),
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
                    decoration: const BoxDecoration(
                      gradient: Palette.callGradient,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isVideoOff
                                ? Icons.videocam_off
                                : Icons.account_circle,
                            size: 64,
                            color: Colors.white38,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            !hasStream
                                ? l10n.text(
                                    fr: 'Connexion vidéo…',
                                    en: 'Connecting video…',
                                  )
                                : l10n.text(
                                    fr: 'Caméra désactivée',
                                    en: 'Camera off',
                                  ),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
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
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.signalExcellent,
                      ),
                      SizedBox(height: 10),
                      Text(
                        l10n.text(
                          fr: 'Reconnexion du flux vidéo…',
                          en: 'Reconnecting video stream…',
                        ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE63A2E0B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.accent, width: 1.2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 6),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.push_pin,
                            color: AppColors.accent,
                            size: 13,
                          ),
                          SizedBox(width: 5),
                          Text(
                            l10n.text(
                              fr: 'Épinglé • Touchez pour retirer',
                              en: 'Pinned • Tap to unpin',
                            ),
                            style: const TextStyle(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xE60F3D2A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.signalExcellent,
                        width: 1.2,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 6),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.record_voice_over,
                          color: AppColors.signalExcellent,
                          size: 13,
                        ),
                        SizedBox(width: 5),
                        Text(
                          l10n.text(
                            fr: 'Prise de parole • Mise en avant automatique',
                            en: 'Speaking • Auto-spotlight',
                          ),
                          style: const TextStyle(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xE67F1D1D),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFEF4444),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          quality.packetLossPercent > 0
                              ? l10n.text(
                                  fr: 'Faible • ${quality.packetLossPercent}% de perte',
                                  en: 'Poor • ${quality.packetLossPercent}% loss',
                                )
                              : l10n.text(
                                  fr: 'Latence ${quality.rttMs.toStringAsFixed(0)} ms',
                                  en: 'Latency ${quality.rttMs.toStringAsFixed(0)} ms',
                                ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                        SizedBox(width: 4),
                        Text(
                          l10n.text(fr: 'Grille', en: 'Grid'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: quality.isPoor
                          ? const Color(0xFFEF4444)
                          : Colors.white24,
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
                    ? const Color(0xE60F3D2A)
                    : Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSpeaking
                      ? AppColors.signalExcellent
                      : Colors.white24,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMuted ? Icons.mic_off : Icons.mic,
                    size: 14,
                    color: isMuted
                        ? AppColors.callDecline
                        : AppColors.onlineGreen,
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
                      fontWeight: isSpeaking
                          ? FontWeight.w800
                          : FontWeight.w600,
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
    final l10n = AppLocalizations.of(context);
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
        final isSpeaking = isLocal
            ? _callService.isLocalSpeaking
            : _callService.isSpeaking(peerId);
        final audioLevel = isLocal
            ? _callService.getAudioLevel('local')
            : _callService.getAudioLevel(peerId);
        final isMuted = isLocal ? _callService.isMicMuted : false;
        final isVideoOff = isLocal ? _callService.isVideoOff : false;
        final quality = isLocal
            ? _callService.localNetworkQuality
            : _callService.getNetworkQuality(peerId);
        final title = isLocal
            ? l10n.text(fr: 'Vous', en: 'You')
            : _getParticipantName(peerId);

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
              color: const Color(0xFF13231A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSpotlighted
                    ? (isPinned ? AppColors.accent : AppColors.signalExcellent)
                    : (isSpeaking ? AppColors.signalExcellent : Colors.white12),
                width: isSpotlighted || isSpeaking ? 2.2 : 1.0,
              ),
              boxShadow: [
                if (isSpotlighted || isSpeaking)
                  BoxShadow(
                    color:
                        (isPinned
                                ? AppColors.accent
                                : AppColors.signalExcellent)
                            .withValues(alpha: 0.35),
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
                            ? [const Color(0xFF3A2E0B), const Color(0xFF13231A)]
                            : [
                                const Color(0xFF0F3D2A),
                                const Color(0xFF13231A),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isPinned
                                ? Icons.push_pin
                                : Icons.featured_video_rounded,
                            color: isPinned
                                ? AppColors.accent
                                : AppColors.signalExcellent,
                            size: 26,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPinned
                                ? l10n.text(fr: 'ÉPINGLÉ', en: 'PINNED')
                                : l10n.text(fr: 'À L’ÉCRAN', en: 'ON STAGE'),
                            style: TextStyle(
                              color: isPinned
                                  ? AppColors.accent
                                  : AppColors.signalExcellent,
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
                    child:
                        (isVideoOff ||
                            (isLocal
                                ? _callService.localRenderer.srcObject == null
                                : _callService
                                          .remoteRenderers[peerId]
                                          ?.srcObject ==
                                      null))
                        ? Container(
                            decoration: const BoxDecoration(
                              gradient: Palette.callGradient,
                            ),
                            child: Center(
                              child: Icon(
                                isVideoOff
                                    ? Icons.videocam_off
                                    : Icons.account_circle,
                                size: 30,
                                color: Colors.white38,
                              ),
                            ),
                          )
                        : RTCVideoView(
                            isLocal
                                ? _callService.localRenderer
                                : _callService.remoteRenderers[peerId]!,
                            key: ValueKey(
                              'thumb_${peerId}_${_callService.videoRefreshEpoch}',
                            ),
                            mirror: isLocal,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
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
                          ? AppColors.accent
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isMuted ? Icons.mic_off : Icons.mic,
                          size: 11,
                          color: isMuted
                              ? AppColors.callDecline
                              : AppColors.onlineGreen,
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
    final l10n = AppLocalizations.of(context);
    final remoteEntries = _callService.remoteRenderers.entries.toList();
    final totalParticipants = 1 + remoteEntries.length;

    return Container(
      decoration: const BoxDecoration(gradient: Palette.callGradient),
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
                    title: l10n.text(fr: 'Vous (local)', en: 'You (local)'),
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
              final isPeerReconnecting = _callService.isPeerReconnecting(
                peerId,
              );
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
    final l10n = AppLocalizations.of(context);
    final hasStream = renderer.srcObject != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13231A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSpeaking
              ? AppColors.signalExcellent
              : (isPinned
                    ? AppColors.accent
                    : (isLocal
                          ? AppColors.primary.withValues(alpha: 0.6)
                          : Colors.white24)),
          width: isSpeaking || isPinned ? 3.0 : 2.0,
        ),
        boxShadow: [
          if (isSpeaking)
            BoxShadow(
              color: AppColors.signalExcellent.withValues(alpha: 0.55),
              blurRadius: 18,
              spreadRadius: 2,
            )
          else if (isPinned)
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.4),
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
                    decoration: const BoxDecoration(
                      gradient: Palette.callGradient,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isVideoOff
                                ? Icons.videocam_off
                                : Icons.account_circle,
                            size: 48,
                            color: Colors.white38,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            !hasStream
                                ? l10n.connecting
                                : l10n.text(
                                    fr: 'Caméra désactivée',
                                    en: 'Camera off',
                                  ),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
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
          if (networkQuality != null &&
              networkQuality.isPoor &&
              !isReconnecting)
            Positioned(
              top: 10,
              left: 10,
              right: 50,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xE67F1D1D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF4444), width: 1),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 4),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        networkQuality.packetLossPercent > 0
                            ? l10n.text(
                                fr: 'Réseau faible • Perte : ${networkQuality.packetLossPercent}%',
                                en: 'Poor network • Loss: ${networkQuality.packetLossPercent}%',
                              )
                            : l10n.text(
                                fr: 'Réseau faible • Latence : ${networkQuality.rttMs.toStringAsFixed(0)} ms',
                                en: 'Poor network • Latency: ${networkQuality.rttMs.toStringAsFixed(0)} ms',
                              ),
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
                          color: AppColors.signalExcellent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xE60F3D2A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.signalExcellent,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          l10n.text(fr: 'Reconnexion…', en: 'Reconnecting…'),
                          style: const TextStyle(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isPinned
                        ? AppColors.accent
                        : Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isPinned ? AppColors.accent : Colors.white24,
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
                        isPinned
                            ? l10n.text(fr: 'Épinglé', en: 'Pinned')
                            : l10n.text(fr: 'Épingler', en: 'Pin'),
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
            right: onPinTap != null ? 70 : 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
              decoration: BoxDecoration(
                color: isSpeaking
                    ? const Color(0xE60F3D2A)
                    : Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSpeaking
                      ? AppColors.signalExcellent
                      : Colors.white24,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMuted ? Icons.mic_off : Icons.mic,
                    size: 13,
                    color: isMuted
                        ? AppColors.callDecline
                        : AppColors.onlineGreen,
                  ),
                  if (isSpeaking) ...[
                    const SizedBox(width: 4),
                    VoiceWaveIndicator(
                      isSpeaking: true,
                      audioLevel: audioLevel,
                      maxHeight: 11,
                      barWidth: 1.8,
                      barCount: 3,
                    ),
                  ],
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: isSpeaking
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
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
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final isRemoteSpeaking =
        _callService.activeSpeakerId != null &&
        _callService.activeSpeakerId != 'local';
    final remoteAudioLevel = isRemoteSpeaking
        ? _callService.getAudioLevel(_callService.activeSpeakerId!)
        : 0.0;
    final remotePeerId = _callService.remoteRenderers.keys.firstOrNull ?? '';
    final remoteQuality = _callService.getNetworkQuality(remotePeerId);

    final mainRenderer = _isPipSwapped
        ? _callService.localRenderer
        : _callService.remoteRenderer;
    final pipRenderer = _isPipSwapped
        ? _callService.remoteRenderer
        : _callService.localRenderer;
    final isMainLocal = _isPipSwapped;
    final isPipLocal = !_isPipSwapped;

    return Stack(
      children: [
        // Main Video Stream View (Full area)
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(gradient: Palette.callGradient),
            child: mainRenderer.srcObject != null
                ? RTCVideoView(
                    mainRenderer,
                    key: ValueKey(
                      'main_${mainRenderer.textureId}_${_callService.videoRefreshEpoch}',
                    ),
                    mirror: isMainLocal,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          l10n.text(
                            fr: 'En attente du flux vidéo distant…',
                            en: 'Waiting for peer video stream…',
                          ),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),

        // Reconnecting Notice Banner (Top Left)
        if (_callService.isAnyReconnecting)
          Positioned(
            top: isMobile ? 12 : 20,
            left: isMobile ? 12 : 20,
            right: isMobile ? 124 : 175,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xE63A2E0B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent, width: 1.2),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 8),
                ],
              ),
              child: Row(
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
                      l10n.text(
                        fr: 'Réseau instable • Reconnexion…',
                        en: 'Network unstable • Reconnecting…',
                      ),
                      style: const TextStyle(
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
            top: isMobile ? 12 : 20,
            left: isMobile ? 12 : 20,
            right: isMobile ? 124 : 175,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xE67F1D1D),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 8),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      remoteQuality.packetLossPercent > 0
                          ? l10n.text(
                              fr: 'Faible • ${remoteQuality.packetLossPercent}% de perte',
                              en: 'Poor • ${remoteQuality.packetLossPercent}% loss',
                            )
                          : l10n.text(
                              fr: 'Faible • ${remoteQuality.rttMs.toStringAsFixed(0)} ms',
                              en: 'Poor • ${remoteQuality.rttMs.toStringAsFixed(0)} ms',
                            ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SignalIndicator(
                    strength: remoteQuality.bars,
                    maxBars: 4,
                    barWidth: 2.2,
                    maxBarHeight: 10,
                    tooltip: remoteQuality.summaryText,
                  ),
                ],
              ),
            ),
          ),

        // Remote Active Speaker Floating Pill (Bottom Left)
        if (isRemoteSpeaking)
          Positioned(
            left: isMobile ? 12 : 20,
            bottom: isMobile ? 16 : 24,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: screenWidth - (isMobile ? 32 : 50),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xE60F3D2A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.signalExcellent,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.signalExcellent.withValues(alpha: 0.35),
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
                  Flexible(
                    child: Text(
                      l10n.text(
                        fr: '${widget.callTitle} parle',
                        en: '${widget.callTitle} is speaking',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Floating Video Preview (Picture-in-Picture) • Tap to Swap
        Positioned(
          right: isMobile ? 12 : 20,
          top: isMobile ? 12 : 20,
          width: isMobile ? 104 : 140,
          height: isMobile ? 146 : 190,
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
                  color:
                      (isPipLocal && _callService.isLocalSpeaking) ||
                          (!isPipLocal && isRemoteSpeaking)
                      ? AppColors.signalExcellent
                      : Colors.white38,
                  width:
                      (isPipLocal && _callService.isLocalSpeaking) ||
                          (!isPipLocal && isRemoteSpeaking)
                      ? 3
                      : 2,
                ),
                boxShadow: [
                  if ((isPipLocal && _callService.isLocalSpeaking) ||
                      (!isPipLocal && isRemoteSpeaking))
                    BoxShadow(
                      color: AppColors.signalExcellent.withValues(alpha: 0.55),
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
                            child: Icon(
                              Icons.videocam_off,
                              color: Colors.white54,
                              size: 36,
                            ),
                          )
                        : (pipRenderer.srcObject == null)
                        ? const Center(
                            child: Icon(
                              Icons.account_circle,
                              color: Colors.white38,
                              size: 36,
                            ),
                          )
                        : RTCVideoView(
                            pipRenderer,
                            key: ValueKey(
                              'pip_${pipRenderer.textureId}_${_callService.videoRefreshEpoch}',
                            ),
                            mirror: isPipLocal,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          ),
                  ),

                  // Bottom Tag
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE60F3D2A),
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
                          child: const Icon(
                            Icons.swap_horiz,
                            color: Colors.white70,
                            size: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 3,
                          ),
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
    final l10n = AppLocalizations.of(context);
    return CallControls(
      userName: l10n.text(fr: 'Vous', en: 'You'),
      userInitials: l10n.text(fr: 'MO', en: 'ME'),
      elapsed: '00:00',
      participantCount: widget.participantCount,
      controls: [
        CallControlItem(
          icon: _callService.isMicMuted ? Icons.mic_off : Icons.mic,
          label: _callService.isMicMuted ? l10n.unmute : l10n.mute,
          isActive: _callService.isMicMuted,
          onTap: () => _callService.toggleMic(),
        ),
        CallControlItem(
          icon: _callService.isVideoOff ? Icons.videocam_off : Icons.videocam,
          label: _callService.isVideoOff
              ? l10n.text(fr: 'Activer la vidéo', en: 'Start video')
              : l10n.text(fr: 'Désactiver la vidéo', en: 'Stop video'),
          isActive: _callService.isVideoOff,
          onTap: () => _callService.toggleCamera(),
        ),
        CallControlItem(
          icon: Icons.cameraswitch,
          label: l10n.flipCamera,
          onTap: () => _callService.switchCamera(),
        ),
        CallControlItem(
          icon: Icons.call_end,
          label: l10n.endCall,
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
