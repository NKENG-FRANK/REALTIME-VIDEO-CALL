import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../config/api_config.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

/// Payload delivered to the callee when an incoming call arrives.
class IncomingCallData {
  final String roomId;
  final String callerUserId;
  final String callerName;
  final String callerMatricule;
  final bool isVideoCall;

  const IncomingCallData({
    required this.roomId,
    required this.callerUserId,
    required this.callerName,
    required this.callerMatricule,
    required this.isVideoCall,
  });
}

// ─── Service ─────────────────────────────────────────────────────────────────

/// Persistent socket service started right after the user logs in.
///
/// Responsibilities:
/// - Maintain a live connection to the video-calls Socket.io server.
/// - Listen for `call:incoming` and expose it via [incomingCall] so the UI
///   can show [IncomingCallPage] anywhere in the app.
/// - Allow the caller to emit `call:invite` before joining the room.
/// - Allow the callee to emit `call:decline`.
class SignalingService extends ChangeNotifier {
  IO.Socket? _socket;
  bool _disposed = false;

  IncomingCallData? _incomingCall;
  bool _calleeOffline = false;

  // ── Public state ─────────────────────────────────────────────────────────

  /// Non-null when this device has an unhandled incoming call.
  IncomingCallData? get incomingCall => _incomingCall;

  /// True when a `call:invite` was sent but the callee is not connected.
  bool get calleeOffline => _calleeOffline;

  bool get isConnected => _socket?.connected == true;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Call this once after a successful login / auth-check, passing the JWT.
  Future<void> connect(String userToken) async {
    // Avoid duplicate connections for the same user
    if (_socket != null && _socket!.connected) {
      debugPrint('[Signaling] Already connected, skipping.');
      return;
    }

    _socket = IO.io(
      ApiConfig.videoCallsBaseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': userToken})
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[Signaling] Connected to video-calls socket');
      _safe(notifyListeners);
    });

    _socket!.onDisconnect((_) {
      debugPrint('[Signaling] Disconnected from video-calls socket');
      _safe(notifyListeners);
    });

    // ── Incoming call from another user ─────────────────────────────────
    _socket!.on('call:incoming', (data) {
      debugPrint('[Signaling] call:incoming → $data');
      final map = data as Map<String, dynamic>;
      _incomingCall = IncomingCallData(
        roomId: map['roomId'] as String,
        callerUserId: map['callerUserId'] as String,
        callerName: map['callerName'] as String? ?? 'Unknown',
        callerMatricule: map['callerMatricule'] as String? ?? '',
        isVideoCall: (map['callType'] as String?) == 'DIRECT_VIDEO',
      );
      _safe(notifyListeners);
    });

    // ── Callee is offline ────────────────────────────────────────────────
    _socket!.on('call:callee_offline', (data) {
      debugPrint('[Signaling] Callee offline: $data');
      _calleeOffline = true;
      _safe(notifyListeners);
      // Auto-clear the flag after 3 s so callers can retry
      Future.delayed(const Duration(seconds: 3), () {
        if (!_disposed) {
          _calleeOffline = false;
          _safe(notifyListeners);
        }
      });
    });

    // ── Caller was declined ──────────────────────────────────────────────
    _socket!.on('call:declined', (data) {
      debugPrint('[Signaling] Call declined: $data');
      _safe(notifyListeners);
    });

    _socket!.on('error', (data) {
      debugPrint('[Signaling] Socket error: $data');
    });

    _socket!.connect();
  }

  /// Disconnect and release the socket (e.g. on logout).
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _incomingCall = null;
    _calleeOffline = false;
    if (!_disposed) notifyListeners();
  }

  // ── Caller API ────────────────────────────────────────────────────────────

  /// Emit `call:invite` to the backend so the callee is notified.
  /// Call this BEFORE navigating to [CallPage].
  void sendCallInvite({
    required String calleeUserId,
    required String roomId,
    required bool isVideoCall,
    required String callerName,
    required String callerMatricule,
  }) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('[Signaling] Cannot send invite: socket not connected');
      return;
    }
    _socket!.emit('call:invite', {
      'calleeUserId': calleeUserId,
      'roomId': roomId,
      'callType': isVideoCall ? 'DIRECT_VIDEO' : 'DIRECT_AUDIO',
      'callerName': callerName,
      'callerMatricule': callerMatricule,
    });
  }

  // ── Callee API ────────────────────────────────────────────────────────────

  /// Emit `call:decline` so the caller knows the call was rejected.
  void declineCall(String callerUserId, String roomId) {
    _socket?.emit('call:decline', {
      'callerUserId': callerUserId,
      'roomId': roomId,
    });
    clearIncomingCall();
  }

  /// Clear the pending incoming call (after accept or dismiss).
  void clearIncomingCall() {
    _incomingCall = null;
    if (!_disposed) notifyListeners();
  }

  // ── Internal helpers ─────────────────────────────────────────────────────

  /// Run [fn] only if this service has not been disposed.
  void _safe(VoidCallback fn) {
    if (!_disposed) fn();
  }

  @override
  void dispose() {
    _disposed = true;
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}
