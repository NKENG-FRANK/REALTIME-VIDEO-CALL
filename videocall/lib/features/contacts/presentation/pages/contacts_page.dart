import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/widgets/animated_background.dart';
import '../../../../core/widgets/hover_widgets.dart';
import 'package:videocall/features/call/presentation/widgets/call_launcher_dialogs.dart';
import '../../domain/models/contact.dart';
import '../controllers/contacts_controller.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({Key? key}) : super(key: key);

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _Contact {
  const _Contact({
    required this.name,
    required this.matricule,
    required this.status,
    required this.initials,
    required this.color,
    this.online = false,
    this.group = false,
    this.participants,
  });

  final String name;
  final String matricule;
  final String status;
  final String initials;
  final Color color;
  final bool online;
  final bool group;
  final int? participants;
}

class _ContactsPageState extends State<ContactsPage> {
  final _searchController = TextEditingController();
  String _selectedTab = 'All';
  String _selectedFilter = 'All contacts';

  static const _contacts = [
    _Contact(
      name: 'James Liu',
      matricule: 'M00984521',
      status: 'Away',
      initials: 'JL',
      color: Color(0xFF159AB5),
    ),
    _Contact(
      name: 'Alex Morgan',
      matricule: 'A00123948',
      status: 'Offline',
      initials: 'AM',
      color: Color(0xFF7B58F5),
    ),
    _Contact(
      name: 'Ryan Kim',
      matricule: 'R00847102',
      status: 'Offline',
      initials: 'RK',
      color: Color(0xFFE31845),
    ),
    _Contact(
      name: 'Design Team',
      matricule: 'D00994120',
      status: '5 participants',
      initials: 'DT',
      color: AppColors.primary,
      group: true,
      participants: 5,
    ),
    _Contact(
      name: 'Engineering',
      matricule: 'E00389102',
      status: '9 participants',
      initials: 'EN',
      color: Color(0xFFFFA00D),
      group: true,
      participants: 9,
    ),
    _Contact(
      name: 'Emma Stone',
      matricule: 'E00582910',
      status: 'Offline',
      initials: 'ES',
      color: Color(0xFF10A47D),
    ),
  ];

