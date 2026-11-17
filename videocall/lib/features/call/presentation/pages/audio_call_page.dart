import 'package:flutter/material.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/meeting_link_service.dart';
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
    super.key,
    this.callTitle = 'Audio Call',
    required this.roomId,
    this.contactName = 'Peer',
    this.contactMatricule = '',
    this.userToken,
    this.participantCount = 2,
    this.isGroupCall = false,
    this.callService,
  });

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
    if (MediaQuery.sizeOf(context).width < 760) {
      return Theme(data: AppTheme.lightTheme(), child: _buildMobileAudioCall());
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
                          ? _buildHeroAudioArea()
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

  Widget _buildMobileAudioCall() {
    final l10n = AppLocalizations.of(context);
    final peers = ['local', ..._callService.remotePeerIds];
    final group = widget.isGroupCall;
    void invite() => MeetingLinkService.showShareModal(
      context,
      roomId: widget.roomId,
      isVideo: false,
      title: widget.callTitle,
    );
    Widget avatar(String name, double size, {bool speaking = false}) =>
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF27B576), Color(0xFF117A4D)],
            ),
            border: Border.all(
              color: speaking ? Colors.white : Colors.white38,
              width: speaking ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: speaking ? 0.25 : 0.08),
                spreadRadius: 8,
              ),
            ],
          ),
          child: Text(
            _deriveInitials(name),
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.32,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
    Widget action(
      IconData icon,
      String label,
      VoidCallback? onPressed, {
      bool active = false,
    }) => Tooltip(
      message: label,
      child: Material(
        color: active
            ? AppColors.primary
            : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Opacity(
            opacity: onPressed == null ? 0.42 : 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
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
    );
    return Scaffold(
      backgroundColor: const Color(0xFF4E8F72),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: Palette.callGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      if (!group) ...[
                        const SizedBox(height: 18),
                        Center(child: avatar(widget.contactName, 120)),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        group ? widget.callTitle : widget.contactName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _callService.formattedDuration,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        group
                            ? l10n.text(
                                fr: 'Appel vocal de groupe · ${peers.length}',
                                en: 'Group voice call · ${peers.length}',
                              )
                            : l10n.text(
                                fr: 'Appel vocal chiffré',
                                en: 'Encrypted voice call',
                              ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      if (group)
                        Padding(
                          padding: const EdgeInsets.only(top: 28),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 24,
                            children: peers.asMap().entries.map((entry) {
                              final local = entry.value == 'local';
                              final name = local
                                  ? l10n.text(fr: 'Vous', en: 'You')
                                  : l10n.text(
                                      fr: 'Membre ${entry.key}',
                                      en: 'Member ${entry.key}',
                                    );
                              final speaking = local
                                  ? _callService.isLocalSpeaking
                                  : _callService.isSpeaking(entry.value);
                              return SizedBox(
                                width: 80,
                                child: Column(
                                  children: [
                                    avatar(name, 64, speaking: speaking),
                                    const SizedBox(height: 10),
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (local && _callService.isMicMuted)
                                      const Icon(
                                        Icons.mic_off_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: VoiceWaveIndicator(
                              isSpeaking:
                                  _callService.isLocalSpeaking ||
                                  _callService.remotePeerIds.any(
                                    _callService.isSpeaking,
                                  ),
                              audioLevel: peers
                                  .map(_callService.getAudioLevel)
                                  .fold<double>(
                                    0,
                                    (level, next) =>
                                        next > level ? next : level,
                                  ),
                              maxHeight: 48,
                              barCount: 26,
                              barWidth: 4,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.15,
                  children: [
                    action(
                      _callService.isMicMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      _callService.isMicMuted ? l10n.unmute : l10n.mute,
                      _callService.toggleMic,
                      active: _callService.isMicMuted,
                    ),
                    action(
                      Icons.volume_up_rounded,
                      l10n.text(fr: 'Haut-parleur', en: 'Speaker'),
                      _callService.toggleSpeaker,
                      active: _callService.isSpeakerOn,
                    ),
                    action(
                      Icons.dialpad_rounded,
                      l10n.text(fr: 'Clavier', en: 'Keypad'),
                      null,
                    ),
                    action(
                      Icons.videocam_outlined,
                      l10n.text(fr: 'Vidéo', en: 'Video'),
                      null,
                    ),
                    action(
                      Icons.person_add_alt_1_outlined,
                      l10n.text(fr: 'Ajouter', en: 'Add'),
                      invite,
                    ),
                    action(
                      Icons.pause_rounded,
                      l10n.text(fr: 'Attente', en: 'Hold'),
                      null,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: FilledButton.icon(
                    onPressed: _hangUpAndExit,
                    icon: const Icon(Icons.call_end_rounded),
                    label: Text(l10n.endCall),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 20,
        vertical: isCompact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xE613241C),
        border: const Border(bottom: BorderSide(color: Color(0x1FFFFFFF))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            color: AppColors.textPrimary,
            tooltip: l10n.endCall,
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
                    color: Colors.white,
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
                      child: InkWell(
                        onTap: () => MeetingLinkService.showShareModal(
                          context,
                          roomId: widget.roomId,
                          isVideo: false,
                          title: widget.callTitle,
                          hostName: widget.contactName,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                l10n.text(
                                  fr: 'Salle : ${_formatRoomId(widget.roomId)} • Audio chiffré',
                                  en: 'Room: ${_formatRoomId(widget.roomId)} • Encrypted audio',
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF8DA69A),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.link_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 20),
            tooltip: l10n.text(
              fr: 'Partager le lien',
              en: 'Share meeting link',
            ),
            color: AppColors.primary,
            onPressed: () => MeetingLinkService.showShareModal(
              context,
              roomId: widget.roomId,
              isVideo: false,
              title: widget.callTitle,
              hostName: widget.contactName,
            ),
          ),
          const SizedBox(width: 4),
          SignalIndicator(
            strength: _callService.localNetworkQuality.bars,
            showLabel: !isCompact,
            tooltip: _callService.localNetworkQuality.summaryText,
          ),
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
    final l10n = AppLocalizations.of(context);
    final remotePeerIds = _callService.remotePeerIds;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xE613241C),
        border: const Border(right: BorderSide(color: Color(0x1FFFFFFF))),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.participants.toUpperCase()} (${1 + remotePeerIds.length})',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
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
            // Live remote participants
            ...remotePeerIds.asMap().entries.map((mapEntry) {
              final index = mapEntry.key;
              final peerId = mapEntry.value;
              final shortId = peerId.length > 6
                  ? peerId.substring(0, 6)
                  : peerId;
              final name = widget.isGroupCall
                  ? l10n.text(
                      fr: 'Membre ${index + 1} ($shortId)',
                      en: 'Member ${index + 1} ($shortId)',
                    )
                  : widget.contactName;
              final initials = widget.isGroupCall
                  ? 'M${index + 1}'
                  : _deriveInitials(widget.contactName);
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
      ),
    );
  }

  Widget _buildHeroAudioArea() {
    final remotePeerIds = _callService.remotePeerIds;
    // Group mode: show a tile grid of all participants
    if (widget.isGroupCall && remotePeerIds.isNotEmpty) {
      return _buildGroupAudioGrid();
    }
    // 1-on-1 mode: classic single hero avatar + ripple
    return _buildSingleHeroAudioArea();
  }

  Widget _buildGroupAudioGrid() {
    final l10n = AppLocalizations.of(context);
    final remotePeerIds = _callService.remotePeerIds;
    final allPeers = [
      (
        'local',
        l10n.text(fr: 'Vous', en: 'You'),
        l10n.text(fr: 'MO', en: 'ME'),
        AppColors.primary,
      ),
      ...remotePeerIds.asMap().entries.map((e) {
        final index = e.key;
        final peerId = e.value;
        final shortId = peerId.length > 6 ? peerId.substring(0, 6) : peerId;
        final avatarColors = [
          AppColors.primary,
          AppColors.accent,
          AppColors.error,
          AppColors.primaryLight,
          const Color(0xFF8DA69A),
        ];
        return (
          peerId,
          l10n.text(
            fr: 'Membre ${index + 1} ($shortId)',
            en: 'Member ${index + 1} ($shortId)',
          ),
          'M${index + 1}',
          avatarColors[index % avatarColors.length],
        );
      }),
    ];

    return Container(
      decoration: const BoxDecoration(gradient: Palette.callGradient),
      child: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: allPeers.length <= 2
              ? 2
              : allPeers.length <= 4
              ? 2
              : 3,
          childAspectRatio: 0.85,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: allPeers.length,
        itemBuilder: (context, index) {
          final (peerId, name, initials, avatarColor) = allPeers[index];
          final isLocal = peerId == 'local';
          final isMuted = isLocal ? _callService.isMicMuted : false;
          final isSpeaking = isLocal
              ? _callService.isLocalSpeaking
              : _callService.isSpeaking(peerId);
          final audioLevel = isLocal
              ? _callService.getAudioLevel('local')
              : _callService.getAudioLevel(peerId);
          final quality = isLocal
              ? _callService.localNetworkQuality
              : _callService.getNetworkQuality(peerId);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: const Color(0xCC13231A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSpeaking
                    ? AppColors.signalExcellent
                    : const Color(0x1FFFFFFF),
                width: isSpeaking ? 2.5 : 1.5,
              ),
              boxShadow: [
                if (isSpeaking)
                  BoxShadow(
                    color: AppColors.signalExcellent.withValues(alpha: 0.30),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Speaking ring + avatar
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSpeaking ? 76 : 66,
                      height: isSpeaking ? 76 : 66,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSpeaking
                            ? AppColors.signalExcellent.withValues(alpha: 0.18)
                            : Colors.transparent,
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: avatarColor,
                        boxShadow: [
                          BoxShadow(
                            color: avatarColor.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Color(0xFF13231A),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    // Mute badge
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: isMuted
                                ? AppColors.callDecline
                                : AppColors.onlineGreen,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          isMuted ? Icons.mic_off : Icons.mic,
                          size: 10,
                          color: isMuted
                              ? AppColors.callDecline
                              : AppColors.onlineGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Name
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Speaking badge or signal indicator
                if (isSpeaking)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      VoiceWaveIndicator(
                        isSpeaking: true,
                        audioLevel: audioLevel,
                        maxHeight: 10,
                        barWidth: 2,
                        barCount: 3,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.text(fr: 'Parle', en: 'Speaking'),
                        style: const TextStyle(
                          color: Color(0xFF3DDC97),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                else
                  SignalIndicator(
                    strength: quality.bars,
                    maxBars: 4,
                    barWidth: 2,
                    maxBarHeight: 9,
                    tooltip: quality.summaryText,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSingleHeroAudioArea() {
    final l10n = AppLocalizations.of(context);
    final initials = _deriveInitials(widget.contactName);
    final remotePeerId = _callService.remotePeerIds.firstOrNull ?? '';
    final remoteQuality = _callService.getNetworkQuality(remotePeerId);
    final isPeerSpeaking =
        _callService.activeSpeakerId != null &&
        _callService.activeSpeakerId != 'local';
    final peerAudioLevel = isPeerSpeaking
        ? _callService.getAudioLevel(_callService.activeSpeakerId!)
        : 0.0;
    final currentAudioLevel = isPeerSpeaking
        ? peerAudioLevel
        : (_callService.isLocalSpeaking
              ? _callService.getAudioLevel('local')
              : 0.0);

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
                          ? AppColors.signalExcellent
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
                                colors: [
                                  AppColors.primaryLight,
                                  AppColors.primaryDark,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.25,
                                  ),
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
                                  color: Colors.black.withValues(alpha: 0.12),
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
            // Reconnecting or speaking status badge
            if (_callService.isAnyReconnecting)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accent, width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFB45309),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      l10n.text(
                        fr: 'Reconnexion du flux audio…',
                        en: 'Reconnecting voice stream…',
                      ),
                      style: TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else if (remoteQuality.isPoor)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFEF4444),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: Color(0xFFDC2626),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      remoteQuality.packetLossPercent > 0
                          ? l10n.text(
                              fr: 'Réseau faible • ${remoteQuality.packetLossPercent}% de perte',
                              en: 'Poor network • ${remoteQuality.packetLossPercent}% loss',
                            )
                          : l10n.text(
                              fr: 'Réseau faible • Latence ${remoteQuality.rttMs.toStringAsFixed(0)} ms',
                              en: 'Poor network • Latency ${remoteQuality.rttMs.toStringAsFixed(0)} ms',
                            ),
                      style: const TextStyle(
                        color: Color(0xFF991B1B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SignalIndicator(
                      strength: remoteQuality.bars,
                      maxBars: 4,
                      barWidth: 2.2,
                      maxBarHeight: 10,
                      tooltip: remoteQuality.summaryText,
                    ),
                  ],
                ),
              )
            else if (isPeerSpeaking || _callService.isLocalSpeaking)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF133C2B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.signalExcellent,
                    width: 1.2,
                  ),
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
                          ? l10n.text(
                              fr: '${widget.contactName} parle',
                              en: '${widget.contactName} is speaking',
                            )
                          : l10n.text(
                              fr: 'Vous parlez',
                              en: 'You are speaking',
                            ),
                      style: const TextStyle(
                        color: Color(0xFF3DDC97),
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
                color: const Color(0xCC13231A),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x1FFFFFFF)),
              ),
              child: Text(
                _callService.formattedDuration,
                style: const TextStyle(
                  color: Color(0xFF3DDC97),
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
                color: const Color(0xCC13231A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: remoteQuality.isPoor
                      ? const Color(0xFFFCA5A5)
                      : const Color(0x1FFFFFFF),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: remoteQuality.isPoor
                          ? const Color(0xFFEF4444)
                          : AppColors.onlineGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      remoteQuality.isPoor
                          ? l10n.text(
                              fr: 'Réseau faible • Latence ${remoteQuality.rttMs.toStringAsFixed(0)} ms',
                              en: 'Poor network • Latency ${remoteQuality.rttMs.toStringAsFixed(0)} ms',
                            )
                          : l10n.text(
                              fr: 'Connecté • Voix HD (Opus 48 kHz)',
                              en: 'Connected • HD voice (Opus 48 kHz)',
                            ),
                      style: TextStyle(
                        color: remoteQuality.isPoor
                            ? const Color(0xFFDC2626)
                            : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SignalIndicator(
                    strength: remoteQuality.bars,
                    maxBars: 4,
                    barWidth: 2.2,
                    maxBarHeight: 11,
                    tooltip: remoteQuality.summaryText,
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
    final l10n = AppLocalizations.of(context);
    return CallControls(
      userName: l10n.text(fr: 'Vous', en: 'You'),
      userInitials: l10n.text(fr: 'MO', en: 'ME'),
      elapsed: _callService.formattedDuration,
      participantCount: widget.participantCount,
      controls: [
        CallControlItem(
          icon: _callService.isMicMuted ? Icons.mic_off : Icons.mic,
          label: _callService.isMicMuted ? l10n.unmute : l10n.mute,
          isActive: _callService.isMicMuted,
          onTap: () => _callService.toggleMic(),
        ),
        CallControlItem(
          icon: _callService.isSpeakerOn
              ? Icons.volume_up_rounded
              : Icons.volume_down_rounded,
          label: _callService.isSpeakerOn
              ? l10n.text(fr: 'Haut-parleur activé', en: 'Speaker on')
              : l10n.text(fr: 'Haut-parleur désactivé', en: 'Speaker off'),
          isActive: _callService.isSpeakerOn,
          onTap: () => _callService.toggleSpeaker(),
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

  static String _deriveInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
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
      final rawOpacity = (1.0 - ringProgress) * boost;
      final opacity = rawOpacity.isNaN ? 0.0 : rawOpacity.clamp(0.0, 1.0);

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = audioLevel > 0.04 ? 2.5 : 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AudioRipplePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.audioLevel != audioLevel;
}
