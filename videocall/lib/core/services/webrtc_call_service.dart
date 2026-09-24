import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../config/api_config.dart';

enum CallState { idle, connecting, connected, ended }

class WebRTCCallService extends ChangeNotifier {
  IO.Socket? _socket;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCPeerConnection? _peerConnection;
  
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  bool _disposed = false;
  CallState _callState = CallState.idle;
  CallState get callState => _callState;

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
    ],
  };

  WebRTCCallService() {
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  /// Connect to the Video Calls microservice socket
  Future<void> initializeSocket(String userToken) async {
    if (_socket != null && _socket!.connected) return;

    _socket = IO.io(
      ApiConfig.videoCallsBaseUrl,
      IO.OptionBuilder()
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
      notifyListeners();

      final map = data as Map<String, dynamic>?;
      final existingParticipants = map?['participants'] as List?;
      if (existingParticipants != null && existingParticipants.isNotEmpty) {
        // We are joining a room with an existing peer, trigger offer
        await _createOffer();
      }
    });

    _socket!.on('room:participant_joined', (data) async {
      debugPrint('[WebRTC] Participant joined: $data');
      // Create peer connection & offer when new peer arrives
      await _createOffer();
    });

    _socket!.on('webrtc:offer', (data) async {
      debugPrint('[WebRTC] Received WebRTC offer');
      final map = data as Map<String, dynamic>;
      final sdpMap = map['sdp'] as Map<String, dynamic>;
      await _handleOffer(sdpMap);
    });

    _socket!.on('webrtc:answer', (data) async {
      debugPrint('[WebRTC] Received WebRTC answer');
      final map = data as Map<String, dynamic>;
      final sdpMap = map['sdp'] as Map<String, dynamic>;
      final description = RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);
      await _peerConnection?.setRemoteDescription(description);
    });

    _socket!.on('webrtc:candidate', (data) async {
      debugPrint('[WebRTC] Received ICE candidate');
      final map = data as Map<String, dynamic>;
      final candidateMap = map['candidate'] as Map<String, dynamic>?;
      if (candidateMap != null && _peerConnection != null) {
        final candidate = RTCIceCandidate(
          candidateMap['candidate'],
          candidateMap['sdpMid'],
          candidateMap['sdpMLineIndex'],
        );
        await _peerConnection?.addCandidate(candidate);
      }
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
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;
      notifyListeners();
    } catch (e) {
      debugPrint('[WebRTC] Error getting user media: $e');
    }
  }

  /// Join a call room (1-on-1 direct call)
  Future<void> joinCallRoom(String roomId, {bool isVideoCall = true}) async {
    _currentRoomId = roomId;
    _callState = CallState.connecting;
    notifyListeners();

    await startLocalMedia(video: isVideoCall, audio: true);

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

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      debugPrint('[WebRTC] Remote track received: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
        notifyListeners();
      }
    };

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (_currentRoomId != null && candidate.candidate != null) {
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
        notifyListeners();
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
        notifyListeners();
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

    try {
      await _peerConnection?.close();
      await _peerConnection?.dispose();
    } catch (e) {
      debugPrint('[WebRTC] Error closing peer connection: $e');
    }
    _peerConnection = null;

    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    _localStream = null;
    localRenderer.srcObject = null;

    _remoteStream?.getTracks().forEach((track) => track.stop());
    await _remoteStream?.dispose();
    _remoteStream = null;
    remoteRenderer.srcObject = null;

    _currentRoomId = null;
    notifyListeners();

    // Reset state back to idle after delay
    Future.delayed(const Duration(seconds: 1), () {
      if (_disposed) return;
      _callState = CallState.idle;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _peerConnection?.close();
    _peerConnection?.dispose();
    localRenderer.dispose();
    remoteRenderer.dispose();
    _socket?.dispose();
    super.dispose();
  }
}