  static const _onlineContacts = [
    _Contact(
      name: 'Sarah Chen',
      matricule: 'S00847102',
      status: 'Online',
      initials: 'SC',
      color: Color(0xFF8752F4),
      online: true,
    ),
    _Contact(
      name: 'Marcus Webb',
      matricule: 'M00001092',
      status: 'Online',
      initials: 'MW',
      color: Color(0xFF10A47D),
      online: true,
    ),
    _Contact(
      name: 'Priya Nair',
      matricule: 'P00472910',
      status: 'Online',
      initials: 'PN',
      color: Color(0xFFFFA00D),
      online: true,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_Contact> get _filteredContacts {
    final query = _searchController.text.trim().toLowerCase();
    return _contacts.where((contact) {
      final matchesSearch =
          query.isEmpty ||
          contact.name.toLowerCase().contains(query) ||
          contact.matricule.toLowerCase().contains(query);
      final matchesFilter =
          _selectedFilter == 'All contacts' ||
          (_selectedFilter == 'People' && !contact.group) ||
          (_selectedFilter == 'Groups' && contact.group);
      final matchesTab =
          _selectedTab == 'All' ||
          (_selectedTab == 'Favorites' && contact.name == 'Emma Stone') ||
          (_selectedTab == 'Groups' && contact.group);
      return matchesSearch && matchesFilter && matchesTab;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AnimatedBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 760;
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.74),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isMobile
                      ? _buildMobileLayout()
                      : _buildDesktopLayout(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(width: 186, child: _buildSidebar()),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildMobileHeader(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: const Color(0xFFEAF4EE).withOpacity(0.84),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 19, 15, 19),
            child: Row(
              children: [
                _brandMark(),
                const SizedBox(width: 9),
                const Text(
                  'Callwave',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFD7E5DB)),
          const SizedBox(height: 14),
          _navItem(Icons.phone, AppLocalizations.of(context).navCalls, route: '/calls'),
          _navItem(Icons.people_alt, AppLocalizations.of(context).navContacts, selected: true, route: '/contacts'),
          _navItem(Icons.settings, AppLocalizations.of(context).navSettings, route: '/settings'),
          const Spacer(),
          const Divider(height: 1, color: Color(0xFFD7E5DB)),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Consumer<SettingsController>(
              builder: (context, settingsCtrl, _) {
                final displayName = settingsCtrl.settings.displayName;
                final initials = _getInitials(displayName);
                return Row(
                  children: [
                    _avatar(initials, AppColors.primary),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const _OnlineLabel(),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      color: const Color(0xFFEAF4EE).withOpacity(0.9),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: [
          _brandMark(),
          const SizedBox(width: 9),
          const Text(
            'Callwave',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.menu, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, {bool selected = false, String? route}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      child: InkWell(
        onTap: route != null && !selected
            ? () => Navigator.of(context).pushReplacementNamed(route)
            : null,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFCDE8D8) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? const Color(0xFF2387C4) : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Consumer<ContactsController>(
      builder: (context, controller, _) {
        return Column(
          children: [
            _buildPageHeader(controller),
            Expanded(
              child: SmoothScrollView(
                padding: const EdgeInsets.fromLTRB(26, 22, 26, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchBar(controller),
                    const SizedBox(height: 20),
                    _buildTabs(controller),
                    const SizedBox(height: 16),
                    if (controller.onlineContacts.isNotEmpty) ...[
                      Text(
                        AppLocalizations.of(context).online.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 9),
                      _buildOnlineRow(controller),
                      const SizedBox(height: 21),
                    ],
                    Text(
                      AppLocalizations.of(context).allContacts.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 9),
                    _buildContactsTable(controller),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPageHeader(ContactsController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 17, 26, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDCE7DF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).contactsTitle,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppLocalizations.of(context).contactsSubtitle,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          SmoothActionButton(
            icon: Icons.groups_rounded,
            label: AppLocalizations.of(context).startGroupCall,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            onPressed: () => showGroupCallLaunchDialog(context),
          ),
          const SizedBox(width: 9),
          SmoothActionButton(
            icon: Icons.person_add_alt_1_rounded,
            label: AppLocalizations.of(context).oneToOneCall,
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.primary,
            onPressed: () => showOneToOneCallLaunchDialog(context),
          ),
          const SizedBox(width: 9),
          SmoothActionButton(
            icon: Icons.person_add,
            label: AppLocalizations.of(context).addContact,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            onPressed: () => _showAddContactDialog(context, controller),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ContactsController controller) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: (val) => controller.setSearchQuery(val),
            style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).searchContacts,
              hintStyle: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 17,
                color: AppColors.textMuted,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.75),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0EAE2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0EAE2)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 130,
          height: 38,
          child: DropdownButtonFormField<String>(
            value: controller.selectedFilter,
            onChanged: (value) {
              if (value != null) controller.setSelectedFilter(value);
            },
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              filled: true,
              fillColor: Colors.white.withOpacity(0.75),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0EAE2)),
              ),
            ),
            items: [
              DropdownMenuItem(value: 'All contacts', child: Text(AppLocalizations.of(context).allContacts)),
              DropdownMenuItem(value: 'Online', child: Text(AppLocalizations.of(context).online)),
              DropdownMenuItem(value: 'Offline', child: Text(AppLocalizations.of(context).offline)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(ContactsController controller) {
    return Row(
      children: [
        _tab('All', isSelected: controller.selectedTab == 'All', onTap: () => controller.setSelectedTab('All')),
        const SizedBox(width: 16),
        _tab('Favorites', isSelected: controller.selectedTab == 'Favorites', onTap: () => controller.setSelectedTab('Favorites')),
        const SizedBox(width: 16),
        _tab('Groups', isSelected: controller.selectedTab == 'Groups', onTap: () => controller.setSelectedTab('Groups')),
      ],
    );
  }

  Widget _tab(String label, {required bool isSelected, required VoidCallback onTap}) {
    return HoverBuilder(
      onTap: onTap,
      builder: (context, isHovered, isPressed) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isHovered ? AppColors.primary.withOpacity(0.1) : Colors.white.withOpacity(0.72)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }

  Widget _buildOnlineRow(ContactsController controller) {
    final online = controller.onlineContacts;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: online
              .map(
                (contact) => SizedBox(
                  width: (constraints.maxWidth - 20) / 3,
                  child: _onlineCard(contact),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _onlineCard(Contact contact) {
    return SmoothHoverCard(
      onTap: () => Navigator.of(context).pushNamed('/connecting'),
      normalColor: Colors.white.withOpacity(0.86),
      hoverColor: Colors.white,
      borderRadius: 12,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _avatar(contact.initials, contact.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const _OnlineLabel(),
              ],
            ),
          ),
          _iconAction(
            contact.name == 'Marcus Webb' ? Icons.phone : Icons.videocam,
            onTap: () => Navigator.of(context).pushNamed('/connecting'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsTable(ContactsController controller) {
    if (controller.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    final contacts = controller.filteredContacts;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 20,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: contacts.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Text(
                  'No contacts found',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            )
          : Column(children: [_tableHeader(), ...contacts.map((c) => _contactRow(c, controller))]),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: const BoxDecoration(
        color: Color(0xFFF0F7F1),
        border: Border(bottom: BorderSide(color: Color(0xFFDCE7DF))),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('NAME', style: _headerStyle)),
          Expanded(flex: 3, child: Text('MATRICULE', style: _headerStyle)),
          Expanded(flex: 2, child: Text('STATUS', style: _headerStyle)),
          SizedBox(width: 34),
        ],
      ),
    );
  }

  Widget _contactRow(Contact contact, ContactsController controller) {
    return SmoothHoverCard(
      onTap: () => Navigator.of(context).pushNamed('/call'),
      normalColor: Colors.transparent,
      hoverColor: Colors.white.withOpacity(0.7),
      borderRadius: 0,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      border: const Border(bottom: BorderSide(color: Color(0xFFE1EAE3))),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _avatar(contact.initials, contact.color, small: true),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    contact.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              contact.matricule,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              contact.status,
              style: TextStyle(
                fontSize: 10,
                color: contact.status == 'Away'
                    ? const Color(0xFFE6A100)
                    : AppColors.textMuted,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              contact.isFavorite ? Icons.star : Icons.more_vert,
              size: 16,
              color: contact.isFavorite ? Colors.amber : AppColors.textMuted,
            ),
            onSelected: (value) {
              if (value == 'favorite') {
                controller.toggleFavorite(contact.id);
              } else if (value == 'delete') {
                controller.deleteContact(contact.id);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'favorite',
                child: Text(
                  contact.isFavorite ? 'Remove Favorite' : 'Mark Favorite',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Contact', style: TextStyle(fontSize: 11, color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddContactDialog(BuildContext context, ContactsController controller) {
    final nameCtrl = TextEditingController();
    final matriculeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Contact', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Alex Smith'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: matriculeCtrl,
              decoration: const InputDecoration(
                labelText: 'Matricule',
                hintText: 'e.g. M00984521 (>8 chars, starting/ending with a letter)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final matricule = matriculeCtrl.text.trim();
              if (name.isNotEmpty) {
                if (!Contact.isValidMatricule(matricule)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Matricule must be more than 8 characters and start or end with a letter (e.g. M00984521).'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }
                final initials = name.split(' ').map((e) => e[0].toUpperCase()).take(2).join();
                controller.addContact(
                  Contact(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    matricule: matricule,
                    status: 'Available',
                    initials: initials,
                    colorValue: 0xFF159AB5,
                    online: true,
                  ),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    String label,
    Color background,
    Color foreground,
  ) {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _iconAction(IconData icon, {bool light = false, VoidCallback? onTap}) {
    return HoverBuilder(
      onTap: onTap,
      builder: (context, isHovered, isPressed) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 39,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: light
                ? (isHovered ? const Color(0xFFDCECE0) : const Color(0xFFE9F3EB))
                : (isHovered ? AppColors.primary.withOpacity(0.85) : AppColors.primary),
            borderRadius: BorderRadius.circular(8),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Icon(
            icon,
            size: 15,
            color: light ? AppColors.textMuted : Colors.white,
          ),
        );
      },
    );
  }

  Widget _brandMark() => Container(
    width: 25,
    height: 25,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(7),
    ),
    child: const Text(
      'C',
      style: TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w900,
        fontSize: 13,
      ),
    ),
  );

  Widget _avatar(String initials, Color color, {bool small = false}) =>
      Container(
        width: small ? 30 : 34,
        height: small ? 30 : 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: small ? 9 : 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _OnlineLabel extends StatelessWidget {
  const _OnlineLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('•', style: TextStyle(color: Color(0xFF4DBB55), fontSize: 13)),
        const SizedBox(width: 3),
        Text(AppLocalizations.of(context).online,
            style: const TextStyle(color: Color(0xFF4DBB55), fontSize: 9)),
      ],
    );
  }
}

const _headerStyle = TextStyle(
  color: AppColors.textMuted,
  fontSize: 9,
  fontWeight: FontWeight.w900,
);

String _getInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return 'ME';
  if (parts.length == 1) {
    return parts[0][0].toUpperCase();
  }
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
