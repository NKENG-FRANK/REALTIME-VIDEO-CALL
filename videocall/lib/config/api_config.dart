import 'package:flutter/foundation.dart';

class ApiConfig {
  // Network host of the machine running the backend services
  static const String serverHost = String.fromEnvironment('SERVER_IP', defaultValue: '10.105.180.95');
  static const bool isSecure = bool.fromEnvironment('IS_SECURE', defaultValue: false);

  static String get host => kIsWeb ? Uri.base.host : serverHost;
  static bool get _useSecure => kIsWeb
      ? (Uri.base.scheme.startsWith('https') || (!Uri.base.host.contains('192.168.') && !Uri.base.host.contains('10.') && Uri.base.host != 'localhost' && !kDebugMode))
      : (isSecure && !host.contains('192.168.') && !host.contains('10.') && host != 'localhost');
  static String get httpScheme => _useSecure ? 'https' : 'http';
  static String get wsScheme => _useSecure ? 'wss' : 'ws';

  // Base URLs for microservices
  // When running on web over HTTPS, use standard reverse proxy path on port 443
  static String get userManagementBaseUrl => (kIsWeb && _useSecure)
      ? 'https://$host/api/v1'
      : '$httpScheme://$host:3000/api/v1';

  static String get audioCallsBaseUrl => '$wsScheme://$host:3001';
  static String get videoCallsBaseUrl => '$wsScheme://$host:3002';

  // Specific Endpoint Routes
  static String get loginUrl => '$userManagementBaseUrl/auth/login';
  static String get registerUrl => '$userManagementBaseUrl/auth/register';
  static String get profileUrl => '$userManagementBaseUrl/users/profile';
  static String get contactsUrl => '$userManagementBaseUrl/contacts';
  static String get callLogsUrl => '$userManagementBaseUrl/calls';
}
