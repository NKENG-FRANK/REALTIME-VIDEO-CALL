import 'package:flutter/material.dart';
import '../../../../core/services/contacts_service.dart';

class ContactsController extends ChangeNotifier {
  final ContactsService _contactsService = ContactsService();

  List<ContactItem> _savedContacts = [];
  List<ContactItem> _allUsers = [];
  String _selectedTab = 'Saved Contacts'; // 'Saved Contacts' or 'All Users'
  String _searchQuery = '';
  bool _isLoading = false;

  List<ContactItem> get savedContacts => _savedContacts;
  List<ContactItem> get contacts => _savedContacts;
  List<ContactItem> get allUsers => _allUsers;
  String get selectedTab => _selectedTab;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  /// Filtered list based on search query and active tab
  List<ContactItem> get currentList {
    final list = _selectedTab == 'Saved Contacts' ? _savedContacts : _allUsers;
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return list;

    return list.where((item) {
      return item.displayName.toLowerCase().contains(query) ||
          item.matricule.toLowerCase().contains(query) ||
          item.username.toLowerCase().contains(query);
    }).toList();
  }

  ContactsController() {
    refreshData();
  }

  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _savedContacts = await _contactsService.getSavedContacts();
      _allUsers = await _contactsService.searchAllUsers(_searchQuery);
    } catch (e) {
      debugPrint('Error loading contacts data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedTab(String tab) {
    _selectedTab = tab;
    notifyListeners();
  }

  void setSearchQuery(String query) async {
    _searchQuery = query;
    notifyListeners();

    if (_selectedTab == 'All Users') {
      _allUsers = await _contactsService.searchAllUsers(query);
      notifyListeners();
    }
  }

  Future<bool> saveContact(ContactItem item) async {
    final success = await _contactsService.saveContact(item.id);
    if (success) {
      await refreshData();
    }
    return success;
  }
}
