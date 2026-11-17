import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/signaling_service.dart';
import '../../../../core/services/webrtc_call_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import 'audio_call_page.dart';
import 'call_page.dart';

/// Connecting screen shown while initiating and establishing a WebRTC call.
/// Features a spinning ring around camera/phone icon, status text,
/// encryption badge, and a cancel button.
///
/// Only transitions to [CallPage] or [AudioCallPage] after the callee picks up!
class ConnectingPage extends StatefulWidget {
  final String callTitle;
  final String roomId;
  final String? userToken;
  final String recipientUserId;
  final String recipientName;
  final String recipientMatricule;
  final bool isVideoCall;
  final int participantCount;
  final bool isGroupCall;
  final List<String> recipientUserIds;
  final List<String> recipientNames;
  final VoidCallback? onCancel;

  const ConnectingPage({
    super.key,
    this.callTitle = 'Call',
    this.roomId = '',
    this.userToken,
    this.recipientUserId = '',
    this.recipientName = '',
    this.recipientMatricule = '',
    this.isVideoCall = true,
    this.participantCount = 2,
    this.isGroupCall = false,
    this.recipientUserIds = const [],
    this.recipientNames = const [],
    this.onCancel,
  });

  @override
  State<ConnectingPage> createState() => _ConnectingPageState();
}

