import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/theme/app_colors.dart';
import 'config/theme/app_theme.dart';
import 'core/l10n/app_localizations_delegate.dart';
import 'core/services/auth_service.dart';
import 'core/services/ringtone_service.dart';
import 'core/services/meeting_link_service.dart';
import 'core/services/signaling_service.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/calls/domain/models/call_log.dart';
import 'features/calls/presentation/controllers/calls_controller.dart';
import 'features/contacts/presentation/controllers/contacts_controller.dart';
import 'features/settings/presentation/controllers/settings_controller.dart';
import 'features/auth/presentation/pages/auth_page.dart';
import 'features/calls/presentation/pages/calls_history_page.dart';
import 'features/contacts/presentation/pages/contacts_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/call/presentation/pages/incoming_call_page.dart';
import 'features/call/presentation/pages/connecting_page.dart';
import 'features/call/presentation/pages/call_page.dart';
import 'features/call/presentation/pages/audio_call_page.dart';
import 'features/call/presentation/pages/call_ended_page.dart';

/// Global navigator key — lets SignalingService push routes from outside the
/// widget tree (e.g. when an incoming call arrives while any screen is open).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => CallsController()),
        ChangeNotifierProvider(create: (_) => ContactsController()),
        ChangeNotifierProvider(create: (_) => SettingsController()),
        // Persistent signaling socket — connects right after login
        ChangeNotifierProvider(create: (_) => SignalingService()),
      ],
      child: Builder(
        builder: (context) {
          // Wire AuthController → SettingsController so profile data from the
          // backend is seeded into settings after every login / app restart.
          final authCtrl = context.read<AuthController>();
          final settingsCtrl = context.read<SettingsController>();
          final signalingService = context.read<SignalingService>();

          authCtrl.onUserLoaded = (user, token) {
            settingsCtrl.seedFromUser(user);
            // Connect the persistent signaling socket with the real JWT
            signalingService.connect(token);
          };

          if (authCtrl.isAuthenticated && !signalingService.isConnected) {
            AuthService.getToken().then((token) {
              if (token != null && token.isNotEmpty) {
                signalingService.connect(token);
              }
            });
          }

          // Consumer listens to SettingsController so locale updates immediately
          // when the user changes the language in Settings.
          return Consumer<SettingsController>(
            builder: (context, settingsCtrl, _) {
              final languageSetting = settingsCtrl.settings.language;
              final locale = languageSetting == 'English'
                  ? const Locale('en')
                  : const Locale('fr');

              return MaterialApp(
                title: 'Callwave',
                theme: AppTheme.lightTheme(),
                navigatorKey: navigatorKey,

                // ── Localization ─────────────────────────────────────────────
                locale: locale,
                supportedLocales: const [
                  Locale('fr'), // French (default)
                  Locale('en'), // English
                ],
                localizationsDelegates: const [
                  AppLocalizationsDelegate(),
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],

                builder: (context, child) {
                  return _GlobalIncomingCallListener(
                    child: child ?? const SizedBox.shrink(),
                  );
                },
                home: const _AppAuthResolver(),
                debugShowCheckedModeBanner: false,
                onGenerateRoute: (settings) {
                  final name = settings.name;
                  if (name != null) {
                    final uri = Uri.tryParse(name);
                    final path = uri?.path ?? '';
                    if (path == '/join' || path == 'join') {
                      final parsed = MeetingLinkService.parseInput(name);
                      if (parsed.roomId.isNotEmpty) {
                        final authCtrl = context.read<AuthController>();
                        if (authCtrl.isAuthenticated) {
                          return MaterialPageRoute(
                            builder: (_) => parsed.isVideo
                                ? CallPage(
                                    callTitle: parsed.title ?? 'Meeting ${parsed.roomId}',
                                    roomId: parsed.roomId,
                                    isVideoCall: true,
                                    isGroupCall: true,
                                    participantCount: 2,
                                  )
                                : AudioCallPage(
                                    callTitle: parsed.title ?? 'Meeting ${parsed.roomId}',
                                    roomId: parsed.roomId,
                                    contactName: parsed.title ?? 'Meeting',
                                    contactMatricule: parsed.roomId,
                                    isGroupCall: true,
                                    participantCount: 2,
                                  ),
                          );
                        } else {
                          MeetingLinkService.pendingJoinLink = parsed;
                          return MaterialPageRoute(builder: (_) => const AuthPage());
                        }
                      }
                    }
                  }
                  return null;
                },
                routes: {
                  '/auth': (context) => const AuthPage(),
                  '/calls': (context) => const CallsHistoryPage(),
                  '/contacts': (context) => const ContactsPage(),
                  '/settings': (context) => const SettingsPage(),
                  '/connecting': (context) => const ConnectingPage(),
                  '/call-ended': (context) => const CallEndedPage(),
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Global widget that wraps the navigator and listens for incoming calls
/// continuously — ensuring IncomingCallPage appears over any active screen.
class _GlobalIncomingCallListener extends StatefulWidget {
  final Widget child;
  const _GlobalIncomingCallListener({Key? key, required this.child})
    : super(key: key);

  @override
  State<_GlobalIncomingCallListener> createState() =>
      _GlobalIncomingCallListenerState();
}

class _GlobalIncomingCallListenerState
    extends State<_GlobalIncomingCallListener> {
  bool _showingIncomingCall = false;

  @override
  Widget build(BuildContext context) {
    // Listen to SignalingService for incoming call notifications
    final signaling = context.watch<SignalingService>();
    final incoming = signaling.incomingCall;

    if (incoming == null) {
      if (_showingIncomingCall) {
        _showingIncomingCall = false;
        RingtoneService().stop();
      }
    } else if (!_showingIncomingCall) {
      _showingIncomingCall = true;
      // Push after the current frame so we don't call setState/Navigator
      // during a build cycle.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState
            ?.push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => IncomingCallPage(
                  callerName: incoming.callerName,
                  callerMatricule: incoming.callerMatricule,
                  roomId: incoming.roomId,
                  isVideoCall: incoming.isVideoCall,
                  isGroupCall: incoming.isGroupCall,
                  groupTitle: incoming.groupTitle,
                  onAccept: () {
                    // Log incoming accepted call
                    final parts = incoming.callerName
                        .trim()
                        .split(RegExp(r'\s+'))
                        .where((e) => e.isNotEmpty)
                        .toList();
                    final initials = parts.isEmpty
                        ? 'U'
                        : (parts.length == 1
                              ? parts[0][0].toUpperCase()
                              : '${parts[0][0]}${parts[1][0]}'.toUpperCase());
                    final log = CallLog(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: incoming.callerName,
                      initials: initials,
                      colorValue: 0xFF8752F4,
                      time: 'Just now',
                      duration: 'Connected',
                      isOutgoing: false,
                      isMissed: false,
                      contactUserId: incoming.callerUserId,
                      isGroup: incoming.isGroupCall,
                    );
                    context.read<CallsController>().addCallLog(log);

                    // Clear the notification first
                    context.read<SignalingService>().clearIncomingCall();
                    _showingIncomingCall = false;
                    // Navigate to the call screen with real room data
                    navigatorKey.currentState?.pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => incoming.isVideoCall
                            ? CallPage(
                                callTitle: incoming.isGroupCall
                                    ? (incoming.groupTitle ?? 'Group Video Call')
                                    : 'Video Call – ${incoming.callerName}',
                                roomId: incoming.roomId,
                                isVideoCall: true,
                                isGroupCall: incoming.isGroupCall,
                                // participantCount is used only as an initial hint;
                                // the sidebar dynamically uses remoteRenderers.length
                                participantCount: 2,
                              )
                            : AudioCallPage(
                                callTitle: incoming.isGroupCall
                                    ? (incoming.groupTitle ?? 'Group Audio Call')
                                    : 'Audio Call – ${incoming.callerName}',
                                roomId: incoming.roomId,
                                contactName: incoming.callerName,
                                contactMatricule: incoming.callerMatricule,
                                isGroupCall: incoming.isGroupCall,
                                participantCount: 2,
                              ),
                      ),
                    );
                  },
                  onDecline: () {
                    // Log incoming missed/declined call
                    final parts = incoming.callerName
                        .trim()
                        .split(RegExp(r'\s+'))
                        .where((e) => e.isNotEmpty)
                        .toList();
                    final initials = parts.isEmpty
                        ? 'U'
                        : (parts.length == 1
                              ? parts[0][0].toUpperCase()
                              : '${parts[0][0]}${parts[1][0]}'.toUpperCase());
                    final log = CallLog(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: incoming.callerName,
                      initials: initials,
                      colorValue: 0xFF8752F4,
                      time: 'Just now',
                      duration: '',
                      isOutgoing: false,
                      isMissed: true,
                      contactUserId: incoming.callerUserId,
                      isGroup: incoming.isGroupCall,
                    );
                    context.read<CallsController>().addCallLog(log);

                    context.read<SignalingService>().declineCall(
                      incoming.callerUserId,
                      incoming.roomId,
                    );
                    _showingIncomingCall = false;
                  },
                ),
              ),
            )
            .then((_) {
              // If the user dismisses via the back button, reset the flag and stop ringtone
              _showingIncomingCall = false;
              RingtoneService().stop();
              if (mounted) {
                context.read<SignalingService>().clearIncomingCall();
              }
            });
      });
    }

    return widget.child;
  }
}

