import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../config/api_config.dart';
import 'auth_service.dart';

enum CallState { idle, connecting, connected, ended }

/// Real-time WebRTC network quality metrics & MOS score for a peer.
class NetworkQuality {
  final double rttMs;
  final double jitterMs;
  final double packetLossPercent;
  final double mos; // 1.0 to 4.5
  final int bars; // 1 to 4
  final String label; // 'Excellent', 'Good', 'Fair', 'Poor'
  final bool isPoor; // true when packetLossPercent >= 5.0% or bars == 1

  const NetworkQuality({
    this.rttMs = 0.0,
    this.jitterMs = 0.0,
    this.packetLossPercent = 0.0,
    this.mos = 4.5,
    this.bars = 4,
    this.label = 'Excellent',
    this.isPoor = false,
  });

  static const NetworkQuality goodDefault = NetworkQuality();

  String get summaryText =>
      '$bars/4 bars • RTT: ${rttMs.toStringAsFixed(0)}ms • Loss: ${packetLossPercent.toStringAsFixed(1)}% • MOS: ${mos.toStringAsFixed(1)}';
}

class WebRTCCallService extends ChangeNotifier {
  io.Socket? _socket;
  MediaStream? _localStream;
  bool _isGroupCall = false;

  // ── Per-peer WebRTC state ─────────────────────────────────────────────────
  // Keyed by peerId (socketId or userId from the server).
  // For 1-on-1 calls there will be exactly one entry.
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, List<RTCIceCandidate>> _pendingCandidates = {};
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, bool> _makingOffer = {};

  // ── Renderers (public) ────────────────────────────────────────────────────
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> remoteRenderers = {};

  bool _disposed = false;
  bool _isFirstPeer = false;

  CallState _callState = CallState.idle;
  CallState get callState => _callState;

  String? _currentRoomId;
  String? _currentUserId;
  DateTime? _callStartTime;

  bool _isVideoCall = true;
  bool get isVideoCall => _isVideoCall;

  bool _isMicMuted = false;
  bool get isMicMuted => _isMicMuted;

  bool _isVideoOff = false;
  bool get isVideoOff => _isVideoOff;

  bool _isSpeakerOn = false;
  bool get isSpeakerOn => _isSpeakerOn;

  // ── Active Speaker & Audio Level Detection ────────────────────────────────
  Timer? _speakerStatsTimer;
  final Map<String, double> _audioLevels = {};
  String? _activeSpeakerId;
  DateTime? _lastSpeechTime;

  String? get activeSpeakerId => _activeSpeakerId;
  Map<String, double> get audioLevels => Map.unmodifiable(_audioLevels);
  double getAudioLevel(String id) => _audioLevels[id] ?? 0.0;
  bool isSpeaking(String id) => (_audioLevels[id] ?? 0.0) > 0.04;
  bool get isLocalSpeaking => isSpeaking('local');

  // ── Real-Time Network Quality & Signal Strength Monitoring ───────────────
  final Map<String, NetworkQuality> _networkQualities = {};
  final Map<String, int> _prevPacketsLost = {};
  final Map<String, int> _prevPacketsReceived = {};
  int _networkQualityTick = 0;

  NetworkQuality getNetworkQuality(String peerId) =>
      _networkQualities[peerId] ?? NetworkQuality.goodDefault;

  NetworkQuality get localNetworkQuality =>
      _networkQualities['local'] ?? NetworkQuality.goodDefault;

  bool get isAnyPeerNetworkPoor =>
      _networkQualities.values.any((q) => q.isPoor);

  // ── Network Resilience & ICE Watchdog ─────────────────────────────────────
  final Map<String, Timer> _iceDisconnectTimers = {};
  final Map<String, int> _iceRestartAttempts = {};
  final Set<String> _reconnectingPeers = {};
  int _videoRefreshEpoch = 0;
  int get videoRefreshEpoch => _videoRefreshEpoch;

  bool isPeerReconnecting(String peerId) => _reconnectingPeers.contains(peerId);
  bool get isAnyReconnecting => _reconnectingPeers.isNotEmpty;
  Set<String> get reconnectingPeers => Set.unmodifiable(_reconnectingPeers);

  String get formattedDuration {
    if (_callStartTime == null) return '00:05';
    final duration = DateTime.now().difference(_callStartTime!);
    final minutes =
        duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
    'sdpSemantics': 'unified-plan',
    'iceCandidatePoolSize': 10,
  };

  late final Future<void> _initRenderersFuture = _initRenderers();

  WebRTCCallService() {
    _initRenderersFuture;
  }

  void _safeNotify() {
    if (!_disposed) Future.microtask(notifyListeners);
  }

  Future<void> _initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  // ── ICE candidate buffering (per-peer) ───────────────────────────────────

  Future<void> _drainPendingCandidates(String peerId) async {
    final pc = _peerConnections[peerId];
    if (pc == null) return;
    final candidates =
        List<RTCIceCandidate>.from(_pendingCandidates[peerId] ?? []);
    _pendingCandidates[peerId]?.clear();
    debugPrint(
      '[WebRTC] Draining ${candidates.length} pending ICE candidate(s) for peer $peerId',
    );
    for (final candidate in candidates) {
      try {
        await pc.addCandidate(candidate);
      } catch (e) {
        debugPrint('[WebRTC] Error adding pending ICE candidate: $e');
      }
    }
  }

  // ── Resolve a peer ID from a Socket.io event payload ─────────────────────

  String _peerIdFromData(Map<String, dynamic> map, {String? fallback}) {
    return (map['senderUserId'] as String?) ??
        (map['from'] as String?) ??
        (map['socketId'] as String?) ??
        (map['userId'] as String?) ??
        fallback ??
        'peer_${_peerConnections.length}';
  }

  // ── Socket initialization ─────────────────────────────────────────────────

  Future<void> initializeSocket(String userToken) async {
    final userMap = await AuthService.getCurrentUser();
    if (userMap != null) {
      _currentUserId = (userMap['id'] as String?) ?? (userMap['userId'] as String?);
    }

    if (_socket != null && _socket!.connected) return;

    if (_socket != null) {
      _socket!.dispose();
      _socket = null;
    }

    _socket = io.io(
      ApiConfig.videoCallsBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': userToken})
          .enableForceNew()
          .disableAutoConnect()
          .setReconnectionAttempts(15)
          .setReconnectionDelay(1000)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[WebRTC] Connected to Video Calls Socket.io server');
      if (_currentRoomId != null && _callState == CallState.connected) {
        debugPrint(
          '[WebRTC] Socket reconnected during active call - rejoining room $_currentRoomId',
        );
        final callType = _isGroupCall
            ? (_isVideoCall ? 'GROUP_VIDEO' : 'GROUP_AUDIO')
            : (_isVideoCall ? 'DIRECT_VIDEO' : 'DIRECT_AUDIO');
        _socket!.emit('room:join', {'roomId': _currentRoomId, 'callType': callType});
        for (final peerId in _peerConnections.keys) {
          _restartIceForPeer(peerId);
        }
      }
    });

