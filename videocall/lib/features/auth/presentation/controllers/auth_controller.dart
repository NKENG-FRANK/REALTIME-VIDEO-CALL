import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/auth_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  /// Optional callback invoked after a successful login/auth-check with the
  /// user profile map and JWT token. Use this to seed other controllers
  /// (e.g. SettingsController, SignalingService) without creating hard dependencies.
  Function(Map<String, dynamic> user, String token)? onUserLoaded;

  // UI State
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _showPassword = false;
  bool _rememberMe = true;
  bool _isAuthenticated = false;
  String? _errorMessage;

  // Form data
  String _matricule = '';
  String _password = '';
  String _fullName = '';
  
  Map<String, dynamic>? _currentUser;

  AuthController() {
    // Defer auth check until after the first frame so that main.dart's Builder
    // has time to assign `onUserLoaded` before we try to call it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthStatus();
    });
  }

  Future<void> _checkAuthStatus() async {
    final token = await AuthService.getToken();
    if (token != null) {
      _isAuthenticated = true;
      _currentUser = await AuthService.getCurrentUser();
      if (_currentUser != null) {
        onUserLoaded?.call(_currentUser!, token);
      }
      notifyListeners();
    }
  }

  // Getters
  bool get isSignUp => _isSignUp;
  bool get isLoading => _isLoading;
  bool get showPassword => _showPassword;
  bool get rememberMe => _rememberMe;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get currentUser => _currentUser;

  void updateUserData(Map<String, dynamic> userMap) {
    _currentUser = userMap;
    AuthService.getCurrentUser().then((stored) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(userMap));
    });
    notifyListeners();
  }


  String get matricule => _matricule;
  String get password => _password;
  String get fullName => _fullName;

  // Validate matricule format: Exactly 8 characters, letter at start or end (e.g., A1234567 or 1234567A)
  static bool isValidMatricule(String value) {
    final trimmed = value.trim();
    if (trimmed.length != 8) return false;
    final regex = RegExp(r'^(?:[A-Za-z]\d{7}|\d{7}[A-Za-z])$');
    return regex.hasMatch(trimmed);
  }

  void toggleAuthMode() {
    _isSignUp = !_isSignUp;
    _errorMessage = null;
    _clearForm();
    notifyListeners();
  }

  void togglePasswordVisibility() {
    _showPassword = !_showPassword;
    notifyListeners();
  }

  void toggleRememberMe() {
    _rememberMe = !_rememberMe;
    notifyListeners();
  }

  void updateMatricule(String value) {
    _matricule = value;
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void updatePassword(String value) {
    _password = value;
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void updateFullName(String value) {
    _fullName = value;
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Sign In against backend user-management service
  Future<bool> signIn() async {
    _errorMessage = null;

    if (_matricule.trim().isEmpty || _password.isEmpty) {
      _errorMessage = 'Matricule and password are required';
      notifyListeners();
      return false;
    }

    if (!isValidMatricule(_matricule)) {
      _errorMessage = 'Incorrect matricule format (must be 8 chars with 1 letter at start or end, e.g. A1234567)';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authService.login(_matricule, _password);

      if (result['success'] == true) {
        _isAuthenticated = true;
        _errorMessage = null;
        _currentUser = result['user'];
        final token = result['token'] as String? ?? '';
        if (_currentUser != null) {
          onUserLoaded?.call(_currentUser!, token);
        }
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Sign in failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Network connection error: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign Up against backend user-management service
  Future<bool> signUp() async {
    _errorMessage = null;

    if (_fullName.trim().isEmpty || _matricule.trim().isEmpty || _password.isEmpty) {
      _errorMessage = 'All fields are required';
      notifyListeners();
      return false;
    }

    if (!isValidMatricule(_matricule)) {
      _errorMessage = 'Incorrect matricule format (must be 8 chars with 1 letter at start or end, e.g. A1234567)';
      notifyListeners();
      return false;
    }

    if (_password.length < 6) {
      _errorMessage = 'Password must be at least 6 characters';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final nameParts = _fullName.trim().split(' ');
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'User';
      final username = _matricule.trim().toLowerCase();

      final result = await _authService.register(
        username: username,
        matricule: _matricule.trim(),
        password: _password,
        firstName: firstName,
        lastName: lastName,
      );

      if (result['success'] == true) {
        // Auto-login after registration
        return await signIn();
      } else {
        _errorMessage = result['message'] ?? 'Sign up failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Registration error: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void signOut() async {
    await AuthService.logout();
    _isAuthenticated = false;
    _currentUser = null;
    _clearForm();
    notifyListeners();
  }

  void _clearForm() {
    _matricule = '';
    _password = '';
    _fullName = '';
    _showPassword = false;
    _errorMessage = null;
  }
}
