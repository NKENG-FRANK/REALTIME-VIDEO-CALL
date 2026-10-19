import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../config/api_config.dart';

/// Service responsible for keeping a background worker active on mobile devices
/// to listen for incoming WebRTC calls even when the app is minimized or closed.
class BackgroundCallService {
  static const String notificationChannelId = 'callwave_foreground_service';
  static const int notificationId = 888;
  static const String pendingAcceptedCallKey = 'pending_accepted_call';
  static const String pendingIncomingCallKey = 'pending_incoming_call';
  static const String incomingCallChannelId = 'callwave_incoming_call_channel';
  static const int incomingCallNotificationId = 999;

  static final FlutterBackgroundService _service = FlutterBackgroundService();

  /// Whether the current platform is a desktop OS (handled by DesktopTrayService instead).
  static bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
       defaultTargetPlatform == TargetPlatform.linux ||
       defaultTargetPlatform == TargetPlatform.macOS);

  /// Initialize the background service and notification channels.
  /// Skips desktop platforms — those use [DesktopTrayService] for background
  /// call listening via the system tray + window_manager.
  static Future<void> initialize() async {
    if (kIsWeb || _isDesktop) return;

    // Request notification permissions for Android 13+
    try {
      await Permission.notification.request();
    } catch (e) {
      debugPrint('[BackgroundCallService] Notification permission error: $e');
    }

    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel foregroundChannel = AndroidNotificationChannel(
      notificationChannelId,
      'CallWave Background Listener',
      description: 'Maintains incoming call listener when the app is in the background',
      importance: Importance.low,
    );

    const AndroidNotificationChannel incomingChannel = AndroidNotificationChannel(
      incomingCallChannelId,
      'CallWave Incoming Calls',
      description: 'Incoming video and audio call notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(foregroundChannel);
    await androidPlugin?.createNotificationChannel(incomingChannel);

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onBackgroundServiceStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'CallWave is active',
        initialNotificationContent: 'Listening for incoming calls in background...',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onBackgroundServiceStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// Start the background listener (call when user logs in)
  static Future<void> start(String token) async {
    if (kIsWeb || _isDesktop) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);

    final isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
    } else {
      _service.invoke('update_token', {'token': token});
    }
  }

  /// Stop the background listener (call on logout)
  static Future<void> stop() async {
    if (kIsWeb || _isDesktop) return;
    _service.invoke('stop_service');
  }

  /// Check if there was an incoming call accepted via notification action / CallKit while the app was closed
  static Future<Map<String, dynamic>?> checkAndConsumeAcceptedCall() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(pendingAcceptedCallKey);
    if (raw != null) {
      await prefs.remove(pendingAcceptedCallKey);
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }

    // Also check active calls in FlutterCallkitIncoming
    try {
      final activeCalls = await FlutterCallkitIncoming.activeCalls();
      if (activeCalls.isNotEmpty) {
        final extra = activeCalls.first.extra;
        if (extra != null) {
          return Map<String, dynamic>.from(extra);
        }
      }
    } catch (e) {
      debugPrint('[BackgroundCallService] checkAndConsumeAcceptedCall error: $e');
    }

    return null;
  }

  /// Check if there is an unhandled incoming call (e.g. user clicked the notification to open ring page)
  static Future<Map<String, dynamic>?> checkAndConsumeIncomingCall() async {
    if (kIsWeb || _isDesktop) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(pendingIncomingCallKey);
    if (raw != null) {
      await prefs.remove(pendingIncomingCallKey);
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  /// Clear all incoming call notifications and pending states
  static Future<void> clearIncomingNotification() async {
    if (kIsWeb || _isDesktop) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingIncomingCallKey);
    await prefs.remove(pendingAcceptedCallKey);
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.cancel(id: incomingCallNotificationId);
    } catch (_) {}
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (_) {}
  }
}