    _socket!.onDisconnect((reason) {
      debugPrint('[WebRTC] Disconnected from Video Calls Socket.io server: $reason');
      if (_callState == CallState.connected) {
        _reconnectingPeers.addAll(_peerConnections.keys);
        _safeNotify();
      }
    });

    _socket!.on('connect_error', (err) {
      debugPrint('[WebRTC] Connection error: $err');
    });

    // ── room:joined ────────────────────────────────────────────────────────
    _socket!.on('room:joined', (data) async {
      debugPrint('[WebRTC] Joined room: $data');
      final map = data as Map<String, dynamic>?;
      final existingParticipants = map?['participants'] as List?;

      if (existingParticipants != null && existingParticipants.isNotEmpty) {
        // We are a late joiner – existing participant(s) will send us offers.
        _isFirstPeer = false;
        _callState = CallState.connected;
        _callStartTime = DateTime.now();
      } else {
        // We are first in the room – wait for others to join.
        _isFirstPeer = true;
        _callState = CallState.connecting;
      }
      _safeNotify();
    });

    // ── room:participant_joined ────────────────────────────────────────────
    _socket!.on('room:participant_joined', (data) async {
      debugPrint('[WebRTC] Participant joined: $data');
      final map =
          data is Map ? data as Map<String, dynamic> : <String, dynamic>{};
      final peerId = _peerIdFromData(
        map,
        fallback: 'peer_${_peerConnections.length}',
      );

      // If we already have a peer connection for this peer (e.g. they reconnected
      // after a network drop), clear the reconnecting banner and do an ICE restart
      // on the EXISTING connection — do NOT create a duplicate peer connection.
      if (_peerConnections.containsKey(peerId)) {
        debugPrint(
          '[WebRTC] Peer $peerId re-joined — existing connection found. '
          'Clearing reconnecting state & triggering ICE restart.',
        );
        // Cancel any pending disconnect timer since the peer is back
        _iceDisconnectTimers[peerId]?.cancel();
        _iceDisconnectTimers.remove(peerId);
        _iceRestartAttempts[peerId] = 0;
        _reconnectingPeers.remove(peerId);
        _safeNotify();
        // Restart ICE to pick up fresh candidates from the reconnected peer
        if (_isFirstPeer || _peerConnections.length == 1) {
          await _restartIceForPeer(peerId);
        }
        return;
      }

      _callState = CallState.connected;
      _callStartTime = DateTime.now();
      _safeNotify();

      // Fresh peer: create a dedicated offer for this specific peer.
      if (_isFirstPeer || _peerConnections.isEmpty || _isGroupCall) {
        await _createOffer(peerId);
      }
    });


    // ── webrtc:offer ──────────────────────────────────────────────────────
    _socket!.on('webrtc:offer', (data) async {
      final map = data as Map<String, dynamic>;
      final targetUserId = map['targetUserId'] as String?;
      if (targetUserId != null && _currentUserId != null && targetUserId != _currentUserId) {
        debugPrint('[WebRTC] Ignoring offer targeted to $targetUserId (my id: $_currentUserId)');
        return;
      }
      debugPrint('[WebRTC] Received WebRTC offer');
      final sdpMap = map['sdp'] as Map<String, dynamic>;
      final isIceRestart = map['isIceRestart'] == true;
      final peerId = _peerIdFromData(
        map,
        fallback: 'peer_${_peerConnections.length}',
      );
      await _handleOffer(sdpMap, peerId, isIceRestart: isIceRestart);
    });

