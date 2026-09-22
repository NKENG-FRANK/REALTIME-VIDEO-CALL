import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  /// Login with matricule and password
  Future<Map<String, dynamic>> login(String matricule, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'matricule': matricule.trim(),
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['accessToken'] != null) {
        final token = data['accessToken'];
        final user = data['user'] ?? {'matricule': matricule};

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_userKey, jsonEncode(user));

        return {'success': true, 'user': user, 'token': token};
      } else {
        final errorMsg = data['error'] is String
            ? data['error']
            : (data['error']?['message'] ?? 'Login failed');

        return {
          'success': false,
          'message': errorMsg,
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to backend server. Make sure microservices are running.'};
    }
  }

  /// Register a new user account
  Future<Map<String, dynamic>> register({
    required String username,
    required String matricule,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.registerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username.trim(),
          'matricule': matricule.trim(),
          'password': password,
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          (data['accessToken'] != null || data['user'] != null)) {
        return {'success': true, 'message': 'Registration successful'};
      } else {
        final errorMsg = data['error'] is String
            ? data['error']
            : (data['error']?['message'] ?? 'Registration failed');

        return {
          'success': false,
          'message': errorMsg,
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to backend server.'};
    }
  }

  /// Get stored authentication token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Get cached current user data
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw != null) {
      return jsonDecode(raw);
    }
    return null;
  }

  /// Logout and clear stored session
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
