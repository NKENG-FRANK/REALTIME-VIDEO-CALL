import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../config/api_config.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../domain/models/user_settings.dart';

class SettingsController extends ChangeNotifier {
  static const String _storageKey = 'callwave_user_settings';
  UserSettings _settings = const UserSettings();
  bool _isLoading = true;

  UserSettings get settings => _settings;
  bool get isLoading => _isLoading;

  SettingsController() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final storage = await LocalStorageService.getInstance();
      final storedData = storage.getString(_storageKey);

      if (storedData != null && storedData.isNotEmpty) {
        _settings = UserSettings.fromJson(jsonDecode(storedData));
      } else {
        _settings = const UserSettings();
        await _saveToStorage();
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings(UserSettings updated) async {
    _settings = updated;
    notifyListeners();
    await _saveToStorage();
  }

  /// Called after login to pre-fill profile fields from DB data.
  /// Always overwrites local settings with the latest DB values.
  Future<void> seedFromUser(Map<String, dynamic> user) async {
    final displayName = (user['display_name'] as String?)?.trim() ?? '';
    final matricule   = (user['matricule']     as String?)?.trim() ?? '';
    final department  = (user['department']    as String?)?.trim() ?? '';
    final ministry    = (user['ministry']      as String?)?.trim() ?? '';
    final division    = (user['division']      as String?)?.trim() ?? '';
    final position    = (user['position_title'] as String?)?.trim() ?? '';
    final office      = (user['office_location'] as String?)?.trim() ?? '';

    _settings = _settings.copyWith(
      displayName:    displayName,
      matricule:      matricule,
      department:     department,
      ministry:       ministry,
      division:       division,
      positionTitle:  position,
      officeLocation: office,
    );
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> updateProfile({
    String? displayName,
    String? status,
    String? matricule,
    String? ministry,
    String? department,
    String? division,
    String? positionTitle,
    String? officeLocation,
    bool? hidePhoneEmail,
  }) async {
    _settings = _settings.copyWith(
      displayName: displayName,
      status: status,
      matricule: matricule,
      ministry: ministry,
      department: department,
      division: division,
      positionTitle: positionTitle,
      officeLocation: officeLocation,
      hidePhoneEmail: hidePhoneEmail,
    );
    notifyListeners();
    await _saveToStorage();
  }

  /// Persists current user profile settings to the backend database via PATCH /api/v1/users/profile
  Future<bool> saveProfileToBackend() async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('Cannot save profile: No auth token found.');
        return false;
      }

      final response = await http.patch(
        Uri.parse(ApiConfig.profileUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'display_name': _settings.displayName,
          'ministry': _settings.ministry,
          'department': _settings.department,
          'division': _settings.division,
          'position_title': _settings.positionTitle,
          'office_location': _settings.officeLocation,
          'hide_phone_email': _settings.hidePhoneEmail,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('Profile updated on backend successfully');
        return true;
      } else {
        debugPrint('Failed to update profile: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error saving profile to backend: $e');
      return false;
    }
  }

  Future<void> updateCalling({
    bool? cameraOnJoin,
    bool? micOnJoin,
    bool? noiseSuppression,
    String? callQuality,
    bool? lowDataMode,
  }) async {
    _settings = _settings.copyWith(
      cameraOnJoin: cameraOnJoin,
      micOnJoin: micOnJoin,
      noiseSuppression: noiseSuppression,
      callQuality: callQuality,
      lowDataMode: lowDataMode,
    );
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> updateNotifications({
    bool? incomingCallNotif,
    bool? missedCallNotif,
    bool? messageNotif,
  }) async {
    _settings = _settings.copyWith(
      incomingCallNotif: incomingCallNotif,
      missedCallNotif: missedCallNotif,
      messageNotif: messageNotif,
    );
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> updateAppearance({
    String? theme,
    String? language,
    bool? animatedBg,
    bool? reduceMotion,
  }) async {
    _settings = _settings.copyWith(
      theme: theme,
      language: language,
      animatedBg: animatedBg,
      reduceMotion: reduceMotion,
    );
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> resetToDefaults() async {
    _settings = const UserSettings();
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> _saveToStorage() async {
    try {
      final storage = await LocalStorageService.getInstance();
      await storage.setString(_storageKey, jsonEncode(_settings.toJson()));
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }
}
