import 'dart:convert';
import 'package:flutter/material.dart';
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

  Future<void> updateProfile({String? displayName, String? status}) async {
    _settings = _settings.copyWith(
      displayName: displayName,
      status: status,
    );
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> updateCalling({
    bool? cameraOnJoin,
    bool? micOnJoin,
    bool? noiseSuppression,
    String? callQuality,
  }) async {
    _settings = _settings.copyWith(
      cameraOnJoin: cameraOnJoin,
      micOnJoin: micOnJoin,
      noiseSuppression: noiseSuppression,
      callQuality: callQuality,
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
    bool? animatedBg,
    bool? reduceMotion,
  }) async {
    _settings = _settings.copyWith(
      theme: theme,
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
