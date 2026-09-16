import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme/app_theme.dart';
import 'ui/home_page.dart';
// Duplicate import removed
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
      child: MaterialApp(
        title: 'Callwave',
        theme: AppTheme.lightTheme(),
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
      ),
    );
  }
}
