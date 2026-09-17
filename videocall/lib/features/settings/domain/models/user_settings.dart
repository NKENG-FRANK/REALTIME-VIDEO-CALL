class UserSettings {
  final String displayName;
  final String status;
  final String matricule;
  final String ministry;
  final String department;
  final String division;
  final String positionTitle;
  final String officeLocation;
  final bool cameraOnJoin;
  final bool micOnJoin;
  final bool noiseSuppression;
  final String callQuality;
  final bool lowDataMode;
  final bool incomingCallNotif;
  final bool missedCallNotif;
  final bool messageNotif;
  final String theme;
  final String language;
  final bool animatedBg;
  final bool reduceMotion;
  final bool hidePhoneEmail;

  const UserSettings({
    this.displayName = 'You',
    this.status = 'Available',
    this.matricule = '',
    this.ministry = 'CENADI',
    this.department = 'Software Engineering',
    this.division = 'IT & Telecoms',
    this.positionTitle = 'Engineer',
    this.officeLocation = 'Building A, Room 102',
    this.cameraOnJoin = true,
    this.micOnJoin = true,
    this.noiseSuppression = true,
    this.callQuality = 'Auto',
    this.lowDataMode = false,
    this.incomingCallNotif = true,
    this.missedCallNotif = true,
    this.messageNotif = false,
    this.theme = 'Light',
    this.language = 'French',
    this.animatedBg = true,
    this.reduceMotion = false,
    this.hidePhoneEmail = false,
  });

  UserSettings copyWith({
    String? displayName,
    String? status,
    String? matricule,
    String? ministry,
    String? department,
    String? division,
    String? positionTitle,
    String? officeLocation,
    bool? cameraOnJoin,
    bool? micOnJoin,
    bool? noiseSuppression,
    String? callQuality,
    bool? lowDataMode,
    bool? incomingCallNotif,
    bool? missedCallNotif,
    bool? messageNotif,
    String? theme,
    String? language,
    bool? animatedBg,
    bool? reduceMotion,
    bool? hidePhoneEmail,
  }) {
    return UserSettings(
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      matricule: matricule ?? this.matricule,
      ministry: ministry ?? this.ministry,
      department: department ?? this.department,
      division: division ?? this.division,
      positionTitle: positionTitle ?? this.positionTitle,
      officeLocation: officeLocation ?? this.officeLocation,
      cameraOnJoin: cameraOnJoin ?? this.cameraOnJoin,
      micOnJoin: micOnJoin ?? this.micOnJoin,
      noiseSuppression: noiseSuppression ?? this.noiseSuppression,
      callQuality: callQuality ?? this.callQuality,
      lowDataMode: lowDataMode ?? this.lowDataMode,
      incomingCallNotif: incomingCallNotif ?? this.incomingCallNotif,
      missedCallNotif: missedCallNotif ?? this.missedCallNotif,
      messageNotif: messageNotif ?? this.messageNotif,
      theme: theme ?? this.theme,
      language: language ?? this.language,
      animatedBg: animatedBg ?? this.animatedBg,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      hidePhoneEmail: hidePhoneEmail ?? this.hidePhoneEmail,
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'status': status,
        'matricule': matricule,
        'ministry': ministry,
        'department': department,
        'division': division,
        'positionTitle': positionTitle,
        'officeLocation': officeLocation,
        'cameraOnJoin': cameraOnJoin,
        'micOnJoin': micOnJoin,
        'noiseSuppression': noiseSuppression,
        'callQuality': callQuality,
        'lowDataMode': lowDataMode,
        'incomingCallNotif': incomingCallNotif,
        'missedCallNotif': missedCallNotif,
        'messageNotif': messageNotif,
        'theme': theme,
        'language': language,
        'animatedBg': animatedBg,
        'reduceMotion': reduceMotion,
        'hidePhoneEmail': hidePhoneEmail,
      };

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
        displayName: json['displayName'] as String? ?? 'You',
        status: json['status'] as String? ?? 'Available',
        matricule: json['matricule'] as String? ?? '',
        ministry: json['ministry'] as String? ?? 'CENADI',
        department: json['department'] as String? ?? 'Software Engineering',
        division: json['division'] as String? ?? 'IT & Telecoms',
        positionTitle: json['positionTitle'] as String? ?? 'Engineer',
        officeLocation: json['officeLocation'] as String? ?? 'Building A, Room 102',
        cameraOnJoin: json['cameraOnJoin'] as bool? ?? true,
        micOnJoin: json['micOnJoin'] as bool? ?? true,
        noiseSuppression: json['noiseSuppression'] as bool? ?? true,
        callQuality: json['callQuality'] as String? ?? 'Auto',
        lowDataMode: json['lowDataMode'] as bool? ?? false,
        incomingCallNotif: json['incomingCallNotif'] as bool? ?? true,
        missedCallNotif: json['missedCallNotif'] as bool? ?? true,
        messageNotif: json['messageNotif'] as bool? ?? false,
        theme: json['theme'] as String? ?? 'Light',
        language: json['language'] as String? ?? 'French',
        animatedBg: json['animatedBg'] as bool? ?? true,
        reduceMotion: json['reduceMotion'] as bool? ?? false,
        hidePhoneEmail: json['hidePhoneEmail'] as bool? ?? false,
      );
}
