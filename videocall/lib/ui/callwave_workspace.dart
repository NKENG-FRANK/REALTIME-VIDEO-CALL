import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme/app_colors.dart';
import '../core/l10n/app_localizations.dart';
import '../core/services/contacts_service.dart';
import '../core/services/meeting_link_service.dart';
import '../core/widgets/animated_background.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/call/presentation/pages/audio_call_page.dart';
import '../features/call/presentation/pages/call_page.dart';
import '../features/call/presentation/widgets/call_launcher_dialogs.dart';
import '../features/calls/domain/models/call_log.dart';
import '../features/settings/presentation/controllers/settings_controller.dart';
import '../features/calls/presentation/controllers/calls_controller.dart';
import '../features/contacts/presentation/controllers/contacts_controller.dart';

class CallwaveWorkspace extends StatefulWidget {
  const CallwaveWorkspace({super.key, this.initialPage = 'calls'});

  final String initialPage;

  @override
  State<CallwaveWorkspace> createState() => _CallwaveWorkspaceState();
}

class _CallwaveWorkspaceState extends State<CallwaveWorkspace> {
  late String _activePage = widget.initialPage;
  final _callSearch = TextEditingController();
  final _peopleSearch = TextEditingController();
  final _roomCode = TextEditingController();
  String? _selectedCallId;
  String _mobileCallsTab = 'recent';
  bool _isSigningOut = false;

