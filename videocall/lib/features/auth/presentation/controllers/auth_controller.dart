import 'package:flutter/material.dart';

class AuthController extends ChangeNotifier {
  // UI State
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _showPassword = false;
  bool _rememberMe = true;
  bool _isAuthenticated = false;

  // Form data
  String _matricule = '';
  String _password = '';
  String _fullName = '';

  // Getters
  bool get isSignUp => _isSignUp;
  bool get isLoading => _isLoading;
  bool get showPassword => _showPassword;
  bool get rememberMe => _rememberMe;
  bool get isAuthenticated => _isAuthenticated;

  String get matricule => _matricule;
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
  void updateMatricule(String value) {
    _matricule = value;
  }

  void updatePassword(String value) {
    _password = value;
  }

  void updateFullName(String value) {
    _fullName = value;
  }

  // Sign In — returns true on success
  Future<bool> signIn() async {
    if (_matricule.isEmpty || _password.isEmpty) {
      print('Matricule and password required');
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // TODO: Call backend API
      // await _authService.login(_matricule, _password);
      print('Sign In: $_matricule');
      
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));

      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      print('Sign In Error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign Up — returns true on success
  Future<bool> signUp() async {
    if (_fullName.isEmpty || _matricule.isEmpty || _password.isEmpty) {
      print('All fields required');
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // TODO: Call backend API
      // await _authService.register(_fullName, _matricule, _password);
      print('Sign Up: $_fullName, $_matricule');
      
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));

      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      print('Sign Up Error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign out
  void signOut() {
    _isAuthenticated = false;
    _clearForm();
    notifyListeners();
  }

  // Clear form
  void _clearForm() {
    _matricule = '';
    _password = '';
    _fullName = '';
    _showPassword = false;
  }
}
