import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../config/api_config.dart';

enum CallState { idle, connecting, connected, ended }

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

  // ── Renderers (public) ────────────────────────────────────────────────────
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> remoteRenderers = {};

  bool _disposed = false;
  bool _isFirstPeer = false;

  CallState _callState = CallState.idle;
  CallState get callState => _callState;

  String? _currentRoomId;
  DateTime? _callStartTime;

  bool _isVideoCall = true;
  bool get isVideoCall => _isVideoCall;

  bool _isMicMuted = false;
  bool get isMicMuted => _isMicMuted;

  bool _isVideoOff = false;
  bool get isVideoOff => _isVideoOff;

  bool _isSpeakerOn = false;
  bool get isSpeakerOn => _isSpeakerOn;

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
          .setReconnectionAttempts(3)
          .setReconnectionDelay(500)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[WebRTC] Connected to Video Calls Socket.io server');
    });

    _socket!.onDisconnect((_) {
      debugPrint('[WebRTC] Disconnected from Video Calls Socket.io server');
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
      _callState = CallState.connected;
      _callStartTime = DateTime.now();
      _safeNotify();

      // Extract the joining peer's ID for targeted offer creation.
      final map =
          data is Map ? data as Map<String, dynamic> : <String, dynamic>{};
      final peerId = _peerIdFromData(
        map,
        fallback: 'peer_${_peerConnections.length}',
      );

      // Create a dedicated offer for this specific peer.
      // Any participant who joined earlier (or is first) sends offers.
      if (_isFirstPeer || _peerConnections.isEmpty) {
        await _createOffer(peerId);
      } else if (_isGroupCall) {
        // In a group call, every existing participant creates an offer
        // to the newly joined peer.
        await _createOffer(peerId);
      }
    });

    // ── webrtc:offer ──────────────────────────────────────────────────────
    _socket!.on('webrtc:offer', (data) async {
      debugPrint('[WebRTC] Received WebRTC offer');
      final map = data as Map<String, dynamic>;
      final sdpMap = map['sdp'] as Map<String, dynamic>;
      final peerId = _peerIdFromData(
        map,
        fallback: 'peer_${_peerConnections.length}',
      );
      await _handleOffer(sdpMap, peerId);
    });

    // ── webrtc:answer ─────────────────────────────────────────────────────
    _socket!.on('webrtc:answer', (data) async {
      debugPrint('[WebRTC] Received WebRTC answer');
      final map = data as Map<String, dynamic>;
      final sdpMap = map['sdp'] as Map<String, dynamic>;
      final peerId = _peerIdFromData(
        map,
        fallback: _peerConnections.keys.firstOrNull ?? 'peer_0',
      );

      final pc = _peerConnections[peerId];
      if (pc == null) {
        debugPrint('[WebRTC] No peer connection found for peerId: $peerId, connections: ${_peerConnections.keys}');
        // Fallback: try the first available connection (1-on-1 compat)
        final fallbackPc = _peerConnections.values.firstOrNull;
        if (fallbackPc != null) {
          final description =
              RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);
          await fallbackPc.setRemoteDescription(description);
          final fallbackKey = _peerConnections.keys.first;
          await _drainPendingCandidates(fallbackKey);
        }
        return;
      }
      final description =
          RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);
      await pc.setRemoteDescription(description);
      await _drainPendingCandidates(peerId);
    });

    // ── webrtc:candidate ──────────────────────────────────────────────────
    _socket!.on('webrtc:candidate', (data) async {
      debugPrint('[WebRTC] <<< Remote ICE candidate arrived');
      final map = data as Map<String, dynamic>;
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

    // ── call:ended ────────────────────────────────────────────────────────
    _socket!.on('call:ended', (data) {
      String? eventRoomId;
      if (data is Map) {
        eventRoomId = data['roomId'] as String?;
      } else if (data is List && data.isNotEmpty && data.first is Map) {
        eventRoomId = data.first['roomId'] as String?;
      }
      if (eventRoomId != null && eventRoomId != _currentRoomId) {
        debugPrint(
          '[WebRTC] Ignoring stale call:ended for room $eventRoomId (current: $_currentRoomId)',
        );
        return;
      }
      debugPrint('[WebRTC] Call ended by server/peer: $data');
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

      if (_isGroupCall) {
        // In group calls: close only that peer's connection, keep the call alive.
        final map =
            data is Map ? data as Map<String, dynamic> : <String, dynamic>{};
        final peerId =
            (map['socketId'] as String?) ?? (map['userId'] as String?);
        if (peerId != null) {
          _removePeerConnection(peerId);
        }
        // If no more peers remain, end the call.
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
      'audio': audio,
      'video': video
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
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
    };

    return pc;
  }

  // ── Offer / Answer ────────────────────────────────────────────────────────

  Future<void> _createOffer(String peerId) async {
    try {
      final pc = await _createPeerConnectionForPeer(peerId);
      final offer = await pc.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': _isVideoCall,
      });
      await pc.setLocalDescription(offer);

      _socket?.emit('webrtc:offer', {
        'roomId': _currentRoomId,
        'to': peerId,
        'sdp': offer.toMap(),
      });
      debugPrint('[WebRTC] Sent offer to peer $peerId');
    } catch (e) {
      debugPrint('[WebRTC] Error creating offer for $peerId: $e');
    }
  }

  Future<void> _handleOffer(
    Map<String, dynamic> sdpMap,
    String peerId,
  ) async {
    try {
      final pc = await _createPeerConnectionForPeer(peerId);
      final description =
          RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);
      await pc.setRemoteDescription(description);

      final answer = await pc.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': _isVideoCall,
      });
      await pc.setLocalDescription(answer);

      _socket?.emit('webrtc:answer', {
        'roomId': _currentRoomId,
        'to': peerId,
        'sdp': answer.toMap(),
      });
      debugPrint('[WebRTC] Sent answer to peer $peerId');

      await _drainPendingCandidates(peerId);
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
      ..off('call:ended')
      ..off('room:participant_left')
      ..off('error');
  }
}