    // ── webrtc:answer ─────────────────────────────────────────────────────
    _socket!.on('webrtc:answer', (data) async {
      final map = data as Map<String, dynamic>;
      final targetUserId = map['targetUserId'] as String?;
      if (targetUserId != null && _currentUserId != null && targetUserId != _currentUserId) {
        debugPrint('[WebRTC] Ignoring answer targeted to $targetUserId (my id: $_currentUserId)');
        return;
      }
      debugPrint('[WebRTC] Received WebRTC answer');
      final sdpMap = map['sdp'] as Map<String, dynamic>;
      final peerId = _peerIdFromData(
        map,
        fallback: _peerConnections.keys.firstOrNull ?? 'peer_0',
      );

      final pc = _peerConnections[peerId];
      if (pc == null) {
        debugPrint('[WebRTC] No peer connection found for peerId: $peerId, connections: ${_peerConnections.keys}');
        final fallbackPc = _peerConnections.values.firstOrNull;
        if (fallbackPc != null) {
          final description =
              RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);
          await fallbackPc.setRemoteDescription(description);
          final fallbackKey = _peerConnections.keys.first;
          await _drainPendingCandidates(fallbackKey);
          await _rebindAndRestoreVideo(fallbackKey);
          _updateAdaptiveBitrates();
        }
        return;
      }
      final description =
          RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);
      await pc.setRemoteDescription(description);
      await _drainPendingCandidates(peerId);
      await _rebindAndRestoreVideo(peerId);
      _updateAdaptiveBitrates();
    });

    // ── webrtc:candidate ──────────────────────────────────────────────────
    _socket!.on('webrtc:candidate', (data) async {
      final map = data as Map<String, dynamic>;
      final targetUserId = map['targetUserId'] as String?;
      if (targetUserId != null && _currentUserId != null && targetUserId != _currentUserId) {
        return;
      }
      debugPrint('[WebRTC] <<< Remote ICE candidate arrived');
      final candidateMap = map['candidate'] as Map<String, dynamic>?;
      if (candidateMap == null) return;

      final peerId = _peerIdFromData(
        map,
        fallback: _peerConnections.keys.firstOrNull ?? 'peer_0',
      );

      final candidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );

      final pc = _peerConnections[peerId];
      if (pc != null) {
        final remoteDesc = await pc.getRemoteDescription();
        if (remoteDesc != null) {
          try {
            await pc.addCandidate(candidate);
            debugPrint('[WebRTC] Added ICE candidate for peer $peerId');
            return;
          } catch (e) {
            debugPrint('[WebRTC] Error adding candidate: $e');
          }
        }
      }
      // Buffer until remote description is set.
      debugPrint('[WebRTC] Buffering ICE candidate for peer $peerId');
      _pendingCandidates.putIfAbsent(peerId, () => []).add(candidate);
    });

    // ── webrtc:request_keyframe ───────────────────────────────────────────
    _socket!.on('webrtc:request_keyframe', (data) async {
      final map = data as Map<String, dynamic>;
      final targetUserId = map['targetUserId'] as String?;
      if (targetUserId != null && _currentUserId != null && targetUserId != _currentUserId) {
        return;
      }
      final peerId = _peerIdFromData(
        map,
        fallback: _peerConnections.keys.firstOrNull ?? '',
      );
      debugPrint('[WebRTC] Keyframe request received from $peerId — kickstart sender + recreate renderer');
      // Kickstart our outgoing encoder (IDR keyframe to remote).
      await _kickstartVideoSender(peerId);
      // Also recreate our local renderer for the remote stream to unfreeze display.
      // Skip echo-back (no outbound request_keyframe emit) to avoid infinite loop.
      final stream = _remoteStreams[peerId];
      if (stream != null) {
        for (final track in stream.getVideoTracks()) {
          track.enabled = true;
        }
        final freshPeerRenderer = await _recreateRenderer(
          old: remoteRenderers[peerId],
          stream: stream,
        );
        remoteRenderers[peerId] = freshPeerRenderer;
        if (_isVideoCall && (_remoteStreams.length == 1 || remoteRenderer.srcObject != null)) {
          await _recreateRenderer(
            old: remoteRenderer,
            stream: stream,
            reuse: remoteRenderer,
          );
        }
      }
      _videoRefreshEpoch++;
      _safeNotify();
    });

    // ── call:ended ────────────────────────────────────────────────────────
    _socket!.on('call:ended', (data) {
      String? eventRoomId;
      String? endedBy;
      if (data is Map) {
        eventRoomId = data['roomId'] as String?;
        endedBy = (data['endedBy'] as String?) ?? (data['userId'] as String?);
      } else if (data is List && data.isNotEmpty && data.first is Map) {
        eventRoomId = data.first['roomId'] as String?;
        endedBy = (data.first['endedBy'] as String?) ?? (data.first['userId'] as String?);
      }
      if (eventRoomId != null && eventRoomId != _currentRoomId) {
        debugPrint(
          '[WebRTC] Ignoring stale call:ended for room $eventRoomId (current: $_currentRoomId)',
        );
        return;
      }
      debugPrint('[WebRTC] Received call:ended payload: $data');

      if (_isGroupCall) {
        // In group calls, single participant exit does NOT terminate call for everyone.
        if (endedBy != null) {
          debugPrint('[WebRTC] Group call: Participant $endedBy left, removing peer connection...');
          _removePeerConnection(endedBy);
        }
        if (_peerConnections.isEmpty) {
          endCall();
        }
        return;
      }
      endCall();
    });

    // ── room:participant_left ─────────────────────────────────────────────
    _socket!.on('room:participant_left', (data) {
      String? eventRoomId;
      if (data is Map) {
        eventRoomId = data['roomId'] as String?;
      } else if (data is List && data.isNotEmpty && data.first is Map) {
        eventRoomId = data.first['roomId'] as String?;
      }
      if (eventRoomId != null && eventRoomId != _currentRoomId) {
        debugPrint('[WebRTC] Ignoring stale room:participant_left');
        return;
      }
      debugPrint('[WebRTC] Participant left: $data');

      final map = data is Map ? data as Map<String, dynamic> : <String, dynamic>{};
      final peerId = _peerIdFromData(map);

      if (_isGroupCall) {
        // Close only that peer's connection so the video tile disappears and call continues for others
        _removePeerConnection(peerId);
        if (_peerConnections.isEmpty) endCall();
      } else {
        endCall();
      }
    });

    _socket!.on('error', (data) {
      debugPrint('[WebRTC] Socket Error: $data');
    });

    _socket!.connect();
  }

  // ── Media ─────────────────────────────────────────────────────────────────

  Future<void> startLocalMedia({bool video = true, bool audio = true}) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': video
          ? {
              'mandatory': {
                'minWidth': '480',
                'minHeight': '360',
                'maxWidth': '640',
                'maxHeight': '480',
                'maxFrameRate': '24',
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };

    try {
      _localStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);
      if (video) {
        localRenderer.srcObject = _localStream;
      }
      _safeNotify();
    } catch (e) {
      debugPrint('[WebRTC] Error getting user media: $e');
    }
  }

  /// Join a call room.
  ///
  /// Pass [isGroupCall] = true for group calls so the correct
  /// `callType` (`GROUP_VIDEO` / `GROUP_AUDIO`) is emitted and
  /// per-peer connection logic is enabled.
  Future<void> joinCallRoom(
    String roomId, {
    bool isVideoCall = true,
    bool isGroupCall = false,
  }) async {
    _currentRoomId = roomId;
    _isVideoCall = isVideoCall;
    _isGroupCall = isGroupCall;
    _callState = CallState.connecting;
    _safeNotify();

    // Ensure socket is connected before joining.
    if (_socket != null && !_socket!.connected) {
      debugPrint('[WebRTC] Socket not connected yet, waiting for connection...');
      _socket!.connect();
      int waitMs = 0;
      while (!_socket!.connected && waitMs < 8000) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitMs += 100;
      }
    }

    if (_socket == null || !_socket!.connected) {
      debugPrint(
        '[WebRTC] Socket failed to connect after 8s — aborting joinCallRoom',
      );
      return;
    }

    // Emit the correct callType so the server handles the room correctly.
    final callType = _isGroupCall
        ? (isVideoCall ? 'GROUP_VIDEO' : 'GROUP_AUDIO')
        : (isVideoCall ? 'DIRECT_VIDEO' : 'DIRECT_AUDIO');

    debugPrint(
      '[WebRTC] Emitting room:join for room $roomId (callType: $callType)',
    );
    _socket!.emit('room:join', {'roomId': roomId, 'callType': callType});

    // Acquire local media AFTER joining so we don't time out.
    if (isVideoCall) {
      await _initRenderersFuture;
    }
    await startLocalMedia(video: isVideoCall, audio: true);
  }

  // ── Peer connection factory ───────────────────────────────────────────────

  Future<RTCPeerConnection> _createPeerConnectionForPeer(
    String peerId,
  ) async {
    if (_peerConnections.containsKey(peerId)) {
      return _peerConnections[peerId]!;
    }

    debugPrint('[WebRTC] Creating peer connection for peer $peerId');
    final pc = await createPeerConnection(_iceServers);
    _peerConnections[peerId] = pc;

    // Add our local tracks to this peer connection.
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    // Handle incoming remote tracks from this peer.
    pc.onTrack = (RTCTrackEvent event) async {
      debugPrint(
        '[WebRTC] Remote track received from $peerId: ${event.track.kind}, streams: ${event.streams.length}',
      );
      MediaStream stream;
      if (event.streams.isNotEmpty) {
        stream = event.streams[0];
      } else {
        stream = _remoteStreams[peerId] ??
            await createLocalMediaStream('remote_$peerId');
        await stream.addTrack(event.track);
      }
      _remoteStreams[peerId] = stream;

      // Maintain dynamic per-peer video renderer
      if (!remoteRenderers.containsKey(peerId)) {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        renderer.srcObject = stream;
        remoteRenderers[peerId] = renderer;
      } else {
        remoteRenderers[peerId]!.srcObject = stream;
      }

      // Bind the first arriving remote stream to the main renderer for 1-on-1 compatibility.
      if (_isVideoCall && (_remoteStreams.length == 1 || remoteRenderer.srcObject == null)) {
        remoteRenderer.srcObject = stream;
      }
      _safeNotify();
    };

    // Send our ICE candidates to the remote peer.
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (_currentRoomId != null && candidate.candidate != null) {
        debugPrint('[WebRTC] >>> Sending ICE candidate to $peerId');
        _socket?.emit('webrtc:candidate', {
          'roomId': _currentRoomId,
          'to': peerId, // targeted delivery
          'candidate': candidate.toMap(),
        });
      }
    };

    pc.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('[WebRTC] ICE Connection State for $peerId: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _iceDisconnectTimers[peerId]?.cancel();
        _iceDisconnectTimers.remove(peerId);
        _iceRestartAttempts[peerId] = 0;
        if (_reconnectingPeers.remove(peerId)) {
          _safeNotify();
        }
        _startSpeakerStatsMonitor();
        _rebindAndRestoreVideo(peerId);
        // Staggered second pass to resolve any packet-timing or keyframe arrival delay
        Future.delayed(const Duration(milliseconds: 400), () {
          if (_peerConnections.containsKey(peerId)) {
            _rebindAndRestoreVideo(peerId);
          }
        });
        _updateAdaptiveBitrates();
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        // Transient disconnect: wait 3.5s before triggering ICE restart
        _iceDisconnectTimers[peerId]?.cancel();
        _iceDisconnectTimers[peerId] = Timer(const Duration(milliseconds: 3500), () {
          debugPrint('[WebRTC] ICE disconnected >3.5s for $peerId — auto-restarting ICE');
          _reconnectingPeers.add(peerId);
          _safeNotify();
          _restartIceForPeer(peerId);
        });
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        // Immediate failure: initiate ICE restart right away
        _iceDisconnectTimers[peerId]?.cancel();
        _iceDisconnectTimers.remove(peerId);
        debugPrint('[WebRTC] ICE failed for $peerId — initiating immediate ICE restart');
        _reconnectingPeers.add(peerId);
        _safeNotify();
        _restartIceForPeer(peerId);
      }
    };

    return pc;
  }

  /// Optimize SDP by enabling Opus DTX (Discontinuous Transmission)
  /// and applying bandwidth limits (b=AS) on video.
  String _optimizeSdp(String sdp, {required int peerCount}) {
    var modified = sdp;

    // 1. Audio: Enable Opus DTX & In-Band FEC to eliminate silence-packet flooding
    modified = modified.replaceAllMapped(
      RegExp(r'(a=fmtp:\d+ [^\r\n]*)'),
      (match) {
        final line = match.group(0)!;
        if (!line.contains('usedtx=')) {
          return '$line;usedtx=1;useinbandfec=1;maxaveragebitrate=32000';
        }
        return line;
      },
    );

    // 2. Video: Apply b=AS bitrate limit matching participant scale
    if (_isVideoCall) {
      final int videoBitrateKbps;
      if (peerCount <= 1 && !_isGroupCall) {
        videoBitrateKbps = 750;
      } else if (peerCount <= 2) {
        videoBitrateKbps = 300;
      } else {
        videoBitrateKbps = 180;
      }

      if (modified.contains('b=AS:')) {
        modified = modified.replaceAll(
          RegExp(r'b=AS:\d+'),
          'b=AS:$videoBitrateKbps',
        );
      } else {
        modified = modified.replaceFirstMapped(
          RegExp(r'(m=video[^\r\n]*\r?\n(?:c=IN[^\r\n]*\r?\n)?)'),
          (match) => '${match.group(0)}b=AS:$videoBitrateKbps\r\n',
        );
      }
    }

    return modified;
  }

  /// Dynamically updates video bitrate, framerate, and resolution downscaling
  /// across all active peer connections based on participant count.
  Future<void> _updateAdaptiveBitrates() async {
    final peerCount = _peerConnections.length;
    if (peerCount == 0) return;

    final int targetMaxBitrate;
    final int targetMaxFramerate;
    final double targetScaleDown;

    if (peerCount <= 1 && !_isGroupCall) {
      // 1-on-1 call: Maximum clarity (750 kbps, 24 fps, no downscaling)
      targetMaxBitrate = 750000;
      targetMaxFramerate = 24;
      targetScaleDown = 1.0;
    } else if (peerCount <= 2) {
      // 3 participants total (2 outgoing streams): 300 kbps, 20 fps, 1.5x downscaling
      targetMaxBitrate = 300000;
      targetMaxFramerate = 20;
      targetScaleDown = 1.5;
    } else {
      // 4+ participants: 180 kbps, 15 fps, 2.0x downscaling (75% fewer pixels)
      targetMaxBitrate = 180000;
      targetMaxFramerate = 15;
      targetScaleDown = 2.0;
    }

    debugPrint(
      '[WebRTC] Applying adaptive quality for $peerCount peer(s): '
      'bitrate=${targetMaxBitrate ~/ 1000}kbps, '
      'fps=$targetMaxFramerate, '
      'scaleDown=$targetScaleDown',
    );

    for (final entry in _peerConnections.entries) {
      final peerId = entry.key;
      final pc = entry.value;
      try {
        final senders = await pc.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            final params = sender.parameters;
            if (params.encodings != null && params.encodings!.isNotEmpty) {
              for (final enc in params.encodings!) {
                enc.maxBitrate = targetMaxBitrate;
                enc.maxFramerate = targetMaxFramerate;
                enc.scaleResolutionDownBy = targetScaleDown;
              }
              await sender.setParameters(params);
              debugPrint('[WebRTC] Updated sender parameters for peer $peerId');
            }
          }
        }
      } catch (e) {
        debugPrint('[WebRTC] Error setting adaptive parameters for $peerId: $e');
      }
    }
  }

  // ── Active Speaker Detection Monitor ─────────────────────────────────────

  void _startSpeakerStatsMonitor() {
    if (_speakerStatsTimer != null) return;
    _speakerStatsTimer = Timer.periodic(const Duration(milliseconds: 350), (_) async {
      if (_callState != CallState.connected || _peerConnections.isEmpty) {
        if (_activeSpeakerId != null) {
          _activeSpeakerId = null;
          _audioLevels.clear();
          _safeNotify();
        }
        return;
      }

      String? topSpeakerId;
      double topLevel = 0.04;
      bool hasChanges = false;
      _networkQualityTick++;
      final bool shouldUpdateQuality = (_networkQualityTick % 3 == 0); // approx every 1.05s

      // 1. Remote peers audio levels & network stats
      for (final entry in _peerConnections.entries) {
        final peerId = entry.key;
        final pc = entry.value;
        try {
          final stats = await pc.getStats();
          for (final report in stats) {
            final level = _extractAudioLevel(report);
            if (level != null) {
              final prev = _audioLevels[peerId] ?? 0.0;
              final smoothed = (prev * 0.3) + (level * 0.7);
              _audioLevels[peerId] = smoothed;
              if (smoothed > topLevel) {
                topLevel = smoothed;
                topSpeakerId = peerId;
              }
              if ((prev - smoothed).abs() > 0.02) {
                hasChanges = true;
              }
            }
          }

          if (shouldUpdateQuality) {
            final qualityChanged = _processPeerNetworkQuality(peerId, stats);
            if (qualityChanged) {
              hasChanges = true;
            }
          }
        } catch (_) {}
      }

      // 2. Local audio level (if not muted)
      if (!_isMicMuted && _peerConnections.isNotEmpty) {
        final firstPc = _peerConnections.values.firstOrNull;
        if (firstPc != null) {
          try {
            final stats = await firstPc.getStats();
            for (final report in stats) {
              if (report.type == 'media-source' || report.type == 'outbound-rtp') {
                final level = _extractAudioLevel(report);
                if (level != null) {
                  final prev = _audioLevels['local'] ?? 0.0;
                  final smoothed = (prev * 0.3) + (level * 0.7);
                  _audioLevels['local'] = smoothed;
                  if (smoothed > topLevel) {
                    topLevel = smoothed;
                    topSpeakerId = 'local';
                  }
                  if ((prev - smoothed).abs() > 0.02) {
                    hasChanges = true;
                  }
                }
              }
            }
          } catch (_) {}
        }
      } else {
        if ((_audioLevels['local'] ?? 0.0) > 0.0) {
          _audioLevels['local'] = 0.0;
          hasChanges = true;
        }
      }

      // 3. Active speaker holdover / hysteresis
      final now = DateTime.now();
      if (topSpeakerId != null) {
        _lastSpeechTime = now;
        if (_activeSpeakerId != topSpeakerId) {
          _activeSpeakerId = topSpeakerId;
          hasChanges = true;
        }
      } else if (_lastSpeechTime != null &&
          now.difference(_lastSpeechTime!) > const Duration(milliseconds: 700)) {
        if (_activeSpeakerId != null) {
          _activeSpeakerId = null;
          hasChanges = true;
        }
      }

      if (hasChanges) {
        _safeNotify();
      }
    });
  }

  void _stopSpeakerStatsMonitor() {
    _speakerStatsTimer?.cancel();
    _speakerStatsTimer = null;
    _audioLevels.clear();
    _activeSpeakerId = null;
    _lastSpeechTime = null;
    _networkQualities.clear();
    _prevPacketsLost.clear();
    _prevPacketsReceived.clear();
    _networkQualityTick = 0;
  }

  double? _extractAudioLevel(StatsReport report) {
    final values = report.values;
    final kind = values['kind'] ?? values['mediaType'];
    if (kind != 'audio' && report.type != 'media-source') {
      return null;
    }

    if (values.containsKey('audioLevel')) {
      final val = values['audioLevel'];
      if (val is num) return val.toDouble().clamp(0.0, 1.0);
      if (val is String) {
        final parsed = double.tryParse(val);
        if (parsed != null) return parsed.clamp(0.0, 1.0);
      }
    }

    if (values.containsKey('audioOutputLevel')) {
      final val = values['audioOutputLevel'];
      final numVal = val is num ? val.toDouble() : double.tryParse(val.toString());
      if (numVal != null) return (numVal / 32767.0).clamp(0.0, 1.0);
    }

    if (values.containsKey('audioInputLevel')) {
      final val = values['audioInputLevel'];
      final numVal = val is num ? val.toDouble() : double.tryParse(val.toString());
      if (numVal != null) return (numVal / 32767.0).clamp(0.0, 1.0);
    }

    return null;
  }

  bool _processPeerNetworkQuality(String peerId, List<StatsReport> reports) {
    double? rtt;
    double? jitter;
    int currentPacketsLost = 0;
    int currentPacketsReceived = 0;
    bool hasRtp = false;

    for (final report in reports) {
      final values = report.values;

      // 1. Candidate-pair for Round Trip Time (RTT)
      if (report.type == 'candidate-pair') {
        final state = values['state'];
        final nominated = values['nominated'];
        final selected = values['selected'];
        final isSelected = state == 'succeeded' ||
            nominated == true ||
            nominated == 'true' ||
            selected == true ||
            selected == 'true';

        if (isSelected || values.containsKey('currentRoundTripTime')) {
          final rttVal = values['currentRoundTripTime'] ?? values['roundTripTime'];
          if (rttVal != null) {
            final parsed = _numToDouble(rttVal);
            if (parsed != null && parsed > 0) {
              rtt = parsed < 5.0 ? parsed * 1000.0 : parsed;
            }
          }
        }
      }

      // 2. Inbound-RTP for Jitter & Packet Loss
      if (report.type == 'inbound-rtp') {
        hasRtp = true;
        if (values.containsKey('jitter')) {
          final jVal = _numToDouble(values['jitter']);
          if (jVal != null && jVal > 0) {
            final jMs = jVal < 5.0 ? jVal * 1000.0 : jVal;
            if (jitter == null || jMs > jitter) {
              jitter = jMs;
            }
          }
        }

        if (values.containsKey('packetsLost')) {
          final pl = _numToInt(values['packetsLost']);
          if (pl != null && pl >= 0) {
            currentPacketsLost += pl;
          }
        }

        if (values.containsKey('packetsReceived')) {
          final pr = _numToInt(values['packetsReceived']);
          if (pr != null && pr >= 0) {
            currentPacketsReceived += pr;
          }
        }
      }

      // 3. Remote-Inbound-RTP (RTCP receiver report fallback)
      if (report.type == 'remote-inbound-rtp') {
        if (rtt == null && values.containsKey('roundTripTime')) {
          final rVal = _numToDouble(values['roundTripTime']);
          if (rVal != null && rVal > 0) {
            rtt = rVal < 5.0 ? rVal * 1000.0 : rVal;
          }
        }
        if (jitter == null && values.containsKey('jitter')) {
          final jVal = _numToDouble(values['jitter']);
          if (jVal != null && jVal > 0) {
            jitter = jVal < 5.0 ? jVal * 1000.0 : jVal;
          }
        }
      }
    }

    // Packet loss calculation over window delta
    double lossPercent = 0.0;
    if (hasRtp) {
      final prevLost = _prevPacketsLost[peerId];
      final prevRecv = _prevPacketsReceived[peerId];

      if (prevLost != null && prevRecv != null) {
        final deltaLost = currentPacketsLost - prevLost;
        final deltaRecv = currentPacketsReceived - prevRecv;
        final deltaTotal = deltaLost + deltaRecv;

        if (deltaTotal > 0 && deltaLost >= 0) {
          final rawLoss = (deltaLost / deltaTotal) * 100.0;
          final prevLoss = _networkQualities[peerId]?.packetLossPercent ?? 0.0;
          lossPercent = (prevLoss * 0.4) + (rawLoss.clamp(0.0, 100.0) * 0.6);
        } else {
          final prevLoss = _networkQualities[peerId]?.packetLossPercent ?? 0.0;
          lossPercent = prevLoss * 0.5; // decay
        }
      }

      _prevPacketsLost[peerId] = currentPacketsLost;
      _prevPacketsReceived[peerId] = currentPacketsReceived;
    }

    final effectiveRtt = rtt ?? _networkQualities[peerId]?.rttMs ?? 35.0;
    final effectiveJitter = jitter ?? _networkQualities[peerId]?.jitterMs ?? 8.0;

    // ITU-T G.107 standard E-model Mean Opinion Score (MOS)
    final effectiveDelay = (effectiveRtt / 2.0) + (effectiveJitter * 2.0) + 10.0;
    final delayImpairment = effectiveDelay > 100.0 ? (effectiveDelay - 100.0) / 35.0 : 0.0;
    final lossImpairment = lossPercent * 2.5;

    double rFactor = 94.2 - delayImpairment - lossImpairment;
    rFactor = rFactor.clamp(0.0, 100.0);

    double mos = 1.0;
    if (rFactor >= 100.0) {
      mos = 4.5;
    } else if (rFactor > 0.0) {
      mos = 1.0 + 0.035 * rFactor + rFactor * (rFactor - 60.0) * (100.0 - rFactor) * 7.0e-6;
    }
    mos = mos.clamp(1.0, 4.5);

    int bars;
    String label;
    if (lossPercent > 10.0 || effectiveRtt > 450.0 || effectiveJitter > 120.0 || mos < 2.5) {
      bars = 1;
      label = 'Poor';
    } else if (lossPercent > 5.0 || effectiveRtt > 280.0 || effectiveJitter > 70.0 || mos < 3.4) {
      bars = 2;
      label = 'Fair';
    } else if (lossPercent > 2.0 || effectiveRtt > 160.0 || effectiveJitter > 35.0 || mos < 4.0) {
      bars = 3;
      label = 'Good';
    } else {
      bars = 4;
      label = 'Excellent';
    }

    final isPoor = bars == 1 || lossPercent >= 5.0;

    final prevQuality = _networkQualities[peerId];
    final updatedQuality = NetworkQuality(
      rttMs: double.parse(effectiveRtt.toStringAsFixed(1)),
      jitterMs: double.parse(effectiveJitter.toStringAsFixed(1)),
      packetLossPercent: double.parse(lossPercent.toStringAsFixed(1)),
      mos: double.parse(mos.toStringAsFixed(2)),
      bars: bars,
      label: label,
      isPoor: isPoor,
    );

    _networkQualities[peerId] = updatedQuality;

    // Update local network quality (derived from peer connection health)
    NetworkQuality worst = updatedQuality;
    for (final entry in _networkQualities.entries) {
      if (entry.key != 'local' && entry.value.bars < worst.bars) {
        worst = entry.value;
      }
    }
    _networkQualities['local'] = worst;

    return prevQuality?.bars != bars || prevQuality?.isPoor != isPoor;
  }

  static double? _numToDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  static int? _numToInt(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString());
  }

  // ── Network Resilience & ICE Restart ─────────────────────────────────────

  /// Restores video pipeline after ICE reconnect, renegotiation, or track stall.
  /// Fully restores video after ICE reconnection:
  /// 1. Kickstarts sender video encoder via replaceTrack to force an immediate IDR keyframe
  /// 2. Unmutes and enables remote video tracks
  /// 3. Recreates the RTCVideoRenderer (dispose + initialize) to flush the frozen native texture
  /// 4. Increments videoRefreshEpoch to force UI widget to rebuild with new renderer
  /// 5. Requests remote peer to also transmit a fresh keyframe
  Future<void> _rebindAndRestoreVideo(String peerId) async {
    debugPrint('[WebRTC] 🔄 Rebinding & restoring video stream for peer: $peerId');

    // 1. Force local video sender to produce a fresh IDR keyframe
    await _kickstartVideoSender(peerId);

    // 2. Ensure remote stream & video tracks are enabled
    final stream = _remoteStreams[peerId];
    if (stream != null) {
      for (final track in stream.getVideoTracks()) {
        track.enabled = true;
      }

      // 3. Recreate per-peer renderer — the only reliable fix for a frozen native texture.
      //    Setting srcObject=null then srcObject=stream is NOT enough when the stream object
      //    reference hasn't changed; the platform layer skips re-initialization.
      //    We must dispose and re-initialize to obtain a new textureId.
      final freshPeerRenderer = await _recreateRenderer(
        old: remoteRenderers[peerId],
        stream: stream,
      );
      remoteRenderers[peerId] = freshPeerRenderer;

      // 4. Recreate main renderer (for 1-on-1 mode)
      if (_isVideoCall && (_remoteStreams.length == 1 || remoteRenderer.srcObject != null)) {
        final freshMain = await _recreateRenderer(
          old: remoteRenderer,
          stream: stream,
          reuse: remoteRenderer, // reuse the field reference but re-initialize it in-place
        );
        if (!identical(freshMain, remoteRenderer)) {
          // If a new instance was created (old was null or disposed), re-init the shared field
          remoteRenderer.srcObject = stream;
        }
      }
    }

    _videoRefreshEpoch++;
    _safeNotify();

    // 5. Ask remote peer over socket to also transmit a fresh keyframe
    if (_currentRoomId != null) {
      _socket?.emit('webrtc:request_keyframe', {
        'roomId': _currentRoomId,
        'to': peerId,
      });
    }
  }

  /// Disposes [old] renderer and returns a fresh initialized renderer with [stream] attached.
  /// If [reuse] is provided, re-initializes it in-place (for named fields like remoteRenderer)
  /// and returns it; otherwise creates and returns a brand-new RTCVideoRenderer.
  Future<RTCVideoRenderer> _recreateRenderer({
    RTCVideoRenderer? old,
    required MediaStream stream,
    RTCVideoRenderer? reuse,
  }) async {
    if (reuse != null) {
      // In-place re-init for a named field we can't replace
      try { reuse.srcObject = null; } catch (_) {}
      try { await reuse.initialize(); } catch (_) {}
      reuse.srcObject = stream;
      return reuse;
    }
    // For map-stored renderers: dispose old, create fresh one
    try { old?.srcObject = null; } catch (_) {}
    try { await old?.dispose(); } catch (_) {}
    final fresh = RTCVideoRenderer();
    await fresh.initialize();
    fresh.srcObject = stream;
    return fresh;
  }

  /// Forces libwebrtc video encoder to re-initialize and generate an IDR keyframe
  Future<void> _kickstartVideoSender(String peerId) async {
    final pc = _peerConnections[peerId];
    if (pc == null || _localStream == null || _isVideoOff) return;

    final localVideoTrack = _localStream!.getVideoTracks().firstOrNull;
    if (localVideoTrack == null) return;

    try {
      localVideoTrack.enabled = true;
      final senders = await pc.getSenders();
      for (final sender in senders) {
        if (sender.track?.kind == 'video') {
          await sender.replaceTrack(localVideoTrack);
          debugPrint('[WebRTC] 🎬 replaceTrack invoked on video sender for $peerId (IDR keyframe forced)');
        }
      }
    } catch (e) {
      debugPrint('[WebRTC] Note on kickstarting video sender for $peerId: $e');
    }
  }

  /// Attempts automatic ICE restart on an unstable or broken peer connection
  Future<void> _restartIceForPeer(String peerId) async {
    final pc = _peerConnections[peerId];
    if (pc == null) return;

    final attempts = (_iceRestartAttempts[peerId] ?? 0) + 1;
    _iceRestartAttempts[peerId] = attempts;

    if (attempts > 3) {
      debugPrint('[WebRTC] Max ICE restart attempts reached (3) for $peerId');
      _reconnectingPeers.remove(peerId);
      _safeNotify();
      return;
    }

    debugPrint('[WebRTC] 🔄 Restarting ICE for $peerId (Attempt $attempts/3)...');

    try {
      try {
        await pc.restartIce();
      } catch (e) {
        debugPrint('[WebRTC] pc.restartIce() call note: $e');
      }

      await _createOffer(peerId, isIceRestart: true);
      await _kickstartVideoSender(peerId);
    } catch (e) {
      debugPrint('[WebRTC] Error during ICE restart for $peerId: $e');
    }
  }

  // ── Offer / Answer (Perfect Negotiation Pattern) ─────────────────────────

  Future<void> _createOffer(String peerId, {bool isIceRestart = false}) async {
    try {
      _makingOffer[peerId] = true;
      final pc = await _createPeerConnectionForPeer(peerId);
      final offer = await pc.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': _isVideoCall,
        if (isIceRestart) 'iceRestart': true,
      });
      // A freshly-created peer connection reports signalingState as null,
      // which is functionally equivalent to "stable". Allow both.
      if (pc.signalingState != null &&
          pc.signalingState != RTCSignalingState.RTCSignalingStateStable) {
        debugPrint(
          '[WebRTC] Signaling state not stable (${pc.signalingState}) - skipping offer creation for $peerId',
        );
        return;
      }
      final optimizedSdp = _optimizeSdp(
        offer.sdp ?? '',
        peerCount: _peerConnections.length,
      );
      final optimizedOffer = RTCSessionDescription(optimizedSdp, offer.type);
      await pc.setLocalDescription(optimizedOffer);

      _socket?.emit('webrtc:offer', {
        'roomId': _currentRoomId,
        'to': peerId,
        'sdp': optimizedOffer.toMap(),
        if (isIceRestart) 'isIceRestart': true,
      });
      debugPrint(
        '[WebRTC] Sent ${isIceRestart ? "ICE restart offer" : "offer"} to peer $peerId',
      );
    } catch (e) {
      debugPrint('[WebRTC] Error creating offer for $peerId: $e');
    } finally {
      _makingOffer[peerId] = false;
    }
  }

  Future<void> _handleOffer(
    Map<String, dynamic> sdpMap,
    String peerId, {
    bool isIceRestart = false,
  }) async {
    try {
      final pc = await _createPeerConnectionForPeer(peerId);

      // Deterministic role assignment:
      // Larger ID is polite (accepts offer), smaller ID is impolite (initiator priority).
      final isPolite =
          _currentUserId != null && _currentUserId!.compareTo(peerId) > 0;
      // A freshly-created peer connection reports signalingState as null,
      // which is functionally equivalent to "stable". Treat both as non-colliding.
      final signalingStable = pc.signalingState == null ||
          pc.signalingState == RTCSignalingState.RTCSignalingStateStable;
      final offerCollision = (_makingOffer[peerId] == true) || !signalingStable;

      if (offerCollision && !isPolite) {
        debugPrint(
          '[WebRTC] Glare collision detected: Impolite peer ignoring offer from $peerId',
        );
        return;
      }

      final description =
          RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);
      await pc.setRemoteDescription(description);

      final answer = await pc.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': _isVideoCall,
      });
      final optimizedSdp = _optimizeSdp(
        answer.sdp ?? '',
        peerCount: _peerConnections.length,
      );
      final optimizedAnswer = RTCSessionDescription(optimizedSdp, answer.type);
      await pc.setLocalDescription(optimizedAnswer);

      _socket?.emit('webrtc:answer', {
        'roomId': _currentRoomId,
        'to': peerId,
        'sdp': optimizedAnswer.toMap(),
      });
      debugPrint('[WebRTC] Sent answer to peer $peerId${isIceRestart ? " (ICE restart)" : ""}');

      await _drainPendingCandidates(peerId);

      if (isIceRestart) {
        // For ICE restart offers, Device B (the non-disconnecting peer) may never see
        // an ICE state transition back to "connected" because it was always connected.
        // Schedule delayed video restoration after ICE has had time to use new candidates.
        debugPrint('[WebRTC] ICE restart answer sent — scheduling delayed video restore for $peerId');
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (_peerConnections.containsKey(peerId)) {
            debugPrint('[WebRTC] 🔄 Delayed restore (1200ms) for ICE restart peer: $peerId');
            _rebindAndRestoreVideo(peerId);
          }
        });
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (_peerConnections.containsKey(peerId)) {
            debugPrint('[WebRTC] 🔄 Delayed restore (2500ms) for ICE restart peer: $peerId');
            _rebindAndRestoreVideo(peerId);
          }
        });
      } else {
        await _rebindAndRestoreVideo(peerId);
      }
      _updateAdaptiveBitrates();
    } catch (e) {
      debugPrint('[WebRTC] Error handling offer from $peerId: $e');
    }
  }

  // ── Peer removal (group call: one peer leaves) ───────────────────────────

  void _removePeerConnection(String peerId) {
    final pc = _peerConnections.remove(peerId);
    pc?.close();
    pc?.dispose();
    _pendingCandidates.remove(peerId);
    _makingOffer.remove(peerId);
    _iceDisconnectTimers.remove(peerId)?.cancel();
    _iceRestartAttempts.remove(peerId);
    _reconnectingPeers.remove(peerId);
    _networkQualities.remove(peerId);
    _prevPacketsLost.remove(peerId);
    _prevPacketsReceived.remove(peerId);

    final renderer = remoteRenderers.remove(peerId);
    if (renderer != null) {
      try {
        renderer.srcObject = null;
        renderer.dispose();
      } catch (_) {}
    }

    final stream = _remoteStreams.remove(peerId);
    try {
      for (final track in stream?.getTracks() ?? []) {
        track.stop();
      }
      stream?.dispose();
    } catch (_) {}

    // Re-bind renderer to another peer if needed.
    if (_remoteStreams.isNotEmpty && _isVideoCall) {
      remoteRenderer.srcObject = _remoteStreams.values.first;
    } else if (_remoteStreams.isEmpty) {
      remoteRenderer.srcObject = null;
    }
    _safeNotify();
    _updateAdaptiveBitrates();
  }

  // ── Call controls ─────────────────────────────────────────────────────────

  void toggleMic() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        _isMicMuted = !_isMicMuted;
        audioTracks[0].enabled = !_isMicMuted;
        _safeNotify();
      }
    }
  }

  void toggleCamera() {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        _isVideoOff = !_isVideoOff;
        videoTracks[0].enabled = !_isVideoOff;
        _safeNotify();
      }
    }
  }

  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        await Helper.switchCamera(videoTrack);
      }
    }
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    try {
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
    } catch (e) {
      debugPrint('[WebRTC] Error toggling speaker: $e');
    }
    _safeNotify();
  }

  // ── End Call ──────────────────────────────────────────────────────────────

  Future<void> endCall() async {
    if (_callState == CallState.ended) return;
    _stopSpeakerStatsMonitor();

    for (final timer in _iceDisconnectTimers.values) {
      timer.cancel();
    }
    _iceDisconnectTimers.clear();
    _iceRestartAttempts.clear();
    _reconnectingPeers.clear();

    if (_currentRoomId != null) {
      _socket?.emit('call:end', {
        'roomId': _currentRoomId,
        'durationSeconds': 0,
      });
    }

    _callState = CallState.ended;
    _isFirstPeer = false;

    // 1. Detach renderers first so native sinks unregister.
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    for (final renderer in remoteRenderers.values) {
      try {
        renderer.srcObject = null;
        renderer.dispose();
      } catch (_) {}
    }
    remoteRenderers.clear();
    await Future.delayed(const Duration(milliseconds: 60));

    // 2. Close all peer connections.
    for (final entry in _peerConnections.entries) {
      try {
        await entry.value.close();
        await entry.value.dispose();
      } catch (e) {
        debugPrint(
          '[WebRTC] Error closing peer connection for ${entry.key}: $e',
        );
      }
    }
    _peerConnections.clear();
    _pendingCandidates.clear();

    // 3. Stop and dispose local media stream.
    if (_localStream != null) {
      try {
        for (final track in _localStream!.getTracks()) {
          await track.stop();
        }
        await _localStream!.dispose();
      } catch (e) {
        debugPrint('[WebRTC] Error disposing local stream: $e');
      }
      _localStream = null;
    }

    // 4. Stop and dispose all remote streams.
    for (final stream in _remoteStreams.values) {
      try {
        for (final track in stream.getTracks()) {
          await track.stop();
        }
        await stream.dispose();
      } catch (e) {
        debugPrint('[WebRTC] Remote stream cleanup: $e');
      }
    }
    _remoteStreams.clear();

    _currentRoomId = null;
    _safeNotify();

    // 5. Disconnect and release the call socket.
    removeSocketListeners();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    // Reset to idle after a short pause.
    Future.delayed(const Duration(seconds: 1), () {
      if (_disposed) return;
      _callState = CallState.idle;
      _safeNotify();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _stopSpeakerStatsMonitor();

    for (final timer in _iceDisconnectTimers.values) {
      timer.cancel();
    }
    _iceDisconnectTimers.clear();
    _iceRestartAttempts.clear();
    _reconnectingPeers.clear();

    removeSocketListeners();
    _pendingCandidates.clear();

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    for (final renderer in remoteRenderers.values) {
      try {
        renderer.srcObject = null;
        renderer.dispose();
      } catch (_) {}
    }
    remoteRenderers.clear();

    for (final pc in _peerConnections.values) {
      try {
        pc.close();
        pc.dispose();
      } catch (_) {}
    }
    _peerConnections.clear();

    if (_localStream != null) {
      try {
        for (final track in _localStream!.getTracks()) {
          track.stop();
        }
        _localStream!.dispose();
      } catch (e) {
        debugPrint('[WebRTC] Error disposing local stream during teardown: $e');
      }
      _localStream = null;
    }

    for (final stream in _remoteStreams.values) {
      try {
        for (final track in stream.getTracks()) {
          track.stop();
        }
        stream.dispose();
      } catch (e) {
        debugPrint('[WebRTC] Error disposing remote stream: $e');
      }
    }
    _remoteStreams.clear();

    localRenderer.dispose();
    remoteRenderer.dispose();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    super.dispose();
  }

  /// Detach all socket event listeners to prevent stray notifications
  /// after the page is disposed.
  void removeSocketListeners() {
    if (_socket == null) return;
    _socket!
      ..off('room:joined')
      ..off('room:participant_joined')
      ..off('webrtc:offer')
      ..off('webrtc:answer')
      ..off('webrtc:candidate')
      ..off('webrtc:request_keyframe')
      ..off('call:ended')
      ..off('room:participant_left')
      ..off('error');
  }
}
