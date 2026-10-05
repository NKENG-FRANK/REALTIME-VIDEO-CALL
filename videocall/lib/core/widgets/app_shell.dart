import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme/app_colors.dart';
import '../../core/l10n/app_localizations.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';

/// Responsive shell: sidebar on desktop, bottom nav on mobile.
class AppShell extends StatelessWidget {
  final Widget child;
  final String activePage; // 'calls' | 'contacts' | 'settings'

  const AppShell({
    Key? key,
    required this.child,
    required this.activePage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 760;
        return isMobile
            ? _MobileShell(activePage: activePage, child: child)
            : _DesktopShell(activePage: activePage, child: child);
      },
    );
  }
}

// ── Desktop: sidebar + content ────────────────────────────────────────────────

class _DesktopShell extends StatelessWidget {
  final Widget child;
  final String activePage;
  const _DesktopShell({required this.child, required this.activePage});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 186, child: _AppSidebar(activePage: activePage)),
        Expanded(child: child),
      ],
    );
  }
}

// ── Mobile: content + bottom navigation bar ───────────────────────────────────

class _MobileShell extends StatelessWidget {
  final Widget child;
  final String activePage;
  const _MobileShell({required this.child, required this.activePage});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      _NavItem(icon: Icons.phone_rounded, label: l10n.navCalls, page: 'calls', route: '/calls'),
      _NavItem(icon: Icons.people_alt_rounded, label: l10n.navContacts, page: 'contacts', route: '/contacts'),
      _NavItem(icon: Icons.settings_rounded, label: l10n.navSettings, page: 'settings', route: '/settings'),
    ];

    return Column(
      children: [
        // Content area
        Expanded(child: child),
        // Bottom navigation
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.97),
            border: const Border(top: BorderSide(color: Color(0xFFDCE7DF))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: items.map((item) {
                  final selected = item.page == activePage;
                  return Expanded(
                    child: InkWell(
                      onTap: selected
                          ? null
                          : () => Navigator.of(context).pushReplacementNamed(item.route),
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary.withOpacity(0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              item.icon,
                              size: 22,
                              color: selected ? AppColors.primary : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                              color: selected ? AppColors.primary : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sidebar (desktop only) ────────────────────────────────────────────────────

class _AppSidebar extends StatelessWidget {
  final String activePage;
  const _AppSidebar({required this.activePage});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      color: const Color(0xFFEAF4EE).withOpacity(0.84),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 19, 15, 19),
            child: Row(
              children: [
                _BrandMark(),
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
          _SidebarNavItem(
            icon: Icons.phone_rounded,
            label: l10n.navCalls,
            selected: activePage == 'calls',
            onTap: activePage == 'calls'
                ? null
                : () => Navigator.of(context).pushReplacementNamed('/calls'),
          ),
          _SidebarNavItem(
            icon: Icons.people_alt_rounded,
            label: l10n.navContacts,
            selected: activePage == 'contacts',
            onTap: activePage == 'contacts'
                ? null
                : () => Navigator.of(context).pushReplacementNamed('/contacts'),
          ),
          _SidebarNavItem(
            icon: Icons.settings_rounded,
            label: l10n.navSettings,
            selected: activePage == 'settings',
            onTap: activePage == 'settings'
                ? null
                : () => Navigator.of(context).pushReplacementNamed('/settings'),
          ),
          const Spacer(),
          const Divider(height: 1, color: Color(0xFFD7E5DB)),
          Padding(
            padding: const EdgeInsets.all(13),
            child: _SidebarUserCard(),
          ),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFCDE8D8) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: selected ? AppColors.primary : AppColors.textMuted),
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
}

class _SidebarUserCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, _) {
        final user = authController.currentUser;
        final displayName = user != null
            ? (user['display_name'] ??
                user['displayName'] ??
                user['username'] ??
                user['matricule'] ??
                'User')
            : 'User';
        final parts = (displayName as String).trim().split(' ');
        final initials = parts.isEmpty || parts.first.isEmpty
            ? 'U'
            : parts.length == 1
                ? parts.first[0].toUpperCase()
                : '${parts.first[0]}${parts.last[0]}'.toUpperCase();

        return Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                  const SizedBox(height: 3),
                  if (user != null && user['matricule'] != null)
                    Text(user['matricule'], maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w600))
                  else
                    Row(children: const [
                      Text('•', style: TextStyle(color: Color(0xFF4DBB55), fontSize: 13)),
                      SizedBox(width: 3),
                      Text('Online', style: TextStyle(color: Color(0xFF4DBB55), fontSize: 9)),
                    ]),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout, size: 16, color: Colors.redAccent),
              tooltip: AppLocalizations.of(context).logout,
              onPressed: () async {
                final l10n = AppLocalizations.of(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.logoutConfirmTitle),
                    content: Text(l10n.logoutConfirmMessage),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.cancel)),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(l10n.logout),
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
    );
  }
}

class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 25,
        height: 25,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(7)),
        child: const Text('C', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 13)),
      );
}

class _NavItem {
  final IconData icon;
  final String label;
  final String page;
  final String route;
  const _NavItem({required this.icon, required this.label, required this.page, required this.route});
}
