class ApiConfig {
  // Network IP address of the machine running the backend Docker containers
  static const String serverHost = String.fromEnvironment('SERVER_IP', defaultValue: '192.168.50.123');

  // Base URLs for microservices
  static String get userManagementBaseUrl => 'http://$serverHost:3000/api/v1';
  static String get audioCallsBaseUrl => 'ws://$serverHost:3001';
  static String get videoCallsBaseUrl => 'ws://$serverHost:3002';

  // Specific Endpoint Routes
  static String get loginUrl => '$userManagementBaseUrl/auth/login';
  static String get registerUrl => '$userManagementBaseUrl/auth/register';
  static String get profileUrl => '$userManagementBaseUrl/users/profile';
  static String get contactsUrl => '$userManagementBaseUrl/contacts';
  static String get callLogsUrl => '$userManagementBaseUrl/calls';
}
