class ApiConfig {
  // Base URLs for microservices
  // Default points to localhost for local testing (can be updated for device/emulator IP)
  static const String userManagementBaseUrl = 'http://localhost:3000/api/v1';
  static const String audioCallsBaseUrl = 'ws://localhost:3001';
  static const String videoCallsBaseUrl = 'ws://localhost:3002';

  // Specific Endpoint Routes
  static String get loginUrl => '$userManagementBaseUrl/auth/login';
  static String get registerUrl => '$userManagementBaseUrl/auth/register';
  static String get profileUrl => '$userManagementBaseUrl/users/profile';
  static String get contactsUrl => '$userManagementBaseUrl/contacts';
  static String get callLogsUrl => '$userManagementBaseUrl/calls';
}
