import 'package:flutter/material.dart';

class CallLog {
  final String id;
  final String name;
  final String initials;
  final int colorValue;
  final String time;
  final String duration;
  final bool isMissed;
  final bool isOutgoing;
  final bool isGroup;
  final int? participants;

  const CallLog({
    required this.id,
    required this.name,
    required this.initials,
    required this.colorValue,
    required this.time,
    required this.duration,
    this.isMissed = false,
    this.isOutgoing = false,
    this.isGroup = false,
    this.participants,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'initials': initials,
        'colorValue': colorValue,
        'time': time,
        'duration': duration,
        'isMissed': isMissed,
        'isOutgoing': isOutgoing,
        'isGroup': isGroup,
        'participants': participants,
      };

  factory CallLog.fromJson(Map<String, dynamic> json) => CallLog(
        id: json['id'] as String,
        name: json['name'] as String,
        initials: json['initials'] as String,
        colorValue: json['colorValue'] as int,
        time: json['time'] as String,
        duration: json['duration'] as String,
        isMissed: json['isMissed'] as bool? ?? false,
        isOutgoing: json['isOutgoing'] as bool? ?? false,
        isGroup: json['isGroup'] as bool? ?? false,
        participants: json['participants'] as int?,
      );
}
