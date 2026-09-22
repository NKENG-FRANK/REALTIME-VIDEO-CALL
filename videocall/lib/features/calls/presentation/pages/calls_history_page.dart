import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/widgets/animated_background.dart';
import '../../../../core/widgets/hover_widgets.dart';
import 'package:videocall/features/call/presentation/widgets/call_launcher_dialogs.dart';
import '../../domain/models/call_log.dart';
import '../controllers/calls_controller.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

/// Data model for a call history entry.
class _CallEntry {
  final String name;
  final String initials;
  final Color color;
  final String time;
  final String duration;
  final bool isMissed;
  final bool isOutgoing;
  final bool isGroup;
  final int? participants;

  const _CallEntry({
    required this.name,
    required this.initials,
    required this.color,
    required this.time,
    required this.duration,
    this.isMissed = false,
    this.isOutgoing = false,
    this.isGroup = false,
    this.participants,
  });
}

class CallsHistoryPage extends StatefulWidget {
  const CallsHistoryPage({Key? key}) : super(key: key);

  @override
  State<CallsHistoryPage> createState() => _CallsHistoryPageState();
}

class _CallsHistoryPageState extends State<CallsHistoryPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                    color: Colors.white.withValues(alpha: 0.74),
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
        SizedBox(width: 186, child: _buildSidebar('Calls')),
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

  // ── Sidebar (shared structure with contacts) ──

  Widget _buildSidebar(String activePage) {
    return Container(
      color: const Color(0xFFEAF4EE).withValues(alpha: 0.84),
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
          _navItem(Icons.phone, AppLocalizations.of(context).navCalls, selected: true, route: '/calls'),
          _navItem(Icons.people_alt, AppLocalizations.of(context).navContacts, route: '/contacts'),
          _navItem(Icons.settings, AppLocalizations.of(context).navSettings, route: '/settings'),
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
                    _avatar(initials, AppColors.primary),
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
                            const _OnlineLabel(),
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
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      color: const Color(0xFFEAF4EE).withValues(alpha: 0.9),
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

  // ── Content ──

  Widget _buildContent() {
    return Consumer<CallsController>(
      builder: (context, controller, _) {
        return Column(
          children: [
            _buildPageHeader(),
            Expanded(
              child: SmoothScrollView(
                padding: const EdgeInsets.fromLTRB(26, 22, 26, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchBar(controller),
                    const SizedBox(height: 20),
                    _buildTabs(controller),
                    const SizedBox(height: 6),
                    _buildCallsList(controller),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPageHeader() {
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
                  AppLocalizations.of(context).callsTitle,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppLocalizations.of(context).callsSubtitle,
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
        ],
      ),
    );
  }

  Widget _buildSearchBar(CallsController controller) {
    return TextField(
      controller: _searchController,
      onChanged: (val) => controller.setSearchQuery(val),
      style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context).search,
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
        fillColor: Colors.white.withValues(alpha: 0.75),
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
    );
  }

  Widget _buildTabs(CallsController controller) {
    return Row(
      children: [
        _tab('All', isSelected: controller.selectedTab == 'All', onTap: () => controller.setSelectedTab('All')),
        const SizedBox(width: 16),
        _tab('Missed', isSelected: controller.selectedTab == 'Missed', badge: controller.missedCount, onTap: () => controller.setSelectedTab('Missed')),
      ],
    );
  }

  Widget _tab(String label, {required bool isSelected, int? badge, required VoidCallback onTap}) {
    return HoverBuilder(
      onTap: onTap,
      builder: (context, isHovered, isPressed) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isHovered && !isSelected
                ? AppColors.primary.withOpacity(0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : (isHovered ? AppColors.primary : AppColors.textMuted),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              if (badge != null && badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.callDecline,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCallsList(CallsController controller) {
    if (controller.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    final calls = controller.filteredCalls;
    if (calls.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text(
            AppLocalizations.of(context).noCallHistory,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      );
    }
    return Column(
      children: calls.map((call) => _callRow(call, controller)).toList(),
    );
  }

  Widget _callRow(CallLog call, CallsController controller) {
    return SmoothHoverCard(
      onTap: () {
        if (call.isGroup) {
          showGroupCallLaunchDialog(context);
        } else {
          showCallTypeSelectionDialog(
            context,
            recipientName: call.name,
            recipientMatricule: '',
          );
        }
      },
      normalColor: call.isMissed
          ? const Color(0xFFFDE8E8).withValues(alpha: 0.45)
          : Colors.transparent,
      hoverColor: call.isMissed
          ? const Color(0xFFFCDADA).withValues(alpha: 0.65)
          : Colors.white.withOpacity(0.7),
      borderRadius: 8,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: const Border(
        bottom: BorderSide(color: Color(0xFFE8EFE9)),
      ),
      child: Row(
        children: [
          // Avatar
          _avatar(call.initials, call.color),
          const SizedBox(width: 14),
          // Name + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      call.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (call.isGroup) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EFE9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${call.participants} people',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                    if (call.isMissed) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.callDecline,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          AppLocalizations.of(context).missedCall,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Direction icon
                    Icon(
                      call.isMissed
                          ? Icons.close
                          : call.isOutgoing
                              ? Icons.call_made
                              : Icons.call_received,
                      size: 11,
                      color: call.isMissed
                          ? AppColors.callDecline
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      call.time,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Duration / delete menu
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (call.duration.isNotEmpty)
                Text(
                  call.duration,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                )
              else
                Text(
                  '—',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.callDecline.withValues(alpha: 0.5),
                  ),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 16, color: AppColors.textMuted),
                onSelected: (value) {
                  if (value == 'delete') {
                    controller.deleteCallLog(call.id);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Log', style: TextStyle(fontSize: 11, color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ──

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
        textStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
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

  Widget _avatar(String initials, Color color) => Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
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
        const Text('•',
            style: TextStyle(color: Color(0xFF4DBB55), fontSize: 13)),
        const SizedBox(width: 3),
        Text(AppLocalizations.of(context).online,
            style: const TextStyle(color: Color(0xFF4DBB55), fontSize: 9)),
      ],
    );
  }
}

String _getInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return 'ME';
  if (parts.length == 1) {
    return parts[0][0].toUpperCase();
  }
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
