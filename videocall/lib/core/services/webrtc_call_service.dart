import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../config/api_config.dart';

enum CallState { idle, connecting, connected, ended }

class WebRTCCallService extends ChangeNotifier {
  io.Socket? _socket;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCPeerConnection? _peerConnection;
  bool _isFirstPeer =
      false; // true if we joined a room with no other participants
  final List<RTCIceCandidate> _pendingCandidates =
      []; // buffered until remote desc is set

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  bool _disposed = false;
  CallState _callState = CallState.idle;
  CallState get callState => _callState;

  void _safeNotify() {
    if (!_disposed) {
      Future.microtask(notifyListeners);
    }
  }

  bool _isMicMuted = false;
  bool get isMicMuted => _isMicMuted;

  bool _isVideoOff = false;
  bool get isVideoOff => _isVideoOff;

  String? _currentRoomId;

  DateTime? _callStartTime;
  String get formattedDuration {
    if (_callStartTime == null) return '00:05';
    final duration = DateTime.now().difference(_callStartTime!);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject'
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject'
      }
    ],
    'sdpSemantics': 'unified-plan',
  };

  late final Future<void> _initRenderersFuture = _initRenderers();

  WebRTCCallService() {
    _initRenderersFuture;
  }

  Future<void> _initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future<void> _drainPendingCandidates() async {
    if (_peerConnection == null) return;
    final candidatesToDrain = List<RTCIceCandidate>.from(_pendingCandidates);
    _pendingCandidates.clear();
    debugPrint(
      '[WebRTC] Draining ${candidatesToDrain.length} pending ICE candidate(s)',
    );
    for (final candidate in candidatesToDrain) {
      try {
        await _peerConnection!.addCandidate(candidate);
        debugPrint(
          '[WebRTC] Added pending ICE candidate: ${candidate.toMap()}',
        );
      } catch (e) {
        debugPrint('[WebRTC] Error adding pending ICE candidate: $e');
      }
    }
  }

  /// Connect to the Video Calls microservice socket
  Future<void> initializeSocket(String userToken) async {
    if (_socket != null && _socket!.connected) return;

    _socket = io.io(
      ApiConfig.videoCallsBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': userToken})
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[WebRTC] Connected to Video Calls Socket.io server');
    });

    _socket!.onDisconnect((_) {
      debugPrint('[WebRTC] Disconnected from Video Calls Socket.io server');
    });

    _socket!.on('room:joined', (data) async {
      debugPrint('[WebRTC] Joined room: $data');
      _callState = CallState.connected;
      _callStartTime = DateTime.now();
      _safeNotify();

      final map = data as Map<String, dynamic>?;
      final existingParticipants = map?['participants'] as List?;
      if (existingParticipants != null && existingParticipants.isNotEmpty) {
        // We are the second peer (callee).
        // Wait for the caller to send the offer. DO NOT create an offer here.
        _isFirstPeer = false;
      } else {
        // We are the first peer (caller). Wait for 'room:participant_joined'.
        _isFirstPeer = true;
      }
    });

    _socket!.on('room:participant_joined', (data) async {
      debugPrint('[WebRTC] Participant joined: $data');
      // Create an offer only if we are the first peer and don't have a peer connection yet
      if (_isFirstPeer && _peerConnection == null) {
        await _createOffer();
      }
    });

    _socket!.on('webrtc:offer', (data) async {
      debugPrint('[WebRTC] Received WebRTC offer');
      final map = data as Map<String, dynamic>;
      final sdpMap = map['sdp'] as Map<String, dynamic>;
      await _handleOffer(sdpMap);
    });

    _socket!.on('webrtc:answer', (data) async {
      debugPrint('[WebRTC] Received WebRTC answer');
      if (_peerConnection == null) return;
      final map = data as Map<String, dynamic>;
      final sdpMap = map['sdp'] as Map<String, dynamic>;
      final description = RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);
      await _peerConnection!.setRemoteDescription(description);
      await _drainPendingCandidates();
    });

    _socket!.on('webrtc:candidate', (data) async {
      debugPrint('[WebRTC] <<< Remote ICE candidate arrived: $data');
      final map = data as Map<String, dynamic>;
      final candidateMap = map['candidate'] as Map<String, dynamic>?;
      if (candidateMap == null) return;
      final candidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );

      if (_peerConnection != null) {
        final remoteDesc = await _peerConnection!.getRemoteDescription();
        if (remoteDesc != null) {
          try {
            await _peerConnection!.addCandidate(candidate);
            debugPrint('[WebRTC] Added remote ICE candidate directly');
            return;
          } catch (e) {
            debugPrint('[WebRTC] Error adding candidate directly: $e');
          }
        }
      }
      debugPrint(
        '[WebRTC] Remote description not set yet, buffering ICE candidate',
      );
      _pendingCandidates.add(candidate);
    });

    _socket!.on('call:ended', (data) {
      debugPrint('[WebRTC] Call ended by server/peer: $data');
      endCall();
    });

    _socket!.on('room:participant_left', (data) {
      debugPrint('[WebRTC] Participant left: $data');
      endCall();
    });

    _socket!.on('error', (data) {
      debugPrint('[WebRTC] Socket Error: $data');
    });

    _socket!.connect();
  }

  /// Start local camera & microphone media streams
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
      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );
      localRenderer.srcObject = _localStream;
      _safeNotify();
    } catch (e) {
      debugPrint('[WebRTC] Error getting user media: $e');
    }
  }

  /// Join a call room (1-on-1 direct call)
  Future<void> joinCallRoom(String roomId, {bool isVideoCall = true}) async {
    _currentRoomId = roomId;
    _callState = CallState.connecting;
    _safeNotify();

    await _initRenderersFuture;
    await startLocalMedia(video: isVideoCall, audio: true);

    if (_socket != null && !_socket!.connected) {
      debugPrint(
        '[WebRTC] Socket not connected yet, waiting for connection...',
      );
      _socket!.connect();
      int waitMs = 0;
      while (!_socket!.connected && waitMs < 5000) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitMs += 100;
      }
    }

    debugPrint(
      '[WebRTC] Emitting room:join for room $roomId (connected: ${_socket?.connected})',
    );
    _socket?.emit('room:join', {
      'roomId': roomId,
      'callType': isVideoCall ? 'DIRECT_VIDEO' : 'DIRECT_AUDIO',
    });
  }

  /// Setup RTCPeerConnection and local/remote track handlers
  Future<void> _createPeerConnection() async {
    if (_peerConnection != null) return;

    _peerConnection = await createPeerConnection(_iceServers);

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }

    _peerConnection!.onTrack = (RTCTrackEvent event) async {
      debugPrint(
        '[WebRTC] Remote track received: ${event.track.kind}, streams: ${event.streams.length}',
      );
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
      } else {
        _remoteStream ??= await createLocalMediaStream('remote_stream');
        await _remoteStream!.addTrack(event.track);
      }
      remoteRenderer.srcObject = _remoteStream;
      _safeNotify();
    };

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (_currentRoomId != null && candidate.candidate != null) {
        debugPrint('[WebRTC] >>> Sending ICE candidate: ${candidate.toMap()}');
        _socket?.emit('webrtc:candidate', {
          'roomId': _currentRoomId,
          'candidate': candidate.toMap(),
        });
      }
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('[WebRTC] ICE Connection State: $state');
    };
  }

  /// Create and send WebRTC SDP Offer
  Future<void> _createOffer() async {
    try {
      await _createPeerConnection();
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await _peerConnection!.setLocalDescription(offer);

      _socket?.emit('webrtc:offer', {
        'roomId': _currentRoomId,
        'sdp': offer.toMap(),
      });
    } catch (e) {
      debugPrint('[WebRTC] Error creating offer: $e');
    }
  }

  /// Handle incoming WebRTC SDP Offer and respond with SDP Answer
  Future<void> _handleOffer(Map<String, dynamic> sdpMap) async {
    try {
      await _createPeerConnection();
      final description = RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);
      await _peerConnection!.setRemoteDescription(description);

      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await _peerConnection!.setLocalDescription(answer);

      _socket?.emit('webrtc:answer', {
        'roomId': _currentRoomId,
        'sdp': answer.toMap(),
      });

      await _drainPendingCandidates();
    } catch (e) {
      debugPrint('[WebRTC] Error handling offer: $e');
    }
  }

  /// Toggle Microphone Mute
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

  /// Toggle Camera Stream On/Off
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

  /// Switch front/rear camera
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        await Helper.switchCamera(videoTrack);
      }
    }
  }

  /// End Call and Release Resources
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

    try {
      await _peerConnection?.close();
      await _peerConnection?.dispose();
    } catch (e) {
      debugPrint('[WebRTC] Error closing peer connection: $e');
    }
    _peerConnection = null;
    _pendingCandidates.clear();

    try {
      _localStream?.getTracks().forEach((track) => track.stop());
      await _localStream?.dispose();
    } catch (e) {
      debugPrint('[WebRTC] Error disposing local stream: $e');
    }
    _localStream = null;
    localRenderer.srcObject = null;

    try {
      _remoteStream?.getTracks().forEach((track) => track.stop());
      await _remoteStream?.dispose();
    } catch (e) {
      debugPrint('[WebRTC] Error disposing remote stream: $e');
    }
    _remoteStream = null;
    remoteRenderer.srcObject = null;

    _currentRoomId = null;
    _safeNotify();

    // Reset state back to idle after delay
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
    _peerConnection?.close();
    _peerConnection?.dispose();
    localRenderer.dispose();
    remoteRenderer.dispose();
    _socket?.dispose();
    super.dispose();
  }

  /// Detach all socket event listeners to prevent stray notifications after the page is disposed.
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