  @override
  void didUpdateWidget(covariant CallwaveWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPage != widget.initialPage) {
      _activePage = widget.initialPage;
    }
  }

  @override
  void dispose() {
    _callSearch.dispose();
    _peopleSearch.dispose();
    _roomCode.dispose();
    super.dispose();
  }

  void _selectPage(String page) {
    if (page == 'people' && MediaQuery.sizeOf(context).width < 860) {
      context.read<ContactsController>().setSelectedTab('All Users');
    }
    setState(() => _activePage = page);
  }

  String _text(String fr, String en) =>
      AppLocalizations.of(context).text(fr: fr, en: en);

  Future<void> _signOut() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSigningOut = true);
    try {
      await context.read<AuthController>().signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSigningOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              'Impossible de se déconnecter. Réessayez.',
              'Could not sign out. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    final success = await context
        .read<SettingsController>()
        .saveProfileToBackend();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? _text('Profil enregistré', 'Profile saved')
              : _text(
                  'Impossible d’enregistrer le profil',
                  'Could not save profile',
                ),
        ),
      ),
    );
  }

  Future<void> _editDisplayName(String currentName) async {
    final value = await _showTextEditor(
      title: _text('Modifier le nom du profil', 'Edit profile name'),
      label: _text('Nom affiché', 'Display name'),
      initialValue: currentName,
    );
    if (value == null || value.isEmpty || !mounted) return;
    await context.read<SettingsController>().updateProfile(displayName: value);
  }

  Future<void> _editSettingField({
    required String title,
    required String value,
    required Future<void> Function(String) onSave,
  }) async {
    final updatedValue = await _showTextEditor(
      title: _text('Modifier : $title', 'Edit $title'),
      label: title,
      initialValue: value,
    );
    if (updatedValue == null || !mounted) return;
    await onSave(updatedValue);
  }

  Future<String?> _showTextEditor({
    required String title,
    required String label,
    required String initialValue,
  }) => showDialog<String>(
    context: context,
    builder: (_) => _WorkspaceTextEditor(
      title: title,
      label: label,
      initialValue: initialValue,
    ),
  );

  Widget _profileField({
    required String title,
    required String value,
    required Future<void> Function(String) onSave,
  }) => _PreferenceRow(
    title: title,
    subtitle: _text(
      'Visible sur votre profil Callwave',
      'Visible on your Callwave profile',
    ),
    control: TextButton.icon(
      onPressed: () =>
          _editSettingField(title: title, value: value, onSave: onSave),
      icon: const Icon(Icons.edit_outlined, size: 17),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 190),
        child: Text(
          value.isEmpty ? _text('Ajouter', 'Add') : value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );

  void _redial(CallLog call) {
    if (call.isGroup) {
      showGroupCallLaunchDialog(context);
      return;
    }
    showCallTypeSelectionDialog(
      context,
      recipientName: call.name,
      recipientMatricule: '',
      recipientUserId: call.contactUserId ?? '',
    );
  }

  void _callContact(ContactItem contact) {
    showCallTypeSelectionDialog(
      context,
      recipientName: contact.displayName,
      recipientMatricule: contact.matricule,
      recipientUserId: contact.id,
    );
  }

  void _joinRoom() {
    final parsed = MeetingLinkService.parseInput(_roomCode.text);
    if (parsed.roomId.isEmpty) return;
    if (!MeetingLinkService.isValidRoomId(parsed.roomId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_text('Code de salle invalide', 'Invalid room code')),
        ),
      );
      return;
    }
    final title = parsed.title ?? 'Meeting ${parsed.roomId}';
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => parsed.isVideo
            ? CallPage(
                callTitle: title,
                roomId: parsed.roomId,
                isVideoCall: true,
                isGroupCall: true,
                participantCount: 2,
              )
            : AudioCallPage(
                callTitle: title,
                roomId: parsed.roomId,
                contactName: title,
                contactMatricule: parsed.roomId,
                isGroupCall: true,
                participantCount: 2,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 860;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AnimatedBackground(),
          SafeArea(child: mobile ? _buildMobile() : _buildDesktop()),
        ],
      ),
    );
  }

  Widget _buildDesktop() {
    return Row(
      children: [
        _NavigationRail(activePage: _activePage, onSelect: _selectPage),
        Expanded(
          child: Column(
            children: [
              _buildHeader(mobile: false),
              Expanded(child: _buildActiveView(mobile: false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobile() {
    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              _buildHeader(mobile: true),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 108),
                  child: _buildActiveView(mobile: true),
                ),
              ),
            ],
          ),
        ),
        if (_activePage == 'calls')
          Positioned(
            right: 20,
            bottom: 108,
            child: FloatingActionButton(
              tooltip: _text('Nouvel appel vidéo', 'New video call'),
              onPressed: () => showOneToOneCallLaunchDialog(context),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.videocam_outlined, size: 26),
            ),
          ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 22,
          child: _MobileNavigation(
            activePage: _activePage,
            onSelect: _selectPage,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({required bool mobile}) {
    final title = switch (_activePage) {
      'people' =>
        mobile
            ? _text('Ajouter des personnes', 'Add people')
            : _text('Personnes', 'People'),
      'join' => _text('Rejoindre un appel', 'Join a call'),
      'settings' => _text('Paramètres', 'Settings'),
      _ => _text('Appels', 'Calls'),
    };
    return Container(
      padding: EdgeInsets.fromLTRB(
        mobile ? 18 : 32,
        18,
        mobile ? 18 : 32,
        mobile ? 0 : 16,
      ),
      decoration: mobile
          ? null
          : BoxDecoration(
              color: Theme.of(context).colorScheme.surface
                  .withValues(alpha: 0.62),
              border: Border(bottom: BorderSide(color: AppColors.borderColor)),
            ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: mobile ? 30 : 28,
                    letterSpacing: mobile ? 0 : null,
                  ),
                ),
                if (!mobile)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      _activePage == 'people'
                          ? _text(
                              'Trouvez des personnes et démarrez une conversation',
                              'Find people and start a conversation',
                            )
                          : _activePage == 'join'
                          ? _text(
                              'Rejoignez avec un code de salle ou un lien d’invitation',
                              'Join with a room code or invitation link',
                            )
                          : _text(
                              'Vos conversations récentes',
                              'Your recent conversations',
                            ),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
          if (_activePage == 'calls') ...[
            if (!mobile) ...[
              _HeaderIconButton(
                icon: Icons.link_rounded,
                tooltip: _text('Rejoindre un appel', 'Join a call'),
                onPressed: () => _selectPage('join'),
              ),
              const SizedBox(width: 8),
            ],
            _HeaderIconButton(
              icon: Icons.groups_rounded,
              tooltip: _text(
                'Démarrer un appel de groupe',
                'Start a group call',
              ),
              onPressed: () => showGroupCallLaunchDialog(context),
            ),
            if (!mobile) ...[
              const SizedBox(width: 8),
              _HeaderIconButton(
                icon: Icons.person_add_alt_1_rounded,
                tooltip: _text('Démarrer un appel', 'Start a call'),
                onPressed: () => showOneToOneCallLaunchDialog(context),
                primary: true,
              ),
            ],
          ],
          if (_activePage == 'people' && mobile)
            _HeaderIconButton(
              icon: Icons.person_add_alt_1_outlined,
              tooltip: _text('Ajouter manuellement', 'Add manually'),
              onPressed: _addByMatricule,
            ),
          if (_activePage == 'people' && !mobile)
            _HeaderIconButton(
              icon: Icons.refresh_rounded,
              tooltip: _text('Actualiser le répertoire', 'Refresh directory'),
              onPressed: () => context.read<ContactsController>().refreshData(),
            ),
          if (_activePage == 'settings')
            mobile
                ? _HeaderIconButton(
                    icon: Icons.save_outlined,
                    tooltip: _text('Enregistrer le profil', 'Save profile'),
                    onPressed: _saveProfile,
                  )
                : FilledButton.icon(
                    onPressed: _saveProfile,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_text('Enregistrer le profil', 'Save profile')),
                  ),
        ],
      ),
    );
  }

  Widget _buildActiveView({required bool mobile}) {
    return switch (_activePage) {
      'people' => _buildPeople(mobile: mobile),
      'join' => _buildJoin(mobile: mobile),
      'settings' => _buildSettings(mobile: mobile),
      _ => _buildCalls(mobile: mobile),
    };
  }

  Widget _buildCalls({required bool mobile}) {
    if (mobile) return _buildMobileCalls();
    return Consumer<CallsController>(
      builder: (context, controller, _) {
        final calls = controller.filteredCalls;
        final selected = calls.cast<CallLog?>().firstWhere(
          (call) => call?.id == _selectedCallId,
          orElse: () => calls.isEmpty ? null : calls.first,
        );
        final listPane = Padding(
          padding: EdgeInsets.fromLTRB(
            mobile ? 18 : 28,
            20,
            mobile ? 18 : 20,
            20,
          ),
          child: Column(
            children: [
              _SearchField(
                controller: _callSearch,
                hint: _text(
                  'Rechercher des personnes ou des numéros',
                  'Search people or numbers',
                ),
                onChanged: controller.setSearchQuery,
              ),
              const SizedBox(height: 14),
              _SegmentedChoice(
                choices: const ['All', 'Missed'],
                labels: {
                  'All': _text('Tous', 'All'),
                  'Missed': _text('Manqués', 'Missed'),
                },
                selected: controller.selectedTab,
                onSelected: controller.setSelectedTab,
                badge: controller.missedCount,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : calls.isEmpty
                    ? _EmptyState(
                        icon: Icons.call_outlined,
                        title: _text('Aucun appel récent', 'No calls yet'),
                        message: _text(
                          'Vos appels récents apparaîtront ici.',
                          'Your recent calls will appear here.',
                        ),
                        action: FilledButton.icon(
                          onPressed: () =>
                              showOneToOneCallLaunchDialog(context),
                          icon: const Icon(Icons.add_call),
                          label: Text(
                            _text('Démarrer un appel', 'Start a call'),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: calls.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 7),
                        itemBuilder: (context, index) => _CallListTile(
                          call: calls[index],
                          selected: calls[index].id == _selectedCallId,
                          onTap: () {
                            setState(() => _selectedCallId = calls[index].id);
                            if (mobile) _redial(calls[index]);
                          },
                          onCall: () => _redial(calls[index]),
                          onDelete: () =>
                              controller.deleteCallLog(calls[index].id),
                        ),
                      ),
              ),
            ],
          ),
        );
        if (mobile) return listPane;
        return Row(
          children: [
            SizedBox(width: 360, child: listPane),
            VerticalDivider(width: 1, color: AppColors.borderColor),
            Expanded(
              child: selected == null
                  ? _EmptyCallDetail()
                  : _CallDetail(
                      call: selected,
                      onCall: () => _redial(selected),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileCalls() {
    return Consumer2<CallsController, ContactsController>(
      builder: (context, callsController, contactsController, _) {
        final query = _callSearch.text.trim().toLowerCase();
        final calls = callsController.filteredCalls;
        final contacts = contactsController.savedContacts
            .where(
              (contact) => '${contact.displayName} ${contact.matricule}'
                  .toLowerCase()
                  .contains(query),
            )
            .toList();
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: Column(
            children: [
              _SearchField(
                controller: _callSearch,
                hint: _text(
                  'Rechercher des personnes ou des numéros',
                  'Search people or numbers',
                ),
                onChanged: (value) {
                  callsController.setSearchQuery(value);
                  setState(() {});
                },
              ),
              if (contactsController.savedContacts.isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 86,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: contactsController.savedContacts.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final contact = contactsController.savedContacts[index];
                      return SizedBox(
                        width: 64,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _callContact(contact),
                          child: Column(
                            children: [
                              _Avatar(
                                initials: contact.initials,
                                color: contact.color,
                                size: 56,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                contact.displayName.split(' ').first,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ] else
                const SizedBox(height: 14),
              _SegmentedChoice(
                choices: const ['recent', 'contacts'],
                labels: {
                  'recent': _text('Récents', 'Recent'),
                  'contacts': _text('Contacts', 'Contacts'),
                },
                selected: _mobileCallsTab,
                expanded: true,
                onSelected: (value) => setState(() => _mobileCallsTab = value),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _mobileCallsTab == 'contacts'
                    ? contactsController.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : contacts.isEmpty
                          ? Center(
                              child: Text(
                                _text(
                                  'Aucun contact enregistré',
                                  'No saved contacts',
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 70),
                              itemCount: contacts.length,
                              itemBuilder: (context, index) {
                                final contact = contacts[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  leading: _Avatar(
                                    initials: contact.initials,
                                    color: contact.color,
                                    size: 46,
                                  ),
                                  title: Text(
                                    contact.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(contact.matricule),
                                  trailing: IconButton(
                                    tooltip: _text('Appeler', 'Call'),
                                    onPressed: () => _callContact(contact),
                                    icon: const Icon(
                                      Icons.call_outlined,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  onTap: () => _callContact(contact),
                                );
                              },
                            )
                    : callsController.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : calls.isEmpty
                    ? Center(
                        child: Text(
                          _text('Aucun appel récent', 'No calls yet'),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 70),
                        itemCount: calls.length,
                        itemBuilder: (context, index) => _CallListTile(
                          call: calls[index],
                          selected: false,
                          compact: true,
                          onTap: () => _redial(calls[index]),
                          onCall: () => _redial(calls[index]),
                          onDelete: () =>
                              callsController.deleteCallLog(calls[index].id),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeople({required bool mobile}) {
    if (mobile) return _buildMobilePeople();
    return Consumer<ContactsController>(
      builder: (context, controller, _) {
        final contacts = controller.currentList;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            mobile ? 18 : 28,
            20,
            mobile ? 18 : 28,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchField(
                controller: _peopleSearch,
                hint: _text(
                  'Rechercher par nom, identifiant ou matricule',
                  'Search by name, username, or matricule',
                ),
                onChanged: controller.setSearchQuery,
              ),
              const SizedBox(height: 14),
              _SegmentedChoice(
                choices: const ['Saved Contacts', 'All Users'],
                labels: {
                  'Saved Contacts': _text(
                    'Contacts enregistrés',
                    'Saved Contacts',
                  ),
                  'All Users': _text('Tous les utilisateurs', 'All Users'),
                },
                selected: controller.selectedTab,
                onSelected: controller.setSelectedTab,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    controller.selectedTab == 'Saved Contacts'
                        ? _text('Vos contacts', 'Your people')
                        : _text('Répertoire', 'Directory'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 8),
                  _CountBadge(count: contacts.length),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : contacts.isEmpty
                    ? _EmptyState(
                        icon: Icons.people_outline_rounded,
                        title: controller.selectedTab == 'Saved Contacts'
                            ? _text(
                                'Aucun contact enregistré',
                                'No saved contacts',
                              )
                            : _text('Aucun résultat', 'No matches found'),
                        message: controller.selectedTab == 'Saved Contacts'
                            ? _text(
                                'Recherchez des personnes dans le répertoire et enregistrez-les ici.',
                                'Search the directory and save people here.',
                              )
                            : _text(
                                'Essayez un autre nom ou matricule.',
                                'Try a different name or matricule.',
                              ),
                        action: controller.selectedTab == 'Saved Contacts'
                            ? OutlinedButton.icon(
                                onPressed: () =>
                                    controller.setSelectedTab('All Users'),
                                icon: const Icon(Icons.search_rounded),
                                label: Text(
                                  _text(
                                    'Parcourir le répertoire',
                                    'Browse directory',
                                  ),
                                ),
                              )
                            : null,
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 900
                              ? 3
                              : constraints.maxWidth >= 560
                              ? 2
                              : 1;
                          final isDirectory =
                              controller.selectedTab == 'All Users';
                          return GridView.builder(
                            itemCount: contacts.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  mainAxisExtent: isDirectory
                                      ? 176
                                      : columns == 1
                                      ? 108
                                      : 232,
                                ),
                            itemBuilder: (context, index) => isDirectory
                                ? _DirectoryPersonCard(
                                    contact: contacts[index],
                                    saved: controller.savedContacts.any(
                                      (item) => item.id == contacts[index].id,
                                    ),
                                    onSave: () => _saveContact(
                                      controller,
                                      contacts[index],
                                    ),
                                    onCall: (isVideo) => launchDirectCall(
                                      context,
                                      isVideo: isVideo,
                                      recipientUserId: contacts[index].id,
                                      recipientName:
                                          contacts[index].displayName,
                                      recipientMatricule:
                                          contacts[index].matricule,
                                    ),
                                  )
                                : _PersonCard(
                                    contact: contacts[index],
                                    showSave:
                                        controller.selectedTab == 'All Users',
                                    compact: columns == 1,
                                    onCall: () => _callContact(contacts[index]),
                                    onSave: () => _saveContact(
                                      controller,
                                      contacts[index],
                                    ),
                                  ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addByMatricule() async {
    final value = await _showTextEditor(
      title: _text('Ajouter par matricule', 'Add by matricule'),
      label: _text('Matricule', 'Matricule'),
      initialValue: '',
    );
    if (value == null || !mounted) return;
    final matricule = value.trim().toUpperCase();
    if (!RegExp(r'^([A-Z]\d{7}|\d{7}[A-Z])$').hasMatch(matricule)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              'Utilisez une lettre au début ou à la fin et sept chiffres.',
              'Use one letter at the start or end and seven digits.',
            ),
          ),
        ),
      );
      return;
    }
    final controller = context.read<ContactsController>();
    final matches = await ContactsService().searchAllUsers(matricule);
    if (!mounted) return;
    final exact = matches.where(
      (item) => item.matricule.toUpperCase() == matricule,
    );
    if (exact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_text('Personne introuvable', 'Person not found')),
        ),
      );
      return;
    }
    await _saveContact(controller, exact.first);
  }

  Widget _buildMobilePeople() {
    return Consumer<ContactsController>(
      builder: (context, controller, _) {
        final query = _peopleSearch.text.trim().toLowerCase();
        final people = controller.allUsers
            .where(
              (person) =>
                  '${person.displayName} ${person.username} ${person.matricule} ${person.department ?? ''}'
                      .toLowerCase()
                      .contains(query),
            )
            .toList();
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text('Le répertoire Callwave', 'Callwave directory'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              _SearchField(
                controller: _peopleSearch,
                hint: _text(
                  'Nom, matricule ou service',
                  'Name, matricule or department',
                ),
                onChanged: (value) {
                  controller.setSelectedTab('All Users');
                  controller.setSearchQuery(value);
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.refreshData,
                  child: controller.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: people.isEmpty ? 1 : people.length,
                          itemBuilder: (context, index) {
                            if (people.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 28,
                                ),
                                child: Text(
                                  _text('Aucun résultat', 'No matches found'),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }
                            final person = people[index];
                            final saved = controller.savedContacts.any(
                              (item) => item.id == person.id,
                            );
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 8,
                              ),
                              child: Row(
                                children: [
                                  _Avatar(
                                    initials: person.initials,
                                    color: person.color,
                                    size: 46,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          person.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          [
                                            person.matricule,
                                            if (person.department?.isNotEmpty ==
                                                true)
                                              person.department!,
                                          ].join(' · '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    tooltip: saved
                                        ? _text('Ajouté', 'Added')
                                        : _text('Ajouter', 'Add'),
                                    onPressed: saved
                                        ? null
                                        : () =>
                                              _saveContact(controller, person),
                                    icon: Icon(
                                      saved
                                          ? Icons.check_rounded
                                          : Icons.add_rounded,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveContact(
    ContactsController controller,
    ContactItem item,
  ) async {
    final saved = await controller.saveContact(item);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? _text('Contact enregistré', 'Contact saved')
              : _text(
                  'Impossible d’enregistrer le contact',
                  'Could not save contact',
                ),
        ),
      ),
    );
  }

  Widget _buildJoin({required bool mobile}) {
    final parsed = MeetingLinkService.parseInput(_roomCode.text);
    final canJoin = parsed.roomId.isNotEmpty;
    if (mobile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _text(
                'Saisissez le code de salle reçu.',
                'Enter the room code you were given.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _roomCode,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => canJoin ? _joinRoom() : null,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.videocam_outlined),
                hintText: _text('Code de salle ou lien', 'Room code or link'),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: canJoin ? _joinRoom : null,
                icon: const Icon(Icons.videocam_outlined),
                label: Text(_text('Rejoindre l’appel', 'Join call')),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(mobile ? 20 : 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Row(
            children: [
              if (!mobile)
                Expanded(
                  child: Container(
                    height: 330,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E9E64), Color(0xFF117A4D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.video_call_rounded,
                        size: 78,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              if (!mobile) const SizedBox(width: 28),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text('Rejoindre un appel', 'Join a call'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _text(
                        'Saisissez un code de salle ou collez un lien d’invitation.',
                        'Enter a room code or paste an invitation link.',
                      ),
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _roomCode,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => canJoin ? _joinRoom() : null,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.link_rounded),
                        hintText: _text(
                          'Code de salle ou lien d’invitation',
                          'Room code or invitation link',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: canJoin ? _joinRoom : null,
                        icon: const Icon(Icons.video_call_rounded),
                        label: Text(_text('Rejoindre l’appel', 'Join call')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettings({required bool mobile}) {
    return Consumer2<SettingsController, AuthController>(
      builder: (context, controller, auth, _) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final l10n = AppLocalizations.of(context);
        final settings = controller.settings;
        final user = auth.currentUser;
        final displayName = settings.displayName.isNotEmpty
            ? settings.displayName
            : (user?['display_name'] ??
                      user?['displayName'] ??
                      user?['username'] ??
                      _text('Votre profil', 'Your profile'))
                  .toString();
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            mobile ? 18 : 30,
            20,
            mobile ? 18 : 30,
            28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PreferenceGroup(
                    title: l10n.profileSection,
                    subtitle: l10n.profileSubtitle,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            _Avatar(
                              initials: _initials(displayName),
                              color: AppColors.primary,
                              size: 56,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    settings.matricule.isEmpty
                                        ? _text(
                                            'Compte Callwave',
                                            'Callwave account',
                                          )
                                        : settings.matricule,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: _text('Modifier le nom', 'Edit name'),
                              onPressed: () => _editDisplayName(displayName),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ],
                        ),
                      ),
                      _PreferenceRow(
                        title: l10n.statusLabel,
                        subtitle: l10n.statusSubtitle,
                        control: DropdownButton<String>(
                          isExpanded: mobile,
                          value: settings.status,
                          underline: const SizedBox.shrink(),
                          items:
                              {
                                    'Available': l10n.statusAvailable,
                                    'Busy': l10n.statusBusy,
                                    'Away': l10n.statusAway,
                                    'Do Not Disturb': l10n.statusDnd,
                                  }.entries
                                  .map(
                                    (entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              controller.updateProfile(status: value);
                            }
                          },
                        ),
                      ),
                      _PreferenceRow(
                        title: l10n.hidePhoneMatricule,
                        subtitle: l10n.hidePhoneMatriculeSubtitle,
                        control: Switch(
                          value: settings.hidePhoneEmail,
                          onChanged: (value) =>
                              controller.updateProfile(hidePhoneEmail: value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PreferenceGroup(
                    title: l10n.orgSection,
                    subtitle: l10n.orgSubtitle,
                    children: [
                      _profileField(
                        title: l10n.matriculeId,
                        value: settings.matricule,
                        onSave: (value) =>
                            controller.updateProfile(matricule: value),
                      ),
                      _profileField(
                        title: l10n.ministryOrg,
                        value: settings.ministry,
                        onSave: (value) =>
                            controller.updateProfile(ministry: value),
                      ),
                      _profileField(
                        title: l10n.department,
                        value: settings.department,
                        onSave: (value) =>
                            controller.updateProfile(department: value),
                      ),
                      _profileField(
                        title: l10n.division,
                        value: settings.division,
                        onSave: (value) =>
                            controller.updateProfile(division: value),
                      ),
                      _profileField(
                        title: l10n.positionTitle,
                        value: settings.positionTitle,
                        onSave: (value) =>
                            controller.updateProfile(positionTitle: value),
                      ),
                      _profileField(
                        title: l10n.officeLocation,
                        value: settings.officeLocation,
                        onSave: (value) =>
                            controller.updateProfile(officeLocation: value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PreferenceGroup(
                    title: l10n.callingSection,
                    subtitle: l10n.callingSubtitle,
                    children: [
                      _PreferenceRow(
                        title: l10n.cameraOnJoin,
                        subtitle: l10n.cameraOnJoinSubtitle,
                        control: Switch(
                          value: settings.cameraOnJoin,
                          onChanged: (value) =>
                              controller.updateCalling(cameraOnJoin: value),
                        ),
                      ),
                      _PreferenceRow(
                        title: l10n.micOnJoin,
                        subtitle: l10n.micOnJoinSubtitle,
                        control: Switch(
                          value: settings.micOnJoin,
                          onChanged: (value) =>
                              controller.updateCalling(micOnJoin: value),
                        ),
                      ),
                      _PreferenceRow(
                        title: l10n.noiseSuppression,
                        subtitle: l10n.noiseSuppressionSubtitle,
                        control: Switch(
                          value: settings.noiseSuppression,
                          onChanged: (value) =>
                              controller.updateCalling(noiseSuppression: value),
                        ),
                      ),
                      _PreferenceRow(
                        title: l10n.lowDataMode,
                        subtitle: l10n.lowDataModeSubtitle,
                        control: Switch(
                          value: settings.lowDataMode,
                          onChanged: (value) =>
                              controller.updateCalling(lowDataMode: value),
                        ),
                      ),
                      _PreferenceRow(
                        title: l10n.defaultCallQuality,
                        subtitle: l10n.defaultCallQualitySubtitle,
                        control: DropdownButton<String>(
                          isExpanded: mobile,
                          value: settings.callQuality,
                          underline: const SizedBox.shrink(),
                          items:
                              {
                                    'Auto': _text('Automatique', 'Auto'),
                                    'High': _text('Élevée', 'High'),
                                    'Medium': _text('Moyenne', 'Medium'),
                                    'Low': _text('Faible', 'Low'),
                                  }.entries
                                  .map(
                                    (entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              controller.updateCalling(callQuality: value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PreferenceGroup(
                    title: l10n.notificationsSection,
                    subtitle: l10n.notificationsSubtitle,
                    children: [
                      _PreferenceRow(
                        title: l10n.incomingCallNotif,
                        subtitle: l10n.incomingCallNotifSubtitle,
                        control: Switch(
                          value: settings.incomingCallNotif,
                          onChanged: (value) => controller.updateNotifications(
                            incomingCallNotif: value,
                          ),
                        ),
                      ),
                      _PreferenceRow(
                        title: l10n.missedCallNotif,
                        subtitle: l10n.missedCallNotifSubtitle,
                        control: Switch(
                          value: settings.missedCallNotif,
                          onChanged: (value) => controller.updateNotifications(
                            missedCallNotif: value,
                          ),
                        ),
                      ),
                      _PreferenceRow(
                        title: l10n.messageNotif,
                        subtitle: l10n.messageNotifSubtitle,
                        control: Switch(
                          value: settings.messageNotif,
                          onChanged: (value) => controller.updateNotifications(
                            messageNotif: value,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PreferenceGroup(
                    title: l10n.appearanceSection,
                    subtitle: l10n.appearanceSubtitle,
                    children: [
                      _PreferenceRow(
                        title: l10n.themeLabel,
                        subtitle: l10n.themeSubtitle,
                        control: _SegmentedChoice(
                          choices: const ['System', 'Light', 'Dark'],
                          expanded: mobile,
                          labels: {
                            'System': l10n.themeSystem,
                            'Light': l10n.themeLight,
                            'Dark': l10n.themeDark,
                          },
                          selected: settings.theme,
                          onSelected: (value) =>
                              controller.updateAppearance(theme: value),
                        ),
                      ),
                      _PreferenceRow(
                        title: l10n.languageLabel,
                        subtitle: l10n.languageSubtitle,
                        control: _SegmentedChoice(
                          choices: const ['French', 'English'],
                          expanded: mobile,
                          labels: {
                            'French': l10n.languageFrench,
                            'English': l10n.languageEnglish,
                          },
                          selected: settings.language,
                          onSelected: (value) =>
                              controller.updateAppearance(language: value),
                        ),
                      ),
                      _PreferenceRow(
                        title: l10n.animatedBg,
                        subtitle: l10n.animatedBgSubtitle,
                        control: Switch(
                          value: settings.animatedBg,
                          onChanged: (value) =>
                              controller.updateAppearance(animatedBg: value),
                        ),
                      ),
                      _PreferenceRow(
                        title: l10n.reduceMotion,
                        subtitle: l10n.reduceMotionSubtitle,
                        control: Switch(
                          value: settings.reduceMotion,
                          onChanged: (value) =>
                              controller.updateAppearance(reduceMotion: value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    onPressed: _isSigningOut ? null : _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(l10n.logout),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class _WorkspaceTextEditor extends StatefulWidget {
  const _WorkspaceTextEditor({
    required this.title,
    required this.label,
    required this.initialValue,
  });

  final String title;
  final String label;
  final String initialValue;

  @override
  State<_WorkspaceTextEditor> createState() => _WorkspaceTextEditorState();
}

class _WorkspaceTextEditorState extends State<_WorkspaceTextEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class _UserAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Consumer<AuthController>(
    builder: (context, auth, _) {
      final user = auth.currentUser;
      final name =
          (user?['display_name'] ??
                  user?['displayName'] ??
                  user?['username'] ??
                  'User')
              .toString()
              .trim();
      final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
      final initials = parts
          .take(2)
          .map((part) => part[0].toUpperCase())
          .join();
      return Tooltip(
        message: name,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            initials.isEmpty ? 'U' : initials,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    },
  );
}

class _PreferenceGroup extends StatelessWidget {
  const _PreferenceGroup({
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 860) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface
                  .withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Theme.of(context).colorScheme.surface
                    .withValues(alpha: 0.78),
              ),
            ),
            child: Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  if (index > 0)
                    Divider(height: 1, color: AppColors.borderColor),
                  children[index],
                ],
              ],
            ),
          ),
        ],
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderColor),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.title,
    required this.subtitle,
    required this.control,
  });
  final String title;
  final String subtitle;
  final Widget control;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final label = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      );
      final compact = constraints.maxWidth < 520 && control is! Switch;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  label,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: control),
                ],
              )
            : Row(
                children: [
                  Expanded(child: label),
                  const SizedBox(width: 12),
                  Flexible(child: control),
                ],
              ),
      );
    },
  );
}

class _NavigationRail extends StatelessWidget {
  const _NavigationRail({required this.activePage, required this.onSelect});
  final String activePage;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: 84,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
        border: Border(right: BorderSide(color: AppColors.borderColor)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset('assets/logo/logo.png', width: 42, height: 42),
            ),
          ),
          Divider(height: 1, color: AppColors.borderColor),
          const SizedBox(height: 12),
          _RailButton(
            icon: Icons.phone_rounded,
            label: l10n.navCalls,
            selected: activePage == 'calls',
            onTap: () => onSelect('calls'),
          ),
          _RailButton(
            icon: Icons.people_alt_rounded,
            label: l10n.text(fr: 'Personnes', en: 'People'),
            selected: activePage == 'people',
            onTap: () => onSelect('people'),
          ),
          _RailButton(
            icon: Icons.video_call_rounded,
            label: l10n.join,
            selected: activePage == 'join',
            onTap: () => onSelect('join'),
          ),
          const Spacer(),
          _RailButton(
            icon: Icons.settings_rounded,
            label: l10n.navSettings,
            selected: false,
            onTap: () => onSelect('settings'),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _UserAvatar(),
          ),
        ],
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({required this.activePage, required this.onSelect});
  final String activePage;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      ('calls', Icons.phone_rounded, l10n.navCalls),
      (
        'people',
        Icons.people_alt_rounded,
        l10n.text(fr: 'Personnes', en: 'People'),
      ),
      ('join', Icons.video_call_rounded, l10n.join),
      ('settings', Icons.settings_rounded, l10n.navSettings),
    ];
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
        border: Border.all(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.78),
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: items.map((item) {
          final selected = item.$1 == activePage;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(item.$1),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.13)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.$2,
                        size: 22,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textMuted,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 66,
            height: 62,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.13)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.primary = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: primary
            ? theme.colorScheme.primary
            : theme.colorScheme.surface.withValues(alpha: 0.72),
        foregroundColor: primary
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.primary,
      ),
      icon: Icon(icon),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.search_rounded),
      hintText: hint,
    ),
  );
}

class _SegmentedChoice extends StatelessWidget {
  const _SegmentedChoice({
    required this.choices,
    required this.selected,
    required this.onSelected,
    this.labels = const {},
    this.badge = 0,
    this.expanded = false,
  });
  final List<String> choices;
  final String selected;
  final ValueChanged<String> onSelected;
  final Map<String, String> labels;
  final int badge;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        border: Border.all(color: AppColors.borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: choices.map((choice) {
          final active = selected == choice;
          final button = InkWell(
            onTap: () => onSelected(choice),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    labels[choice] ?? choice,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: active ? Colors.white : AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (choice == 'Missed' && badge > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$badge',
                      style: TextStyle(
                        color: active ? Colors.white : AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
          return expanded ? Expanded(child: button) : button;
        }).toList(),
      ),
    );
  }
}

class _CallListTile extends StatelessWidget {
  const _CallListTile({
    required this.call,
    required this.selected,
    required this.onTap,
    required this.onCall,
    required this.onDelete,
    this.compact = false,
  });
  final CallLog call;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onCall;
  final VoidCallback onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final signalColor = call.isMissed ? AppColors.error : AppColors.primary;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.14)
          : compact
          ? Colors.transparent
          : theme.colorScheme.surface.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        onLongPress: compact
            ? () async {
                final remove = await showModalBottomSheet<bool>(
                  context: context,
                  builder: (context) => SafeArea(
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: Text(
                        l10n.text(
                          fr: 'Supprimer de l’historique',
                          en: 'Remove from history',
                        ),
                      ),
                      onTap: () => Navigator.pop(context, true),
                    ),
                  ),
                );
                if (remove == true) onDelete();
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              _Avatar(initials: call.initials, color: call.color, size: 46),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      call.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: compact && call.isMissed
                            ? AppColors.error
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          call.isMissed
                              ? Icons.call_missed_rounded
                              : call.isOutgoing
                              ? Icons.call_made_rounded
                              : Icons.call_received_rounded,
                          size: 14,
                          color: signalColor,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '${call.time} · ${call.duration}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: compact && call.isMissed
                                  ? AppColors.error
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.callAgain,
                onPressed: onCall,
                icon: Icon(
                  call.isGroup ? Icons.groups_rounded : Icons.call_rounded,
                  color: AppColors.primary,
                ),
              ),
              if (!compact)
                PopupMenuButton<String>(
                  tooltip: l10n.text(fr: 'Plus d’options', en: 'More options'),
                  onSelected: (value) {
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        l10n.text(
                          fr: 'Supprimer de l’historique',
                          en: 'Remove from history',
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCallDetail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _EmptyState(
      icon: Icons.call_outlined,
      title: l10n.text(fr: 'Sélectionnez un appel', en: 'Select a call'),
      message: l10n.text(
        fr: 'Les détails de l’appel apparaîtront ici.',
        en: 'Call details will appear here.',
      ),
    );
  }
}

class _CallDetail extends StatelessWidget {
  const _CallDetail({required this.call, required this.onCall});
  final CallLog call;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Avatar(initials: call.initials, color: call.color, size: 120),
            const SizedBox(height: 20),
            Text(
              call.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 7),
            Text(
              call.isGroup
                  ? '${call.participants ?? 0} ${l10n.participants.toLowerCase()}'
                  : call.isOutgoing
                  ? l10n.text(fr: 'Appel sortant', en: 'Outgoing call')
                  : l10n.incomingCall,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _CountBadge(label: call.time),
                if (call.duration.isNotEmpty) _CountBadge(label: call.duration),
                if (call.isMissed)
                  _CountBadge(label: l10n.missedCall, color: AppColors.error),
              ],
            ),
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: onCall,
              icon: const Icon(Icons.call_rounded),
              label: Text(call.isGroup ? l10n.startGroupCall : l10n.callAgain),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectoryPersonCard extends StatelessWidget {
  const _DirectoryPersonCard({
    required this.contact,
    required this.saved,
    required this.onSave,
    required this.onCall,
  });

  final ContactItem contact;
  final bool saved;
  final VoidCallback onSave;
  final ValueChanged<bool> onCall;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(
                  initials: contact.initials,
                  color: contact.color,
                  size: 52,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        contact.matricule,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 18,
              child: Text(
                contact.department ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: saved ? null : onSave,
                  icon: Icon(
                    saved ? Icons.check_rounded : Icons.add_rounded,
                    size: 18,
                  ),
                  label: Text(
                    saved
                        ? l10n.text(fr: 'Ajouté', en: 'Added')
                        : l10n.text(fr: 'Ajouter', en: 'Add'),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 36),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: l10n.text(fr: 'Appel audio', en: 'Audio call'),
                  onPressed: () => onCall(false),
                  icon: const Icon(
                    Icons.call_outlined,
                    size: 19,
                    color: AppColors.primary,
                  ),
                ),
                IconButton(
                  tooltip: l10n.text(fr: 'Appel vidéo', en: 'Video call'),
                  onPressed: () => onCall(true),
                  icon: const Icon(
                    Icons.videocam_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.contact,
    required this.showSave,
    required this.compact,
    required this.onCall,
    required this.onSave,
  });
  final ContactItem contact;
  final bool showSave;
  final bool compact;
  final VoidCallback onCall;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final avatar = _Avatar(
      initials: contact.initials,
      color: contact.color,
      size: compact ? 46 : 54,
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          contact.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        Text(
          '@${contact.username}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        if (!compact) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _CountBadge(label: contact.matricule, color: AppColors.textMuted),
              if (contact.department?.isNotEmpty == true)
                _CountBadge(
                  label: contact.department!,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ],
      ],
    );
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onCall,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 18),
          child: compact
              ? Row(
                  children: [
                    avatar,
                    const SizedBox(width: 12),
                    Expanded(child: identity),
                    if (showSave)
                      IconButton(
                        tooltip: l10n.addContact,
                        onPressed: onSave,
                        icon: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                    IconButton.filled(
                      tooltip: l10n.callTo,
                      onPressed: onCall,
                      icon: const Icon(Icons.call_rounded),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        avatar,
                        const Spacer(),
                        if (showSave)
                          IconButton(
                            tooltip: l10n.addContact,
                            onPressed: onSave,
                            icon: const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    identity,
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onCall,
                        icon: const Icon(Icons.call_rounded),
                        label: Text(l10n.callTo),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initials,
    required this.color,
    required this.size,
  });
  final String initials;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Text(
      initials,
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.32,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({this.count, this.label, this.color = AppColors.primary});
  final int? count;
  final String? label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.11),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label ?? '$count',
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 42,
            color: AppColors.primary.withValues(alpha: 0.58),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    ),
  );
}
