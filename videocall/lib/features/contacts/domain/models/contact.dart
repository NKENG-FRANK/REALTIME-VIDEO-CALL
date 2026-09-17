import 'package:flutter/material.dart';

class Contact {
  final String id;
  final String name;
  final String matricule;
  final String phone;
  final String status;
  final String initials;
  final int colorValue;
  final bool online;
  final bool isFavorite;
  final bool group;
  final int? participants;
  final String? customAlias;
  final bool isBlocked;

  const Contact({
    required this.id,
    required this.name,
    required this.matricule,
    this.phone = '',
    required this.status,
    required this.initials,
    required this.colorValue,
    this.online = false,
    this.isFavorite = false,
    this.group = false,
    this.participants,
    this.customAlias,
    this.isBlocked = false,
  });

  /// Validates matricule: length > 8 and starts or ends with a letter (A-Z, a-z)
  static bool isValidMatricule(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 8) return false;
    final startsWithLetter = RegExp(r'^[a-zA-Z]').hasMatch(trimmed);
    final endsWithLetter = RegExp(r'[a-zA-Z]$').hasMatch(trimmed);
    return startsWithLetter || endsWithLetter;
  }

  Color get color => Color(colorValue);

  Contact copyWith({
    String? id,
    String? name,
    String? matricule,
    String? phone,
    String? status,
    String? initials,
    int? colorValue,
    bool? online,
    bool? isFavorite,
    bool? group,
    int? participants,
    String? customAlias,
    bool? isBlocked,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      matricule: matricule ?? this.matricule,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      initials: initials ?? this.initials,
      colorValue: colorValue ?? this.colorValue,
      online: online ?? this.online,
      isFavorite: isFavorite ?? this.isFavorite,
      group: group ?? this.group,
      participants: participants ?? this.participants,
      customAlias: customAlias ?? this.customAlias,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'matricule': matricule,
        'phone': phone,
        'status': status,
        'initials': initials,
        'colorValue': colorValue,
        'online': online,
        'isFavorite': isFavorite,
        'group': group,
        'participants': participants,
        'customAlias': customAlias,
        'isBlocked': isBlocked,
      };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id: json['id'] as String,
        name: json['name'] as String,
        matricule: (json['matricule'] ?? json['email'] ?? '') as String,
        phone: json['phone'] as String? ?? '',
        status: json['status'] as String? ?? 'Available',
        initials: json['initials'] as String,
        colorValue: json['colorValue'] as int,
        online: json['online'] as bool? ?? false,
        isFavorite: json['isFavorite'] as bool? ?? false,
        group: json['group'] as bool? ?? false,
        participants: json['participants'] as int?,
        customAlias: json['customAlias'] as String?,
        isBlocked: json['isBlocked'] as bool? ?? false,
      );
}