/// iOS background fetch entry point
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// The main entry point executed in the separate background isolate by Android
@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Reference to background socket
  io.Socket? socket;
  String? currentToken;

  void updateNotification(String title, String content) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: title,
        content: content,
      );
    }
  }

  Future<void> connectSocket(String token) async {
    if (currentToken == token && socket != null && socket!.connected) {
      return;
    }

    currentToken = token;
    socket?.dispose();
    socket = null;

    final url = ApiConfig.videoCallsBaseUrl;
    debugPrint('[BackgroundService] Connecting to video-calls signaling: $url');

    socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableForceNew()
          .enableReconnection()
          .setReconnectionDelay(3000)
          .setReconnectionAttempts(999999)
          .build(),
    );

    socket!.onConnect((_) {
      debugPrint('[BackgroundService] Signaling connected!');
      updateNotification('CallWave Active', 'Ready to receive calls');
    });

    socket!.onDisconnect((_) {
      debugPrint('[BackgroundService] Signaling disconnected.');
      updateNotification('CallWave Active', 'Reconnecting to network...');
    });

    socket!.onConnectError((err) {
      debugPrint('[BackgroundService] Connection error: $err');
    });

    // ── Listen for Incoming Call from backend ──────────────────────────────
    socket!.on('call:incoming', (payload) async {
      debugPrint('[BackgroundService] Incoming call received: $payload');
      if (payload is! Map) return;

      final roomId = payload['roomId']?.toString() ?? '';
      final callerUserId = payload['callerUserId']?.toString() ?? '';
      final callerName = payload['callerName']?.toString() ?? 'Caller';
      final callerMatricule = payload['callerMatricule']?.toString() ?? '';
      final rawCallType = (payload['callType']?.toString() ?? '').toUpperCase();
      final isVideoCall = rawCallType.contains('VIDEO') || payload['isVideoCall'] == true || payload['isVideoCall'] == 'true';
      final isGroupCall = rawCallType.contains('GROUP') || payload['isGroupCall'] == true || payload['isGroupCall'] == 'true';
      final groupTitle = payload['groupTitle']?.toString();

      final callData = <String, dynamic>{
        'roomId': roomId,
        'callerUserId': callerUserId,
        'callerName': callerName,
        'callerMatricule': callerMatricule,
        'isVideoCall': isVideoCall,
        'isGroupCall': isGroupCall,
        'groupTitle': groupTitle,
        'callType': isVideoCall ? 'DIRECT_VIDEO' : 'DIRECT_AUDIO',
      };

      // Store pending incoming call so tapping notification in background opens the ring page directly
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        BackgroundCallService.pendingIncomingCallKey,
        jsonEncode(callData),
      );

      // Show high priority incoming call notification via flutter_local_notifications
      final localNotifications = FlutterLocalNotificationsPlugin();
      await localNotifications.show(
        id: BackgroundCallService.incomingCallNotificationId,
        title: callerName,
        body: isVideoCall ? 'Incoming Video Call...' : 'Incoming Audio Call...',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            BackgroundCallService.incomingCallChannelId,
            'CallWave Incoming Calls',
            channelDescription: 'Incoming video and audio call notifications',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.call,
            fullScreenIntent: true,
            visibility: NotificationVisibility.public,
            ongoing: true,
            autoCancel: false,
            actions: const [
              AndroidNotificationAction(
                'decline_call',
                'Decline',
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                'accept_call',
                'Accept',
                showsUserInterface: true,
                cancelNotification: true,
              ),
            ],
          ),
        ),
        payload: jsonEncode(callData),
      );

      // On iOS: CallKit handles the system lock screen incoming call UI
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final callParams = CallKitParams(
          id: roomId,
          nameCaller: callerName,
          appName: 'CallWave',
          avatar: 'https://i.pravatar.cc/150?u=$callerMatricule',
          handle: callerMatricule,
          type: isVideoCall ? 1 : 0,
          duration: 35000,
          extra: callData,
          ios: const IOSParams(
            iconName: 'CallWave',
            handleType: 'generic',
            supportsVideo: true,
            maximumCallGroups: 1,
            maximumCallsPerCallGroup: 1,
            audioSessionMode: 'videoChat',
            audioSessionActive: true,
          ),
        );
        await FlutterCallkitIncoming.showCallkitIncoming(callParams);
      }

      // Notify the foreground UI if it is listening
      service.invoke('call:incoming', callData);
    });

    // ── Listen for caller cancelling or ending call ────────────────────────
    socket!.on('call:cancelled', (payload) async {
      debugPrint('[BackgroundService] Call cancelled by caller');
      await BackgroundCallService.clearIncomingNotification();
      if (payload is Map) {
        service.invoke('call:cancelled', Map<String, dynamic>.from(payload));
      }
    });

    socket!.on('call:ended', (payload) async {
      debugPrint('[BackgroundService] Call ended');
      await BackgroundCallService.clearIncomingNotification();
      if (payload is Map) {
        service.invoke('call:ended', Map<String, dynamic>.from(payload));
      }
    });
  }

  // ── Listen for CallKit events (Accept / Decline on lock screen or popup) ──
  FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
    if (event == null) return;
    debugPrint('[BackgroundService] CallKit event: ${event.eventName}');

    switch (event) {
      case CallEventActionCallAccept(:final callKitParams):
        final extra = callKitParams.extra;
        if (extra != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            BackgroundCallService.pendingAcceptedCallKey,
            jsonEncode(extra),
          );
          service.invoke('call:accepted', extra);
        }
        break;

      case CallEventActionCallDecline(:final callKitParams):
        final extra = callKitParams.extra;
        final roomId = extra?['roomId']?.toString() ?? callKitParams.id;
        if (socket != null) {
          socket!.emit('call:decline', {'roomId': roomId});
        }
        await BackgroundCallService.clearIncomingNotification();
        service.invoke('call:declined', extra ?? {'roomId': roomId});
        break;

      case CallEventActionCallTimeout():
      case CallEventActionCallEnded():
        await FlutterCallkitIncoming.endAllCalls();
        break;

      default:
        break;
    }
  });

  // ── Service communication channels ───────────────────────────────────────
  service.on('update_token').listen((event) {
    final token = event?['token']?.toString();
    if (token != null && token.isNotEmpty) {
      connectSocket(token);
    }
  });

  service.on('stop_service').listen((_) async {
    socket?.dispose();
    socket = null;
    await FlutterCallkitIncoming.endAllCalls();
    service.stopSelf();
  });

  // Read initial stored token and connect
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  if (token != null && token.isNotEmpty) {
    await connectSocket(token);
  } else {
    updateNotification('CallWave Active', 'Waiting for login...');
  }
}
