import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/theme/app_theme.dart';
import 'core/l10n/app_localizations.dart';
import 'core/l10n/app_localizations_delegate.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
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
      ],
      child: Builder(
        builder: (context) {
          // Wire AuthController → SettingsController so profile data from the
          // backend is seeded into settings after every login / app restart.
          final authCtrl = context.read<AuthController>();
          final settingsCtrl = context.read<SettingsController>();
          authCtrl.onUserLoaded = (user) => settingsCtrl.seedFromUser(user);

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

                home: const AuthPage(),
                debugShowCheckedModeBanner: false,
                routes: {
                  '/auth': (context) => const AuthPage(),
                  '/calls': (context) => const CallsHistoryPage(),
                  '/contacts': (context) => const ContactsPage(),
                  '/settings': (context) => const SettingsPage(),
                  '/incoming-call': (context) => const IncomingCallPage(),
                  '/connecting': (context) => const ConnectingPage(),
                  '/call': (context) => const CallPage(),
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
