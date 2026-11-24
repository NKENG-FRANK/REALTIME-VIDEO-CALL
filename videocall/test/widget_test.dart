// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:videocall/config/api_config.dart';
import 'package:videocall/config/theme/app_theme.dart';
import 'package:videocall/core/l10n/app_localizations_delegate.dart';
import 'package:videocall/core/widgets/call/control_dock.dart';
import 'package:videocall/core/widgets/call/video_tile.dart';
import 'package:videocall/core/services/webrtc_call_service.dart';
import 'package:videocall/core/services/signaling_service.dart';
import 'package:videocall/core/services/contacts_service.dart';
import 'package:videocall/core/services/turn_credentials_service.dart';
import 'package:videocall/core/services/meeting_link_service.dart';
import 'package:videocall/features/call/presentation/pages/call_page.dart';
import 'package:videocall/features/call/presentation/pages/audio_call_page.dart';
import 'package:videocall/features/auth/presentation/controllers/auth_controller.dart';
import 'package:videocall/features/auth/presentation/pages/auth_page.dart';
import 'package:videocall/features/calls/presentation/controllers/calls_controller.dart';
import 'package:videocall/features/contacts/presentation/controllers/contacts_controller.dart';
import 'package:videocall/features/settings/presentation/controllers/settings_controller.dart';
import 'package:videocall/ui/callwave_workspace.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  test('Windows uses the local Docker services by default', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(ApiConfig.userManagementBaseUrl, 'http://localhost:3000/api/v1');
    expect(ApiConfig.audioCallsBaseUrl, 'ws://localhost:3001');
    expect(ApiConfig.videoCallsBaseUrl, 'ws://localhost:3002');
  });

  test('Android uses the configured LAN fallback by default', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(
      ApiConfig.registerUrl,
      'http://${ApiConfig.defaultLanIp}:3000/api/v1/auth/register',
    );
  });

  test('signaling reconnects with a changed authentication token', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final tokens = <String>[];
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.add(
        '0${jsonEncode({'sid': 'engine-session', 'upgrades': <String>[], 'pingInterval': 25000, 'pingTimeout': 20000, 'maxPayload': 1000000})}',
      );
      socket.listen((message) {
        if (message is String && message.startsWith('40')) {
          tokens.add(jsonDecode(message.substring(2))['token'] as String);
          socket.add('40${jsonEncode({'sid': 'socket-session'})}');
        }
      });
    });
    final signaling = SignalingService(
      serverUrl: 'http://127.0.0.1:${server.port}',
    );
    addTearDown(() async {
      signaling.dispose();
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
    });

    Future<void> waitForConnection() async {
      if (signaling.isConnected) return;
      final connected = Completer<void>();
      void listener() {
        if (signaling.isConnected && !connected.isCompleted)
          connected.complete();
      }

      signaling.addListener(listener);
      try {
        await connected.future.timeout(const Duration(seconds: 5));
      } finally {
        signaling.removeListener(listener);
      }
    }

    await signaling.connect('first-token');
    await waitForConnection();
    await signaling.connect('second-token');
    await waitForConnection();
    expect(tokens, ['first-token', 'second-token']);

    SharedPreferences.setMockInitialValues({});
    signaling.disconnect();
    await signaling.ensureConnected();
    expect(signaling.isConnected, isFalse);
  });

  test('TURN credentials require a valid authenticated response', () async {
    final endpoint = Uri.parse('https://example.test/turn-credentials');
    final expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300;
    final client = MockClient((request) async {
      expect(request.url, endpoint);
      expect(request.headers['Authorization'], 'Bearer test-token');
      return http.Response(
        jsonEncode({
          'urls': ['turn:example.test:3478?transport=udp'],
          'username': 'temporary-user',
          'credential': 'temporary-password',
          'expiresAt': expiresAt,
        }),
        200,
      );
    });
    final credentials = await TurnCredentialsService.fetch(
      token: 'test-token',
      client: client,
      endpoint: endpoint,
    );
    expect(credentials?['username'], 'temporary-user');
    expect(credentials?['urls'], ['turn:example.test:3478?transport=udp']);
    client.close();

    final expired = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'urls': ['turn:example.test:3478'],
          'username': 'temporary-user',
          'credential': 'temporary-password',
          'expiresAt': 1,
        }),
        200,
      ),
    );
    expect(
      await TurnCredentialsService.fetch(
        token: 'test-token',
        client: expired,
        endpoint: endpoint,
      ),
      isNull,
    );
    expired.close();

    final unavailable = MockClient((_) async => http.Response('', 503));
    expect(
      await TurnCredentialsService.fetch(
        token: 'test-token',
        client: unavailable,
        endpoint: endpoint,
      ),
      isNull,
    );
    unavailable.close();
  });

  test('room IDs are unpredictable UUIDv4 capabilities', () {
    final first = MeetingLinkService.createRoomId();
    final second = MeetingLinkService.createRoomId();
    expect(MeetingLinkService.isValidRoomId(first), isTrue);
    expect(MeetingLinkService.isValidRoomId(second), isTrue);
    expect(first, isNot(second));
    expect(MeetingLinkService.isValidRoomId('group-123456'), isFalse);
  });

  testWidgets('mobile auth switches forms and fits a keyboard-sized viewport', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const AuthPage(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Callwave'), findsOneWidget);
    expect(tester.takeException(), isNull);
    auth.toggleAuthMode();
    await tester.pump(const Duration(milliseconds: 400));
    tester.view.physicalSize = const Size(320, 400);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });

  testWidgets(
    'mobile audio shows caller and prototype controls without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: AudioCallPage(
            roomId: 'test',
            contactName: 'Amina Nkemba',
            callService: _UiCallService(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Amina Nkemba'), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('mobile group video renders spotlight, strip and participants', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: CallPage(
          roomId: MeetingLinkService.createRoomId(),
          isGroupCall: true,
          callService: _UiCallService(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(VideoTile), findsNWidgets(2));
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Participants'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Participants · 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('mobile workspace uses Recent and Contacts without overflow', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController()),
          ChangeNotifierProvider(create: (_) => CallsController()),
          ChangeNotifierProvider(create: (_) => ContactsController()),
          ChangeNotifierProvider(create: (_) => SettingsController()),
        ],
        child: const _LocalizedWorkspaceTestApp(),
      ),
    );
    await tester.pump();
    expect(find.text('Récents'), findsOneWidget);
    expect(find.byTooltip('Nouvel appel vidéo'), findsOneWidget);
    await tester.tap(find.text('Contacts'));
    await tester.pump();
    expect(find.text('Aucun contact enregistré'), findsOneWidget);
    await tester.tap(find.text('Personnes'));
    await tester.pump();
    expect(find.text('Ajouter des personnes'), findsOneWidget);
    expect(find.byTooltip('Ajouter manuellement'), findsOneWidget);
    await tester.tap(find.byTooltip('Ajouter manuellement'));
    await tester.pump();
    expect(find.text('Ajouter par matricule'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Rejoindre'));
    await tester.pump();
    expect(find.text('Code de salle ou lien'), findsOneWidget);
    await tester.tap(find.text('Paramètres'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Anglais'));
    await tester.tap(find.text('Anglais'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('APPEARANCE & LANGUAGE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final workspaceContext = tester.element(find.byType(CallwaveWorkspace));
    await workspaceContext.read<SettingsController>().updateAppearance(
      language: 'French',
    );
    await tester.pump();
    await tester.pump();
    final auth = workspaceContext.read<AuthController>();
    auth.updateMatricule('A1234567');
    auth.updatePassword('password');
    await tester.ensureVisible(
      find.widgetWithIcon(OutlinedButton, Icons.logout_rounded),
    );
    await tester.tap(find.widgetWithIcon(OutlinedButton, Icons.logout_rounded));
    await tester.pump();
    expect(find.text('Confirmer la déconnexion'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(auth.matricule, 'A1234567');
    await tester.tap(find.widgetWithIcon(OutlinedButton, Icons.logout_rounded));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Déconnexion'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(auth.matricule, isEmpty);
    expect(auth.password, isEmpty);
    expect(find.text('Signed out'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CallwaveWorkspace), findsNothing);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('mobile video tile fallback and dock controls render', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var muted = false;
    var ended = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(
                child: VideoTile(
                  renderer: null,
                  name: 'Remote peer',
                  initials: 'RP',
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: ControlDock(
                  actions: [
                    CallDockAction(
                      icon: Icons.mic_off_rounded,
                      label: 'Mute',
                      onPressed: () => muted = true,
                    ),
                    CallDockAction(
                      icon: Icons.call_end_rounded,
                      label: 'End call',
                      isEnd: true,
                      onPressed: () => ended = true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('RP'), findsOneWidget);
    expect(find.text('Remote peer'), findsOneWidget);
    await tester.tap(find.byTooltip('Mute'));
    await tester.tap(find.byTooltip('End call'));
    expect(muted, isTrue);
    expect(ended, isTrue);
  });

  testWidgets('desktop directory cards show contact details and actions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(860, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController()),
          ChangeNotifierProvider(create: (_) => CallsController()),
          ChangeNotifierProvider<ContactsController>(
            create: (_) => _DirectoryContactsController(),
          ),
          ChangeNotifierProvider(create: (_) => SettingsController()),
        ],
        child: const _LocalizedWorkspaceTestApp(initialPage: 'people'),
      ),
    );
    await tester.pump();
    expect(find.text('Amina Nkemba'), findsOneWidget);
    expect(find.text('A2041873'), findsOneWidget);
    expect(find.text('Finance'), findsOneWidget);
    expect(find.byTooltip('Appel audio'), findsNWidgets(2));
    expect(find.byTooltip('Appel vidéo'), findsNWidgets(2));
    expect(find.text('Ajouté'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter'));
    await tester.pump();
    expect(find.text('Ajouté'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('workspace navigates between Calls, People, and Settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController()),
          ChangeNotifierProvider(create: (_) => CallsController()),
          ChangeNotifierProvider(create: (_) => ContactsController()),
          ChangeNotifierProvider(create: (_) => SettingsController()),
        ],
        child: const _LocalizedWorkspaceTestApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Vos conversations récentes'), findsOneWidget);
    expect(find.text('Manqués'), findsOneWidget);

    await tester.tap(find.text('Personnes').first);
    await tester.pump();
    expect(find.text('Vos contacts'), findsOneWidget);

    await tester.tap(find.text('Paramètres').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Apparence et langue'), findsOneWidget);

    await tester.ensureVisible(find.text('Anglais'));
    await tester.pump();
    await tester.tap(find.text('Anglais'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('Appearance & Language'), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);

    await tester.ensureVisible(find.byTooltip('Edit name'));
    await tester.pump();
    await tester.tap(find.byTooltip('Edit name'));
    await tester.pump();
    expect(find.text('Edit profile name'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(
      find.widgetWithIcon(OutlinedButton, Icons.logout_rounded),
    );
    expect(find.widgetWithText(OutlinedButton, 'Log Out'), findsOneWidget);
    await tester.tap(find.widgetWithIcon(OutlinedButton, Icons.logout_rounded));
    await tester.pump();
    expect(find.text('Confirm Logout'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}

class _UiCallService extends WebRTCCallService {
  @override
  void dispose() {
    try {
      super.dispose();
    } catch (error) {
      if (error != 'Call initialize before setting the stream') rethrow;
    }
  }
}

class _DirectoryContactsController extends ContactsController {
  final List<ContactItem> people = [
    ContactItem(
      id: 'one',
      username: 'amina',
      matricule: 'A2041873',
      displayName: 'Amina Nkemba',
      department: 'Finance',
    ),
    ContactItem(
      id: 'two',
      username: 'user',
      matricule: 'B1234567',
      displayName: 'Second Contact',
    ),
  ];
  bool firstSaved = false;

  @override
  List<ContactItem> get currentList => people;
  @override
  List<ContactItem> get savedContacts => [people[1], if (firstSaved) people[0]];
  @override
  String get selectedTab => 'All Users';
  @override
  bool get isLoading => false;
  @override
  Future<void> refreshData() async {}
  @override
  Future<bool> saveContact(ContactItem item) async {
    firstSaved = true;
    notifyListeners();
    return true;
  }
}

class _LocalizedWorkspaceTestApp extends StatelessWidget {
  const _LocalizedWorkspaceTestApp({this.initialPage = 'calls'});

  final String initialPage;

  @override
  Widget build(BuildContext context) => Consumer<SettingsController>(
    builder: (context, settings, _) {
      final locale = settings.settings.language == 'English'
          ? const Locale('en')
          : const Locale('fr');
      return MaterialApp(
        theme: AppTheme.lightTheme(),
        locale: locale,
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: CallwaveWorkspace(initialPage: initialPage),
        routes: {
          '/auth': (_) =>
              const Scaffold(body: Center(child: Text('Signed out'))),
        },
      );
    },
  );
}
