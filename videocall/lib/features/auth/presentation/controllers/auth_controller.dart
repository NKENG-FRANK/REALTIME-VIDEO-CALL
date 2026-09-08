import 'package:flutter/material.dart';

class AuthController extends ChangeNotifier {
  // UI State
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _showPassword = false;
  bool _rememberMe = true;

  // Form data
  String _email = '';
  String _password = '';
  String _fullName = '';

  // Getters
  bool get isSignUp => _isSignUp;
  bool get isLoading => _isLoading;
  bool get showPassword => _showPassword;
  bool get rememberMe => _rememberMe;

  String get email => _email;
  String get password => _password;
  String get fullName => _fullName;

  // Toggle between Sign In and Sign Up
  void toggleAuthMode() {
    _isSignUp = !_isSignUp;
    _clearForm();
    notifyListeners();
  }

  // Toggle password visibility
  void togglePasswordVisibility() {
    _showPassword = !_showPassword;
    notifyListeners();
  }

  // Toggle remember me
  void toggleRememberMe() {
    _rememberMe = !_rememberMe;
    notifyListeners();
  }

  // Update form fields
  void updateEmail(String value) {
    _email = value;
  }

  void updatePassword(String value) {
    _password = value;
  }

  void updateFullName(String value) {
    _fullName = value;
  }

  // Sign In
  Future<void> signIn() async {
    if (_email.isEmpty || _password.isEmpty) {
      print('Email and password required');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // TODO: Call backend API
      // await _authService.login(_email, _password);
      print('Sign In: $_email');
      
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));
      
    } catch (e) {
      print('Sign In Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign Up
  Future<void> signUp() async {
    if (_fullName.isEmpty || _email.isEmpty || _password.isEmpty) {
      print('All fields required');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // TODO: Call backend API
      // await _authService.register(_fullName, _email, _password);
      print('Sign Up: $_fullName, $_email');
      
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));
      
    } catch (e) {
      print('Sign Up Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear form
  void _clearForm() {
    _email = '';
    _password = '';
    _fullName = '';
    _showPassword = false;
  }
}
