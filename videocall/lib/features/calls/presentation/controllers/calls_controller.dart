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
        _calls = storedData
            .map((item) => CallLog.fromJson(jsonDecode(item)))
            .toList();
      } else {
        // Seed default initial logs
        _calls = [
          const CallLog(
            id: '1',
            name: 'Sarah Chen',
            initials: 'SC',
            colorValue: 0xFF8752F4,
            time: '2m ago',
            duration: '42:18',
            isOutgoing: false,
          ),
          const CallLog(
            id: '2',
            name: 'Design Team',
            initials: 'DT',
            colorValue: 0xFF2D5016,
            time: '1h ago',
            duration: '1:12:44',
            isOutgoing: true,
            isGroup: true,
            participants: 5,
          ),
          const CallLog(
            id: '3',
            name: 'Marcus Webb',
            initials: 'MW',
            colorValue: 0xFF10A47D,
            time: '3h ago',
            duration: '',
            isMissed: true,
          ),
          const CallLog(
            id: '4',
            name: 'Priya Nair',
            initials: 'PN',
            colorValue: 0xFFFFA00D,
            time: 'Yesterday',
            duration: '8:33',
            isOutgoing: true,
          ),
          const CallLog(
            id: '5',
            name: 'Engineering Standup',
            initials: 'ES',
            colorValue: 0xFF159AB5,
            time: 'Yesterday',
            duration: '28:07',
            isGroup: true,
            participants: 9,
          ),
          const CallLog(
            id: '6',
            name: 'James Liu',
            initials: 'JL',
            colorValue: 0xFF8752F4,
            time: 'Mon',
            duration: '4:22',
            isOutgoing: false,
          ),
        ];
        await _saveToStorage();
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
