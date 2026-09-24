import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/theme/app_theme.dart';
import 'core/l10n/app_localizations_delegate.dart';
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
                home: const AuthPage(),
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
  const _GlobalIncomingCallListener({Key? key, required this.child}) : super(key: key);

  @override
  State<_GlobalIncomingCallListener> createState() => _GlobalIncomingCallListenerState();
}

class _GlobalIncomingCallListenerState extends State<_GlobalIncomingCallListener> {
  bool _showingIncomingCall = false;

  @override
  Widget build(BuildContext context) {
    // Listen to SignalingService for incoming call notifications
    final signaling = context.watch<SignalingService>();
    final incoming = signaling.incomingCall;

    if (incoming != null && !_showingIncomingCall) {
      _showingIncomingCall = true;
      // Push after the current frame so we don't call setState/Navigator
      // during a build cycle.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => IncomingCallPage(
              callerName: incoming.callerName,
              callerMatricule: incoming.callerMatricule,
              roomId: incoming.roomId,
              isVideoCall: incoming.isVideoCall,
              onAccept: () {
                // Log incoming accepted call
                final parts = incoming.callerName.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
                final initials = parts.isEmpty ? 'U' : (parts.length == 1 ? parts[0][0].toUpperCase() : '${parts[0][0]}${parts[1][0]}'.toUpperCase());
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
                );
                context.read<CallsController>().addCallLog(log);

                // Clear the notification first
                context.read<SignalingService>().clearIncomingCall();
                _showingIncomingCall = false;
                // Navigate to the call screen with real room data
                navigatorKey.currentState?.pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => CallPage(
                      callTitle: incoming.isVideoCall
                          ? 'Video Call – ${incoming.callerName}'
                          : 'Audio Call – ${incoming.callerName}',
                      roomId: incoming.roomId,
                    ),
                  ),
                );
              },
              onDecline: () {
                // Log incoming missed/declined call
                final parts = incoming.callerName.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
                final initials = parts.isEmpty ? 'U' : (parts.length == 1 ? parts[0][0].toUpperCase() : '${parts[0][0]}${parts[1][0]}'.toUpperCase());
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
        ).then((_) {
          // If the user dismisses via the back button, reset the flag
          _showingIncomingCall = false;
          if (mounted) {
            context.read<SignalingService>().clearIncomingCall();
          }
        });
      });
    }

    return widget.child;
  }
}

