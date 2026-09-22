import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/widgets/animated_background.dart';
import '../../../../core/widgets/hover_widgets.dart';
import '../../../../core/services/contacts_service.dart';
import '../controllers/contacts_controller.dart';
import '../../../call/presentation/widgets/call_launcher_dialogs.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({Key? key}) : super(key: key);

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _launchCall(BuildContext context, ContactItem item) {
    showCallTypeSelectionDialog(
      context,
      recipientName: item.displayName,
      recipientMatricule: item.matricule,
      recipientUserId: item.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AnimatedBackground(),
          SafeArea(
            child: Row(
              children: [
                _buildSidebar(context),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: Color(0xFFEAF4EE),
        border: Border(right: BorderSide(color: Color(0xFFDCE7DF))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 19, 15, 19),
            child: Row(
              children: [
                Container(
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
                ),
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
          _navItem(Icons.phone, 'Calls', false, () {
            Navigator.of(context).pushReplacementNamed('/calls');
          }),
          _navItem(Icons.people_alt, 'Contacts', true, () {}),
          _navItem(Icons.settings, 'Settings', false, () {
            Navigator.of(context).pushReplacementNamed('/settings');
          }),
          const Spacer(),
          const Divider(height: 1, color: Color(0xFFD7E5DB)),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Consumer<AuthController>(
              builder: (context, authController, _) {
                final user = authController.currentUser;
                
                final displayName = user != null 
                    ? (user['display_name'] ?? user['displayName'] ?? user['username'] ?? user['matricule'] ?? 'User') 
                    : 'User';
                    
                final String initials;
                if (user != null) {
                  final parts = displayName.trim().split(' ');
                  if (parts.isEmpty || parts.first.isEmpty) {
                    initials = 'U';
                  } else if (parts.length == 1) {
                    initials = parts.first[0].toUpperCase();
                  } else {
                    initials = (parts.first[0] + parts.last[0]).toUpperCase();
                  }
                } else {
                  initials = 'ME';
                }

                return Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
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
                          if (user != null && user['matricule'] != null)
                            Text(
                              user['matricule'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            const Text('Online', style: TextStyle(color: Color(0xFF4DBB55), fontSize: 9)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, size: 16, color: Colors.redAccent),
                      tooltip: AppLocalizations.of(context).logout,
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(AppLocalizations.of(context).logoutConfirmTitle),
                            content: Text(AppLocalizations.of(context).logoutConfirmMessage),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: Text(AppLocalizations.of(context).cancel),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: Text(AppLocalizations.of(context).logout),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true && context.mounted) {
                          authController.signOut();
                          Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
                        }
                      },
                    ),
                  ],
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool selected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: 0.6) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: selected ? AppColors.primary : AppColors.textMuted),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textMuted,
                  fontSize: 12,
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 22, 26, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchBar(controller),
                    const SizedBox(height: 20),
                    _buildTabs(controller),
                    const SizedBox(height: 16),
                    Text(
                      controller.selectedTab.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Expanded(child: _buildContactsTable(controller)),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contacts & Directory',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Select any user or contact to launch a direct audio/video call',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          SmoothActionButton(
            icon: Icons.refresh,
            label: 'Refresh',
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            onPressed: () => controller.refreshData(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ContactsController controller) {
    return TextField(
      controller: _searchController,
      onChanged: (val) => controller.setSearchQuery(val),
      style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search by name or matricule (e.g. A123456789)...',
        hintStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        prefixIcon: const Icon(Icons.search, size: 17, color: AppColors.textMuted),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.75),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0EAE2)),
        ),
      ),
    );
  }

  Widget _buildTabs(ContactsController controller) {
    return Row(
      children: [
        _tab('Saved Contacts', isSelected: controller.selectedTab == 'Saved Contacts', onTap: () {
          controller.setSelectedTab('Saved Contacts');
        }),
        const SizedBox(width: 16),
        _tab('All Users', isSelected: controller.selectedTab == 'All Users', onTap: () {
          controller.setSelectedTab('All Users');
        }),
      ],
    );
  }

  Widget _tab(String label, {required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textMuted,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildContactsTable(ContactsController controller) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final list = controller.currentList;

    if (list.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(13),
        ),
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: Text(
          controller.selectedTab == 'Saved Contacts'
              ? 'No saved contacts found. Switch to "All Users" to search and add contacts.'
              : 'No users found matching "${controller.searchQuery}"',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 20,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: ListView.separated(
        itemCount: list.length + 1,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE1EAE3)),
        itemBuilder: (context, index) {
          if (index == 0) return _tableHeader();
          final item = list[index - 1];
          return _contactRow(item, controller);
        },
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: const BoxDecoration(
        color: Color(0xFFF0F7F1),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(13), topRight: Radius.circular(13)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('NAME / USER', style: _headerStyle)),
          Expanded(flex: 3, child: Text('MATRICULE', style: _headerStyle)),
          Expanded(flex: 2, child: Text('DEPARTMENT', style: _headerStyle)),
          SizedBox(width: 80, child: Text('ACTION', style: _headerStyle)),
        ],
      ),
    );
  }

  Widget _contactRow(ContactItem item, ContactsController controller) {
    return SmoothHoverCard(
      onTap: () => _launchCall(context, item),
      normalColor: Colors.transparent,
      hoverColor: Colors.white.withValues(alpha: 0.7),
      borderRadius: 0,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _avatar(item.displayName),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '@${item.username}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              item.matricule,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.department ?? 'General',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              children: [
                if (controller.selectedTab == 'All Users') ...[
                  IconButton(
                    icon: const Icon(Icons.person_add_alt_1, size: 18, color: AppColors.primary),
                    tooltip: 'Save to Contacts',
                    onPressed: () async {
                      final ok = await controller.saveContact(item);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Contact saved!' : 'Failed to save contact')),
                        );
                      }
                    },
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.call, size: 18, color: AppColors.primary),
                  tooltip: 'Call Now',
                  onPressed: () => _launchCall(context, item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String name) {
    final initials = name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials.isNotEmpty ? initials : 'U',
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    color: AppColors.textMuted,
    fontSize: 9,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.5,
  );
}
