import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../domain/models/call_log.dart';

class CallsController extends ChangeNotifier {
  static const String _storageKey = 'callwave_call_logs';
  List<CallLog> _calls = [];
  String _selectedTab = 'All';
  String _searchQuery = '';
  bool _isLoading = true;

  List<CallLog> get calls => _calls;
  String get selectedTab => _selectedTab;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  int get missedCount => _calls.where((c) => c.isMissed).length;

  List<CallLog> get filteredCalls {
    final query = _searchQuery.trim().toLowerCase();
    return _calls.where((call) {
      final matchesSearch =
          query.isEmpty || call.name.toLowerCase().contains(query);
      final matchesTab =
          _selectedTab == 'All' || (_selectedTab == 'Missed' && call.isMissed);
      return matchesSearch && matchesTab;
    }).toList();
  }

  CallsController() {
    loadCallLogs();
  }

  Future<void> loadCallLogs() async {
    _isLoading = true;
    notifyListeners();

    try {
      final storage = await LocalStorageService.getInstance();
      final storedData = storage.getStringList(_storageKey);

      if (storedData != null && storedData.isNotEmpty) {
        final parsed = storedData
            .map((item) => CallLog.fromJson(jsonDecode(item)))
            .toList();
        // Remove old mock entries if present
        _calls = parsed
            .where((c) => !['1', '2', '3', '4', '5', '6'].contains(c.id))
            .toList();
        if (parsed.length != _calls.length) {
          await _saveToStorage();
        }
      } else {
        _calls = [];
      }
    } catch (e) {
      debugPrint('Error loading call logs: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedTab(String tab) {
    _selectedTab = tab;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> addCallLog(CallLog call) async {
    _calls.insert(0, call);
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> deleteCallLog(String id) async {
    _calls.removeWhere((call) => call.id == id);
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> clearAllLogs() async {
    _calls.clear();
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> _saveToStorage() async {
    try {
      final storage = await LocalStorageService.getInstance();
      final stringList = _calls.map((c) => jsonEncode(c.toJson())).toList();
      await storage.setStringList(_storageKey, stringList);
    } catch (e) {
      debugPrint('Error saving call logs: $e');
    }
  }
}