class _ConnectingPageState extends State<ConnectingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;
  late final WebRTCCallService _callService;
  bool _hasNavigatedToCall = false;
  String _statusTitle = 'Connecting...';
  String _statusSubtitle = 'Establishing secure connection';
  bool _isTerminating = false;

  @override
  void initState() {
    super.initState();
    if (widget.isGroupCall) {
      _statusTitle = 'Starting Group Call...';
      _statusSubtitle = widget.recipientNames.isNotEmpty
          ? 'Ringing ${widget.recipientNames.length} participants...'
          : 'Inviting members...';
    }
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _callService = WebRTCCallService();
    _callService.addListener(_onCallServiceStateChanged);

    _initializeCallAndInvite();
  }

  Future<void> _initializeCallAndInvite() async {
    if (widget.roomId.isEmpty) {
      debugPrint('[ConnectingPage] No roomId provided, idling in preview mode');
      return;
    }
    String? token = widget.userToken;
    token ??= await AuthService.getToken();

    if (token != null && token.isNotEmpty) {
      await _callService.initializeSocket(token);
    } else {
      debugPrint('[ConnectingPage] No auth token found');
    }

    await _callService.joinCallRoom(
      widget.roomId,
      isVideoCall: widget.isVideoCall,
      isGroupCall: widget.isGroupCall,
    );

    // Send call invite to callee
    if (mounted) {
      final authCtrl = context.read<AuthController>();
      final user = authCtrl.currentUser;
      final myName = user != null
          ? (user['display_name'] ??
                user['displayName'] ??
                ((user['first_name'] != null || user['last_name'] != null)
                    ? '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
                          .trim()
                    : user['username'] ?? user['matricule'] ?? 'User'))
          : 'User';
      final myMatricule = user?['matricule']?.toString() ?? '';

      // Reset any previous signaling flags before sending
      final signaling = context.read<SignalingService>();
      signaling.resetCallStatus();

      // Brief delay to give socket time to register in room
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted || _hasNavigatedToCall || _isTerminating) return;
        if (widget.isGroupCall && widget.recipientUserIds.isNotEmpty) {
          signaling.sendGroupCallInvites(
            calleeUserIds: widget.recipientUserIds,
            roomId: widget.roomId,
            isVideoCall: widget.isVideoCall,
            groupTitle: widget.callTitle,
            callerName: myName,
            callerMatricule: myMatricule,
          );
        } else {
          signaling.sendCallInvite(
            calleeUserId: widget.recipientUserId,
            roomId: widget.roomId,
            isVideoCall: widget.isVideoCall,
            callerName: myName,
            callerMatricule: myMatricule,
          );
        }
      });
    }
  }

  void _onCallServiceStateChanged() {
    if (!mounted || _hasNavigatedToCall || _isTerminating) return;

    // Callee has picked up and entered the room!
    if (_callService.callState == CallState.connected) {
      _hasNavigatedToCall = true;
      _navigateToCallPage();
    } else if (_callService.callState == CallState.ended) {
      _cancelAndExit();
    }
  }

  void _navigateToCallPage() {
    if (!mounted) return;

    if (widget.isVideoCall) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CallPage(
            callTitle: widget.callTitle,
            roomId: widget.roomId,
            participantCount: widget.participantCount,
            isVideoCall: true,
            callService: _callService,
            isGroupCall: widget.isGroupCall,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AudioCallPage(
            callTitle: widget.callTitle,
            roomId: widget.roomId,
            contactName: widget.isGroupCall
                ? widget.callTitle
                : widget.recipientName,
            contactMatricule: widget.isGroupCall
                ? '${widget.participantCount} members'
                : widget.recipientMatricule,
            participantCount: widget.participantCount,
            callService: _callService,
            isGroupCall: widget.isGroupCall,
          ),
        ),
      );
    }
  }

  Future<void> _cancelAndExit() async {
    if (_isTerminating || _hasNavigatedToCall) return;
    _isTerminating = true;

    await _callService.endCall();

    if (mounted) {
      if (widget.onCancel != null) {
        widget.onCancel!();
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacementNamed('/calls');
      }
    }
  }

  String _localizedStatusTitle(AppLocalizations l10n) => switch (_statusTitle) {
    'Connecting...' => l10n.connecting,
    'Starting Group Call...' => l10n.text(
      fr: 'Démarrage de l’appel de groupe…',
      en: 'Starting group call…',
    ),
    'User Offline' => l10n.text(
      fr: 'Utilisateur hors ligne',
      en: 'User offline',
    ),
    'Call Declined' => l10n.text(fr: 'Appel refusé', en: 'Call declined'),
    _ => _statusTitle,
  };

  String _localizedStatusSubtitle(AppLocalizations l10n) {
    if (_statusTitle == 'Connecting...') {
      return l10n.text(
        fr: 'Établissement d’une connexion sécurisée',
        en: 'Establishing a secure connection',
      );
    }
    if (_statusTitle == 'Starting Group Call...') {
      if (widget.recipientNames.isEmpty) {
        return l10n.text(
          fr: 'Invitation des participants…',
          en: 'Inviting participants…',
        );
      }
      return l10n.text(
        fr: 'Appel de ${widget.recipientNames.length} participants…',
        en: 'Calling ${widget.recipientNames.length} participants…',
      );
    }
    if (_statusTitle == 'User Offline') {
      return l10n.text(
        fr: '${widget.recipientName} est actuellement indisponible',
        en: '${widget.recipientName} is currently unavailable',
      );
    }
    if (_statusTitle == 'Call Declined') {
      return l10n.text(
        fr: '${widget.recipientName} ne peut pas répondre',
        en: '${widget.recipientName} is unable to answer',
      );
    }
    return _statusSubtitle.isNotEmpty
        ? _statusSubtitle
        : l10n.text(
            fr: 'Appel de ${widget.recipientName}…',
            en: 'Calling ${widget.recipientName}…',
          );
  }

  @override
  void dispose() {
    _spinController.dispose();
    _callService.removeListener(_onCallServiceStateChanged);
    // Only dispose _callService if we did NOT transfer it to CallPage / AudioCallPage
    if (!_hasNavigatedToCall) {
      _callService.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Watch SignalingService for callee responses (declined or offline)
    final signaling = context.watch<SignalingService>();

    if (!_hasNavigatedToCall && !_isTerminating) {
      if (signaling.calleeOffline) {
        _statusTitle = 'User Offline';
        _statusSubtitle = '${widget.recipientName} is currently unavailable';
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) _cancelAndExit();
        });
      } else if (signaling.callDeclined) {
        _statusTitle = 'Call Declined';
        _statusSubtitle = '${widget.recipientName} is unable to answer';
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) _cancelAndExit();
        });
      }
    }

    return Theme(
      data: AppTheme.lightTheme(),
      child: Scaffold(
        backgroundColor: const Color(0xFF4E8F72),
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: Palette.callGradient),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Spinner + camera or phone icon
                _buildSpinner(),
                const SizedBox(height: 28),
                // Connecting text
                Text(
                  _localizedStatusTitle(l10n),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                // Subtitle
                Text(
                  _localizedStatusSubtitle(l10n),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                // Status badge
                _buildStatusBadge(l10n),
                const SizedBox(height: 28),
                // Enter room button for group calls
                if (widget.isGroupCall) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      _hasNavigatedToCall = true;
                      _navigateToCallPage();
                    },
                    icon: const Icon(Icons.meeting_room_rounded, size: 16),
                    label: Text(
                      l10n.text(
                        fr: 'Entrer dans la salle',
                        en: 'Enter meeting room',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Cancel button
                TextButton(
                  onPressed: _cancelAndExit,
                  child: Text(
                    l10n.cancel,
                    style: TextStyle(
                      color: AppColors.callDecline,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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

  Widget _buildSpinner() {
    return SizedBox(
      width: 80,
      height: 80,
      child: AnimatedBuilder(
        animation: _spinController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Spinning arc
              Transform.rotate(
                angle: _spinController.value * math.pi * 2,
                child: CustomPaint(
                  size: const Size(80, 80),
                  painter: _SpinnerPainter(
                    color: const Color(0xFF3DDC97),
                    strokeWidth: 3,
                  ),
                ),
              ),
              // Icon circle: videocam for video call, phone for audio call
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3DDC97).withValues(alpha: 0.16),
                ),
                child: Icon(
                  widget.isGroupCall
                      ? Icons.groups_rounded
                      : (widget.isVideoCall
                            ? Icons.videocam_rounded
                            : Icons.phone_rounded),
                  size: 24,
                  color: const Color(0xFF3DDC97),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF3DDC97),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            widget.isVideoCall
                ? l10n.text(
                    fr: 'Chiffrement du flux vidéo…',
                    en: 'Encrypting video stream…',
                  )
                : l10n.text(
                    fr: 'Chiffrement du flux audio…',
                    en: 'Encrypting voice stream…',
                  ),
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the spinning arc around the call icon.
class _SpinnerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _SpinnerPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw partial arc (~270 degrees)
    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter old) =>
      color != old.color || strokeWidth != old.strokeWidth;
}
