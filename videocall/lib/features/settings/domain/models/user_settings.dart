class UserSettings {
  final String displayName;
  final String status;
  final bool cameraOnJoin;
  final bool micOnJoin;
  final bool noiseSuppression;
  final String callQuality;
  final bool incomingCallNotif;
  final bool missedCallNotif;
  final bool messageNotif;
  final String theme;
  final bool animatedBg;
  final bool reduceMotion;

  const UserSettings({
    this.displayName = 'You',
    this.status = 'Available',
    this.cameraOnJoin = true,
    this.micOnJoin = true,
    this.noiseSuppression = true,
    this.callQuality = 'Auto',
    this.incomingCallNotif = true,
    this.missedCallNotif = true,
    this.messageNotif = false,
    this.theme = 'Light',
    this.animatedBg = true,
    this.reduceMotion = false,
  });

  UserSettings copyWith({
    String? displayName,
    String? status,
    bool? cameraOnJoin,
    bool? micOnJoin,
    bool? noiseSuppression,
    String? callQuality,
    bool? incomingCallNotif,
    bool? missedCallNotif,
    bool? messageNotif,
    String? theme,
    bool? animatedBg,
    bool? reduceMotion,
  }) {
    return UserSettings(
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      cameraOnJoin: cameraOnJoin ?? this.cameraOnJoin,
      micOnJoin: micOnJoin ?? this.micOnJoin,
      noiseSuppression: noiseSuppression ?? this.noiseSuppression,
      callQuality: callQuality ?? this.callQuality,
      incomingCallNotif: incomingCallNotif ?? this.incomingCallNotif,
      missedCallNotif: missedCallNotif ?? this.missedCallNotif,
      messageNotif: messageNotif ?? this.messageNotif,
      theme: theme ?? this.theme,
      animatedBg: animatedBg ?? this.animatedBg,
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'status': status,
        'cameraOnJoin': cameraOnJoin,
        'micOnJoin': micOnJoin,
        'noiseSuppression': noiseSuppression,
        'callQuality': callQuality,
        'incomingCallNotif': incomingCallNotif,
        'missedCallNotif': missedCallNotif,
        'messageNotif': messageNotif,
        'theme': theme,
        'animatedBg': animatedBg,
        'reduceMotion': reduceMotion,
      };

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
        displayName: json['displayName'] as String? ?? 'You',
        status: json['status'] as String? ?? 'Available',
        cameraOnJoin: json['cameraOnJoin'] as bool? ?? true,
        micOnJoin: json['micOnJoin'] as bool? ?? true,
        noiseSuppression: json['noiseSuppression'] as bool? ?? true,
        callQuality: json['callQuality'] as String? ?? 'Auto',
        incomingCallNotif: json['incomingCallNotif'] as bool? ?? true,
        missedCallNotif: json['missedCallNotif'] as bool? ?? true,
        messageNotif: json['messageNotif'] as bool? ?? false,
        theme: json['theme'] as String? ?? 'Light',
        animatedBg: json['animatedBg'] as bool? ?? true,
        reduceMotion: json['reduceMotion'] as bool? ?? false,
      );
}
