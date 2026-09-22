import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import 'auth_service.dart';

class ContactItem {
  final String id;
  final String username;
  final String matricule;
  final String displayName;
  final String? department;
  final String? avatarUrl;
  final bool isFavorite;

  String get name => displayName;
  bool get group => false;
  bool get online => true;
  Color get color => const Color(0xFF2D5016);
  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  ContactItem({
    required this.id,
    required this.username,
    required this.matricule,
    required this.displayName,
    this.department,
    this.avatarUrl,
    this.isFavorite = false,
  });

  factory ContactItem.fromJson(Map<String, dynamic> json) {
    final displayName = json['display_name'] ??
        json['displayName'] ??
        ((json['first_name'] != null || json['last_name'] != null)
            ? '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim()
            : json['username'] ?? json['matricule'] ?? 'User');

    return ContactItem(
      id: json['id']?.toString() ?? json['user_id']?.toString() ?? '',
      username: json['username'] ?? '',
      matricule: json['matricule'] ?? '',
      displayName: displayName,
      department: json['department'],
      avatarUrl: json['avatar_url'],
      isFavorite: json['is_favorite'] == true,
    );
  }
}

class ContactsService {
  /// Fetch user's personal saved contacts
  Future<List<ContactItem>> getSavedContacts() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse(ApiConfig.contactsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ContactItem.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Search all app directory users by name or matricule
  Future<List<ContactItem>> searchAllUsers(String searchQuery) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return [];

      final uri = Uri.parse('${ApiConfig.userManagementBaseUrl}/users/search')
          .replace(queryParameters: searchQuery.trim().isNotEmpty ? {'q': searchQuery.trim()} : null);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ContactItem.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Save a user to personal contacts
  Future<bool> saveContact(String contactUserId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse(ApiConfig.contactsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'contactUserId': contactUserId}),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}
