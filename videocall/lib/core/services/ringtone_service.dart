import 'dart:io' show Platform, Process, ProcessSignal, File, Directory;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// Service managing incoming and outgoing call ringing:
/// - On mobile (Android / iOS): uses the device's native system ringtone via FlutterRingtonePlayer.
/// - On Linux desktop: uses the system's native canberra-gtk-play (phone-incoming-call) or pw-play / aplay.
/// - On macOS: uses afplay system audio.
class RingtoneService {
  static final RingtoneService _instance = RingtoneService._internal();
  factory RingtoneService() => _instance;
  RingtoneService._internal();

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  Process? _desktopProcess;

  /// Plays incoming call ringtone in a continuous loop.
  Future<void> playIncoming() async {
    if (_isPlaying) return;
    _isPlaying = true;

    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        debugPrint('[RingtoneService] Starting mobile device native ringtone');
        await FlutterRingtonePlayer().playRingtone(
          volume: 1.0,
          looping: true,
          asAlarm: false,
        );
      } else if (!kIsWeb && Platform.isLinux) {
        debugPrint('[RingtoneService] Starting Linux desktop incoming ringtone');
        _playLinuxRingtone();
      } else if (!kIsWeb && Platform.isMacOS) {
        debugPrint('[RingtoneService] Starting macOS desktop incoming ringtone');
        _playMacOSRingtone();
      }
    } catch (e) {
      debugPrint('[RingtoneService] Error playing ringtone: $e');
    }
  }

  /// Plays system ringtone on Linux desktop without requiring external CMake C++ libraries
  Future<void> _playLinuxRingtone() async {
    try {
      // 1. Try FreeDesktop system sound theme phone-incoming-call
      _desktopProcess = await Process.start(
        'canberra-gtk-play',
        ['-i', 'phone-incoming-call', '-l', '25'],
      );
      _desktopProcess?.exitCode.then((exitCode) {
        // If canberra sound was missing and we are still ringing, use fallback
        if (exitCode != 0 && _isPlaying) {
          _fallbackLinuxPlay();
        }
      });
    } catch (_) {
      _fallbackLinuxPlay();
    }
  }

  Future<void> _fallbackLinuxPlay() async {
    if (!_isPlaying) return;
    try {
      final tempDir = Directory.systemTemp.path;
      final tempFile = File('$tempDir/videocall_incoming_ring.wav');
      if (!tempFile.existsSync()) {
        final byteData = await rootBundle.load('assets/sounds/incoming_call.wav');
        await tempFile.writeAsBytes(byteData.buffer.asUint8List());
      }
      _desktopProcess = await Process.start('pw-play', [tempFile.path]);
      _desktopProcess?.exitCode.then((_) {
        if (_isPlaying) {
          _fallbackLinuxPlay();
        }
      });
    } catch (_) {
      try {
        final tempFile = File('${Directory.systemTemp.path}/videocall_incoming_ring.wav');
        _desktopProcess = await Process.start('aplay', [tempFile.path]);
        _desktopProcess?.exitCode.then((_) {
          if (_isPlaying) _fallbackLinuxPlay();
        });
      } catch (e) {
        debugPrint('[RingtoneService] Linux fallback audio failed: $e');
      }
    }
  }

  Future<void> _playMacOSRingtone() async {
    try {
      _desktopProcess = await Process.start('afplay', ['/System/Library/Sounds/Ping.aiff']);
      _desktopProcess?.exitCode.then((_) {
        if (_isPlaying) _playMacOSRingtone();
      });
    } catch (e) {
      debugPrint('[RingtoneService] macOS audio failed: $e');
    }
  }

  /// Stops any actively playing ringtone across all platforms.
  Future<void> stop() async {
    if (!_isPlaying) return;
    _isPlaying = false;

    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await FlutterRingtonePlayer().stop();
      }
      if (_desktopProcess != null) {
        _desktopProcess?.kill(ProcessSignal.sigkill);
        _desktopProcess = null;
      }
    } catch (e) {
      debugPrint('[RingtoneService] Error stopping ringtone: $e');
    }
  }
}
