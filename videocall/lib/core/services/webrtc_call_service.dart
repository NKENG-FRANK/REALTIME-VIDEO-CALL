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
  
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  CallState _callState = CallState.idle;
  CallState get callState => _callState;

  bool _isMicMuted = false;
  bool get isMicMuted => _isMicMuted;

  bool _isVideoOff = false;
  bool get isVideoOff => _isVideoOff;

  String? _currentRoomId;

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

    _socket!.on('room:joined', (data) {
      debugPrint('[WebRTC] Joined room: $data');
      _callState = CallState.connected;
      notifyListeners();
    });

    _socket!.on('room:participant_joined', (data) {
      debugPrint('[WebRTC] Participant joined: $data');
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
    if (_currentRoomId != null) {
      _socket?.emit('call:end', {
        'roomId': _currentRoomId,
        'durationSeconds': 0,
      });
    }

    _callState = CallState.ended;

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
      _callState = CallState.idle;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    localRenderer.dispose();
    remoteRenderer.dispose();
    _socket?.dispose();
    super.dispose();
  }
}