/// Automatically resolves startup navigation based on stored JWT validity:
/// - If token is active & valid: automatically opens CallsHistoryPage.
/// - If token is missing/expired: opens AuthPage.
/// - While validating: displays the Callwave splash screen with splach.png.
class _AppAuthResolver extends StatefulWidget {
  const _AppAuthResolver({Key? key}) : super(key: key);

  @override
  State<_AppAuthResolver> createState() => _AppAuthResolverState();
}

class _AppAuthResolverState extends State<_AppAuthResolver> {
  bool _minSplashElapsed = false;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    // On Windows or Linux, ensure splash screen is shown for at least 5 seconds
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux);
    final duration = isDesktop ? const Duration(seconds: 5) : const Duration(milliseconds: 1500);

    _splashTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _minSplashElapsed = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authCtrl = context.watch<AuthController>();

    // Show splash screen while initializing or until minimum 5 seconds on Windows/Linux has elapsed
    if (authCtrl.isInitializing || !_minSplashElapsed) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520, maxHeight: 220),
                  child: Image.asset(
                    'assets/logo/splach.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const Spacer(flex: 2),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Loading Callwave...',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      );
    }

    // Check if there is an incoming join target from web URL or deep-link
    final webJoin = MeetingLinkService.getInitialWebJoinTarget();
    if (webJoin != null && webJoin.roomId.isNotEmpty) {
      MeetingLinkService.pendingJoinLink = webJoin;
    }

    if (authCtrl.isAuthenticated) {
      final pending = MeetingLinkService.consumePendingJoin();
      if (pending != null && pending.roomId.isNotEmpty) {
        return pending.isVideo
            ? CallPage(
                callTitle: pending.title ?? 'Meeting ${pending.roomId}',
                roomId: pending.roomId,
                isVideoCall: true,
                isGroupCall: true,
                participantCount: 2,
              )
            : AudioCallPage(
                callTitle: pending.title ?? 'Meeting ${pending.roomId}',
                roomId: pending.roomId,
                contactName: pending.title ?? 'Meeting',
                contactMatricule: pending.roomId,
                isGroupCall: true,
                participantCount: 2,
              );
      }
      return const CallsHistoryPage();
    } else {
      return const AuthPage();
    }
  }
}
