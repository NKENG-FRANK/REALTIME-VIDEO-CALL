import 'package:flutter/material.dart';

/// Provides all localised strings for the app.
///
/// Usage:
///   final l10n = AppLocalizations.of(context);
///   Text(l10n.settings)
class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('fr'));
  }

  bool get isFrench => locale.languageCode == 'fr';

  // ─── App-wide ───────────────────────────────────────────────────────────────

  String get appName => 'Callwave';

  String get save => isFrench ? 'Enregistrer' : 'Save';
  String get cancel => isFrench ? 'Annuler' : 'Cancel';
  String get confirm => isFrench ? 'Confirmer' : 'Confirm';
  String get close => isFrench ? 'Fermer' : 'Close';
  String get search => isFrench ? 'Rechercher' : 'Search';
  String get add => isFrench ? 'Ajouter' : 'Add';
  String get edit => isFrench ? 'Modifier' : 'Edit';
  String get delete => isFrench ? 'Supprimer' : 'Delete';
  String get yes => isFrench ? 'Oui' : 'Yes';
  String get no => isFrench ? 'Non' : 'No';
  String get loading => isFrench ? 'Chargement…' : 'Loading…';
  String get retry => isFrench ? 'Réessayer' : 'Retry';
  String get optional => isFrench ? 'Optionnel' : 'Optional';
  String get copy => isFrench ? 'Copier' : 'Copy';
  String get copied => isFrench ? 'Copié !' : 'Copied!';
  String get share => isFrench ? 'Partager' : 'Share';
  String get create => isFrench ? 'Créer' : 'Create';
  String get join => isFrench ? 'Rejoindre' : 'Join';
  String get startCall => isFrench ? 'Démarrer l\'appel' : 'Start Call';

  // ─── Navigation ─────────────────────────────────────────────────────────────

  String get navCalls => isFrench ? 'Appels' : 'Calls';
  String get navContacts => isFrench ? 'Contacts' : 'Contacts';
  String get navSettings => isFrench ? 'Paramètres' : 'Settings';

  // ─── Auth ───────────────────────────────────────────────────────────────────

  String get welcomeTitle =>
      isFrench ? 'Bienvenue sur Callwave' : 'Welcome to Callwave';
  String get welcomeSubtitle =>
      isFrench
          ? 'Votre plateforme de communication sécurisée pour les agents CENADI'
          : 'Your secure communication platform for CENADI agents';
  String get signIn => isFrench ? 'Se connecter' : 'Sign In';
  String get signUp => isFrench ? 'Créer un compte' : 'Create Account';
  String get signInTitle =>
      isFrench ? 'Connexion à votre compte' : 'Sign in to your account';
  String get createAccountTitle =>
      isFrench ? 'Créer votre compte' : 'Create your account';
  String get matricule => isFrench ? 'Matricule' : 'Matricule';
  String get matriculePlaceholder =>
      isFrench ? 'Votre matricule' : 'Your matricule';
  String get password => isFrench ? 'Mot de passe' : 'Password';
  String get passwordPlaceholder =>
      isFrench ? 'Votre mot de passe' : 'Your password';
  String get fullName => isFrench ? 'Nom complet' : 'Full Name';
  String get alreadyHaveAccount =>
      isFrench ? 'Déjà un compte ? ' : 'Already have an account? ';
  String get dontHaveAccount =>
      isFrench ? 'Pas encore de compte ? ' : "Don't have an account? ";
  String get signInLink => isFrench ? 'Se connecter' : 'Sign in';
  String get signUpLink => isFrench ? 'S\'inscrire' : 'Sign up';
  String get matriculeError =>
      isFrench
          ? 'Le matricule doit comporter plus de 8 caractères et commencer ou se terminer par une lettre.'
          : 'Matricule must be >8 characters and start or end with a letter.';
  String get passwordError =>
      isFrench ? 'Le mot de passe est requis.' : 'Password is required.';

  // ─── Calls / Call History ───────────────────────────────────────────────────

  String get callsTitle => isFrench ? 'Appels' : 'Calls';
  String get callsSubtitle =>
      isFrench ? 'Historique de vos appels récents' : 'Your recent call history';
  String get newCall => isFrench ? 'Nouvel appel' : 'New Call';
  String get groupCall => isFrench ? 'Appel de groupe' : 'Group Call';
  String get oneToOneCall => isFrench ? 'Appel individuel' : 'One-to-One Call';
  String get startGroupCall =>
      isFrench ? 'Lancer un appel de groupe' : 'Launch Group Call';
  String get startOneToOneCall =>
      isFrench ? 'Démarrer un appel individuel' : 'Start One-to-One Call';
  String get noCallHistory =>
      isFrench ? 'Aucun appel récent' : 'No recent calls';
  String get noCallHistorySubtitle =>
      isFrench
          ? 'Vos appels apparaîtront ici une fois passés.'
          : 'Your calls will appear here once made.';
  String get incomingCall => isFrench ? 'Appel entrant' : 'Incoming Call';
  String get videoCall => isFrench ? 'Appel vidéo' : 'Video Call';
  String get audioCall => isFrench ? 'Appel audio' : 'Audio Call';
  String get missedCall => isFrench ? 'Appel manqué' : 'Missed Call';
  String get callEnded => isFrench ? 'Appel terminé' : 'Call Ended';
  String get connecting => isFrench ? 'Connexion…' : 'Connecting…';
  String get duration => isFrench ? 'Durée' : 'Duration';
  String get answer => isFrench ? 'Répondre' : 'Answer';
  String get decline => isFrench ? 'Refuser' : 'Decline';
  String get endCall => isFrench ? 'Terminer l\'appel' : 'End Call';
  String get callBack => isFrench ? 'Rappeler' : 'Call Back';
  String get callAgain => isFrench ? 'Rappeler' : 'Call Again';
  String get mute => isFrench ? 'Muet' : 'Mute';
  String get unmute => isFrench ? 'Réactiver' : 'Unmute';
  String get camera => isFrench ? 'Caméra' : 'Camera';
  String get speaker => isFrench ? 'Haut-parleur' : 'Speaker';
  String get flipCamera => isFrench ? 'Retourner la caméra' : 'Flip Camera';
  String get screenShare => isFrench ? 'Partage d\'écran' : 'Screen Share';
  String get participants => isFrench ? 'Participants' : 'Participants';
  String get addParticipants =>
      isFrench ? 'Ajouter des participants' : 'Add Participants';
  String get selectMembers =>
      isFrench ? 'Sélectionner des membres' : 'Select Members';
  String get orCreateLink =>
      isFrench ? 'Ou créer un lien d\'invitation' : 'Or create an invite link';
  String get generateLink => isFrench ? 'Générer un lien' : 'Generate Link';
  String get inviteLink => isFrench ? 'Lien d\'invitation' : 'Invite Link';
  String get callLink => isFrench ? 'Lien d\'appel' : 'Call Link';
  String get groupName => isFrench ? 'Nom du groupe' : 'Group Name';
  String get groupNameHint =>
      isFrench ? 'Ex: Réunion CENADI DSI' : 'E.g. CENADI DSI Meeting';
  String get callTo => isFrench ? 'Appeler' : 'Call to';
  String get searchContacts =>
      isFrench ? 'Rechercher un contact…' : 'Search contacts…';
  String get membersSelected =>
      isFrench ? 'membre(s) sélectionné(s)' : 'member(s) selected';

  // ─── Contacts ───────────────────────────────────────────────────────────────

  String get contactsTitle => isFrench ? 'Contacts' : 'Contacts';
  String get contactsSubtitle =>
      isFrench ? 'Votre répertoire Callwave' : 'Your Callwave directory';
  String get addContact => isFrench ? 'Ajouter un contact' : 'Add Contact';
  String get editContact => isFrench ? 'Modifier le contact' : 'Edit Contact';
  String get deleteContact =>
      isFrench ? 'Supprimer le contact' : 'Delete Contact';
  String get confirmDeleteContact =>
      isFrench
          ? 'Supprimer ce contact définitivement ?'
          : 'Delete this contact permanently?';
  String get noContacts => isFrench ? 'Aucun contact' : 'No contacts';
  String get noContactsSubtitle =>
      isFrench
          ? 'Commencez par ajouter des collègues.'
          : 'Start by adding colleagues.';
  String get contactName => isFrench ? 'Nom du contact' : 'Contact Name';
  String get contactPhone => isFrench ? 'Numéro de téléphone' : 'Phone Number';
  String get contactMatricule => isFrench ? 'Matricule' : 'Matricule';
  String get contactDepartment =>
      isFrench ? 'Département' : 'Department';
  String get contactMinistry => isFrench ? 'Ministère' : 'Ministry';
  String get contactPosition => isFrench ? 'Poste / Titre' : 'Position / Title';
  String get contactStatus => isFrench ? 'Statut' : 'Status';
  String get favoriteContacts =>
      isFrench ? 'Contacts favoris' : 'Favourite Contacts';
  String get allContacts => isFrench ? 'Tous les contacts' : 'All Contacts';
  String get online => isFrench ? 'En ligne' : 'Online';
  String get offline => isFrench ? 'Hors ligne' : 'Offline';
  String get busy => isFrench ? 'Occupé' : 'Busy';
  String get away => isFrench ? 'Absent' : 'Away';
  String get doNotDisturb =>
      isFrench ? 'Ne pas déranger' : 'Do Not Disturb';

  // ─── Settings ───────────────────────────────────────────────────────────────

  String get settingsTitle => isFrench ? 'Paramètres' : 'Settings';
  String get settingsSubtitle =>
      isFrench
          ? 'Gérez votre expérience Callwave'
          : 'Manage your Callwave experience';
  String get saveChanges =>
      isFrench ? 'Enregistrer les modifications' : 'Save Changes';
  String get savedSuccessfully =>
      isFrench ? 'Paramètres enregistrés !' : 'Settings saved successfully!';

  // Profile
  String get profileSection => isFrench ? 'Profil' : 'Profile';
  String get profileSubtitle =>
      isFrench
          ? 'Comment les autres utilisateurs vous voient.'
          : 'How other Callwave users see you.';
  String get displayName => isFrench ? 'Nom affiché' : 'Display Name';
  String get displayNameSubtitle =>
      isFrench
          ? 'Le nom affiché lors des appels et dans les contacts.'
          : 'The name shown during calls and in contacts.';
  String get statusLabel => isFrench ? 'Statut' : 'Status';
  String get statusSubtitle =>
      isFrench
          ? 'Indiquez votre disponibilité.'
          : "Let people know when you're available.";
  String get statusAvailable => isFrench ? 'Disponible' : 'Available';
  String get statusBusy => isFrench ? 'Occupé' : 'Busy';
  String get statusAway => isFrench ? 'Absent' : 'Away';
  String get statusDnd => isFrench ? 'Ne pas déranger' : 'Do Not Disturb';
  String get changePhoto =>
      isFrench ? 'Changer la photo' : 'Change photo';

  // Organizational
  String get orgSection =>
      isFrench ? 'Informations organisationnelles' : 'Organizational Information';
  String get orgSubtitle =>
      isFrench
          ? 'Votre identité institutionnelle et vos informations de localisation.'
          : 'Your institutional identity and location details.';
  String get matriculeId =>
      isFrench ? 'Matricule / Identifiant' : 'Matricule / Employee ID';
  String get matriculeIdSubtitle =>
      isFrench
          ? 'Votre matricule d\'identification institutionnel unique.'
          : 'Your unique institutional identification matricule.';
  String get matriculeValidationError =>
      isFrench
          ? 'Doit comporter >8 caractères et commencer/terminer par une lettre'
          : 'Must be >8 chars & start/end with a letter';
  String get ministryOrg =>
      isFrench ? 'Ministère / Organisation' : 'Ministry / Organization';
  String get ministryOrgSubtitle =>
      isFrench
          ? 'Ministère ou institution principale.'
          : 'Primary ministry or institutional body.';
  String get department => isFrench ? 'Département' : 'Department';
  String get departmentSubtitle =>
      isFrench
          ? 'Votre département au sein du ministère.'
          : 'Your department within the ministry.';
  String get division => isFrench ? 'Division' : 'Division';
  String get divisionSubtitle =>
      isFrench
          ? 'Unité organisationnelle ou division.'
          : 'Organizational unit or division.';
  String get positionTitle => isFrench ? 'Poste / Titre' : 'Position / Title';
  String get positionTitleSubtitle =>
      isFrench
          ? 'Votre rôle ou titre professionnel.'
          : 'Your role or professional title.';
  String get officeLocation =>
      isFrench ? 'Localisation du bureau' : 'Office Location';
  String get officeLocationSubtitle =>
      isFrench
          ? 'Bâtiment, étage ou numéro de salle.'
          : 'Building, floor, or office room number.';

  // Privacy
  String get privacySection =>
      isFrench ? 'Confidentialité et répertoire' : 'Privacy & Directory';
  String get privacySubtitle =>
      isFrench
          ? 'Contrôlez votre visibilité dans les contacts.'
          : 'Control your contact visibility and searchability.';
  String get hidePhoneMatricule =>
      isFrench
          ? 'Masquer le téléphone et le matricule'
          : 'Hide phone & matricule from contacts';
  String get hidePhoneMatriculeSubtitle =>
      isFrench
          ? 'Dissimuler les coordonnées personnelles dans la recherche de répertoire.'
          : 'Conceal personal contact details from directory search.';

  // Calling
  String get callingSection =>
      isFrench ? 'Appels' : 'Calling';
  String get callingSubtitle =>
      isFrench
          ? 'Configurez votre comportement audio et vidéo.'
          : 'Configure your audio and video call behavior.';
  String get cameraOnJoin =>
      isFrench ? 'Caméra activée à l\'entrée' : 'Camera on when joining';
  String get cameraOnJoinSubtitle =>
      isFrench
          ? 'Activer automatiquement la caméra lors d\'un appel vidéo.'
          : 'Automatically enable your camera when starting a video call.';
  String get micOnJoin =>
      isFrench ? 'Microphone activé à l\'entrée' : 'Microphone on when joining';
  String get micOnJoinSubtitle =>
      isFrench
          ? 'Activer automatiquement le microphone lors d\'un appel.'
          : 'Automatically enable your microphone when entering a call.';
  String get noiseSuppression =>
      isFrench ? 'Suppression du bruit' : 'Noise suppression';
  String get noiseSuppressionSubtitle =>
      isFrench
          ? 'Réduire les bruits de fond pendant les appels.'
          : 'Reduce background sounds during calls.';
  String get lowDataMode =>
      isFrench ? 'Mode économie de données' : 'Low-data mode';
  String get lowDataModeSubtitle =>
      isFrench
          ? 'Réduire la consommation de bande passante lors des appels vidéo.'
          : 'Reduce bandwidth consumption during video calls.';
  String get defaultCallQuality =>
      isFrench ? 'Qualité d\'appel par défaut' : 'Default call quality';
  String get defaultCallQualitySubtitle =>
      isFrench
          ? 'Choisissez comment Callwave adapte la qualité.'
          : 'Choose how aggressively Callwave adapts quality.';

  // Notifications
  String get notificationsSection =>
      isFrench ? 'Notifications' : 'Notifications';
  String get notificationsSubtitle =>
      isFrench
          ? 'Contrôlez comment Callwave vous alerte.'
          : 'Control how Callwave alerts you.';
  String get incomingCallNotif =>
      isFrench ? 'Notifications d\'appels entrants' : 'Incoming call notifications';
  String get incomingCallNotifSubtitle =>
      isFrench
          ? 'Afficher les notifications pour les appels entrants.'
          : 'Show notifications for incoming audio and video calls.';
  String get missedCallNotif =>
      isFrench ? 'Notifications d\'appels manqués' : 'Missed call notifications';
  String get missedCallNotifSubtitle =>
      isFrench
          ? 'Vous informer quand vous manquez un appel.'
          : 'Notify you when you miss a call.';
  String get messageNotif =>
      isFrench ? 'Notifications de messages' : 'Message notifications';
  String get messageNotifSubtitle =>
      isFrench
          ? 'Afficher des alertes pour les nouveaux messages.'
          : 'Show alerts for new chat messages.';

  // Appearance
  String get appearanceSection =>
      isFrench ? 'Apparence et langue' : 'Appearance & Language';
  String get appearanceSubtitle =>
      isFrench
          ? 'Personnalisez l\'interface Callwave.'
          : 'Customize the Callwave interface.';
  String get themeLabel => isFrench ? 'Thème' : 'Theme';
  String get themeSubtitle =>
      isFrench ? 'Choisissez l\'apparence de Callwave.' : 'Choose how Callwave looks.';
  String get themeLight => isFrench ? 'Clair' : 'Light';
  String get themeDark => isFrench ? 'Sombre' : 'Dark';
  String get themeSystem => isFrench ? 'Système' : 'System';
  String get languageLabel => isFrench ? 'Langue' : 'Language';
  String get languageSubtitle =>
      isFrench
          ? 'Choisissez la langue de l\'interface.'
          : 'Choose your preferred interface language.';
  String get languageFrench => isFrench ? 'Français' : 'French';
  String get languageEnglish => isFrench ? 'Anglais' : 'English';
  String get animatedBg =>
      isFrench ? 'Arrière-plan animé' : 'Animated background';
  String get animatedBgSubtitle =>
      isFrench
          ? 'Afficher les formes animées dans l\'interface.'
          : 'Show the soft animated shapes throughout the interface.';
  String get reduceMotion =>
      isFrench ? 'Réduire les animations' : 'Reduce motion';
  String get reduceMotionSubtitle =>
      isFrench
          ? 'Réduire les animations d\'interface.'
          : 'Reduce background and interface animations.';

  // Account / Logout
  String get logout => isFrench ? 'Déconnexion' : 'Log Out';
  String get logoutSubtitle =>
      isFrench ? 'Déconnecter votre session Callwave.' : 'Sign out of your Callwave session.';
  String get logoutConfirmTitle =>
      isFrench ? 'Confirmer la déconnexion' : 'Confirm Logout';
  String get logoutConfirmMessage =>
      isFrench
          ? 'Voulez-vous vraiment vous déconnecter de votre compte ?'
          : 'Are you sure you want to log out of your account?';
}
