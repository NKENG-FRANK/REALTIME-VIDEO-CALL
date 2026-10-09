import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/theme/app_colors.dart';
import 'config/theme/app_theme.dart';
import 'core/l10n/app_localizations_delegate.dart';
import 'core/services/auth_service.dart';
import 'core/services/ringtone_service.dart';
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
                routes: {
                  '/auth': (context) => const AuthPage(),
                  '/calls': (context) => const CallsHistoryPage(),
                  '/contacts': (context) => const ContactsPage(),
                  '/settings': (context) => const SettingsPage(),
                  '/connecting': (context) => const ConnectingPage(),
                  '/call-ended': (context) => const CallEndedPage(),
                  // /incoming-call and /call are pushed programmatically with
                  // real data — not registered as static named routes anymore.
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
/// - While validating: displays a branded Callwave splash screen.
class _AppAuthResolver extends StatelessWidget {
  const _AppAuthResolver({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authCtrl = context.watch<AuthController>();

    // While verifying stored credentials on app launch
    if (authCtrl.isInitializing) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F7F4),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.phone_in_talk_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Callwave',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 22),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (authCtrl.isAuthenticated) {
      return const CallsHistoryPage();
    } else {
      return const AuthPage();
    }
  }
}
