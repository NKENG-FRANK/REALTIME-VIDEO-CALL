import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../domain/models/contact.dart';

class ContactsController extends ChangeNotifier {
  static const String _storageKey = 'callwave_contacts';
  List<Contact> _contacts = [];
  String _selectedTab = 'All';
  String _selectedFilter = 'All contacts';
  String _searchQuery = '';
  bool _isLoading = true;

  List<Contact> get contacts => _contacts;
  String get selectedTab => _selectedTab;
  String get selectedFilter => _selectedFilter;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  List<Contact> get onlineContacts =>
      _contacts.where((c) => c.online).toList();

  List<Contact> get filteredContacts {
    final query = _searchQuery.trim().toLowerCase();
    return _contacts.where((contact) {
      final matchesSearch = query.isEmpty ||
          contact.name.toLowerCase().contains(query) ||
          contact.matricule.toLowerCase().contains(query);
      final matchesFilter = _selectedFilter == 'All contacts' ||
          (_selectedFilter == 'Online' && contact.online) ||
          (_selectedFilter == 'Offline' && !contact.online);
      final matchesTab = _selectedTab == 'All' ||
          (_selectedTab == 'Favorites' && contact.isFavorite) ||
          (_selectedTab == 'Groups' && contact.group);
      return matchesSearch && matchesFilter && matchesTab;
    }).toList();
  }

  ContactsController() {
    loadContacts();
  }

  Future<void> loadContacts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final storage = await LocalStorageService.getInstance();
      final storedData = storage.getStringList(_storageKey);

      if (storedData != null && storedData.isNotEmpty) {
        _contacts = storedData
            .map((item) => Contact.fromJson(jsonDecode(item)))
            .toList();
      } else {
        // Initial seed data with valid matricules (>8 chars, starts with letter)
        _contacts = [
          const Contact(
            id: '1',
            name: 'James Liu',
            matricule: 'M00984521',
            status: 'Away',
            initials: 'JL',
            colorValue: 0xFF159AB5,
            online: true,
          ),
          const Contact(
            id: '2',
            name: 'Alex Morgan',
            matricule: 'A00123948',
            status: 'Available',
            initials: 'AM',
            colorValue: 0xFF8752F4,
            online: true,
            isFavorite: true,
          ),
          const Contact(
            id: '3',
            name: 'Sarah Chen',
            matricule: 'S00847102',
            status: 'Available',
            initials: 'SC',
            colorValue: 0xFF2D5016,
            online: true,
            isFavorite: true,
          ),
          const Contact(
            id: '4',
            name: 'Marcus Webb',
            matricule: 'M00001092',
            status: 'Busy',
            initials: 'MW',
            colorValue: 0xFFFFA00D,
            online: true,
          ),
          const Contact(
            id: '5',
            name: 'Design Team',
            matricule: 'D00994120',
            status: 'Group channel',
            initials: 'DT',
            colorValue: 0xFFE31845,
            group: true,
            participants: 5,
          ),
          const Contact(
            id: '6',
            name: 'Engineering Standup',
            matricule: 'E00389102',
            status: 'Group channel',
            initials: 'ES',
            colorValue: 0xFF159AB5,
            group: true,
            participants: 9,
          ),
          const Contact(
            id: '7',
            name: 'Priya Nair',
            matricule: 'P00472910',
            status: 'Offline',
            initials: 'PN',
            colorValue: 0xFF10A47D,
          ),
          const Contact(
            id: '8',
            name: 'Emma Stone',
            matricule: 'E00582910',
            status: 'Available',
            initials: 'ES',
            colorValue: 0xFF8752F4,
            isFavorite: true,
          ),
        ];
        await _saveToStorage();
      }
    } catch (e) {
      debugPrint('Error loading contacts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedTab(String tab) {
    _selectedTab = tab;
    notifyListeners();
  }

  void setSelectedFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> addContact(Contact contact) async {
    _contacts.insert(0, contact);
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> updateContact(Contact updated) async {
    final index = _contacts.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _contacts[index] = updated;
      notifyListeners();
      await _saveToStorage();
    }
  }

  Future<void> deleteContact(String id) async {
    _contacts.removeWhere((c) => c.id == id);
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> toggleFavorite(String id) async {
    final index = _contacts.indexWhere((c) => c.id == id);
    if (index != -1) {
      final c = _contacts[index];
      _contacts[index] = c.copyWith(isFavorite: !c.isFavorite);
      notifyListeners();
      await _saveToStorage();
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final storage = await LocalStorageService.getInstance();
      final stringList = _contacts.map((c) => jsonEncode(c.toJson())).toList();
      await storage.setStringList(_storageKey, stringList);
    } catch (e) {
      debugPrint('Error saving contacts: $e');
    }
  }
}
