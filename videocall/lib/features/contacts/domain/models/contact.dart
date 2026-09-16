import 'package:flutter/material.dart';

class Contact {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String status;
  final String initials;
  final int colorValue;
  final bool online;
  final bool isFavorite;
  final bool group;
  final int? participants;

  const Contact({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    required this.status,
    required this.initials,
    required this.colorValue,
    this.online = false,
    this.isFavorite = false,
    this.group = false,
    this.participants,
  });

  Color get color => Color(colorValue);

  Contact copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? status,
    String? initials,
    int? colorValue,
    bool? online,
    bool? isFavorite,
    bool? group,
    int? participants,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      initials: initials ?? this.initials,
      colorValue: colorValue ?? this.colorValue,
      online: online ?? this.online,
      isFavorite: isFavorite ?? this.isFavorite,
      group: group ?? this.group,
      participants: participants ?? this.participants,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'status': status,
        'initials': initials,
        'colorValue': colorValue,
        'online': online,
        'isFavorite': isFavorite,
        'group': group,
        'participants': participants,
      };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String? ?? '',
        status: json['status'] as String? ?? 'Available',
        initials: json['initials'] as String,
        colorValue: json['colorValue'] as int,
        online: json['online'] as bool? ?? false,
        isFavorite: json['isFavorite'] as bool? ?? false,
        group: json['group'] as bool? ?? false,
        participants: json['participants'] as int?,
      );
}
