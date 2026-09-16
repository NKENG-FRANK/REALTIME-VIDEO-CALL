import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/widgets/animated_background.dart';
import '../../../../core/widgets/hover_widgets.dart';
import '../../domain/models/user_settings.dart';
import '../controllers/settings_controller.dart';

/// A single setting item definition.
class _SettingToggle {
  final String title;
  final String subtitle;
  final bool value;

  const _SettingToggle({
    required this.title,
    required this.subtitle,
    required this.value,
  });
}

/// A dropdown setting definition.
class _SettingDropdown {
  final String title;
  final String subtitle;
  final String value;
  final List<String> options;

  const _SettingDropdown({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
  });
}

/// Settings page with left navigation panel and scrollable
/// settings sections: Profile, Calling, Notifications, Appearance.
class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

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
                      ? _buildMobileLayout(context)
                      : _buildDesktopLayout(context),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 186, child: _buildAppSidebar(context)),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        _buildMobileHeader(),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  // ── App Sidebar (shared with contacts/calls) ──

  Widget _buildAppSidebar(BuildContext context) {
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
          _appNavItem(context, Icons.phone, 'Calls', selected: false, route: '/calls'),
          _appNavItem(context, Icons.people_alt, 'Contacts', selected: false, route: '/contacts'),
          _appNavItem(context, Icons.settings, 'Settings', selected: true, route: '/settings'),
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

  Widget _appNavItem(BuildContext context, IconData icon, String label, {bool selected = false, String? route}) {
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

  Widget _buildPageHeader(BuildContext context) {
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
                  'Settings',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Manage your Callwave experience',
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings saved successfully!'),
                  duration: Duration(seconds: 2),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 11),
              textStyle: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        final s = controller.settings;
        return Column(
          children: [
            _buildPageHeader(context),
            Expanded(
              child: SmoothScrollView(
                padding: const EdgeInsets.all(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile section
                    _buildSectionCard(
                      title: 'Profile',
                      subtitle: 'How other Callwave users see you.',
                      children: [
                        _buildProfileRow(s),
                        const _SectionDivider(),
                        _EditableTextSetting(
                          title: 'Display name',
                          subtitle: 'The name shown during calls and in contacts.',
                          value: s.displayName,
                          onChanged: (v) => controller.updateProfile(displayName: v),
                        ),
                        const _SectionDivider(),
                        _buildDropdownSetting(
                          title: 'Status',
                          subtitle: "Let people know when you're available.",
                          value: s.status,
                          options: ['Available', 'Busy', 'Away', 'Do Not Disturb'],
                          onChanged: (v) => controller.updateProfile(status: v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Calling section
                    _buildSectionCard(
                      title: 'Calling',
                      subtitle: 'Configure your audio and video call behavior.',
                      children: [
                        _buildToggleSetting(
                          title: 'Camera on when joining',
                          subtitle:
                              'Automatically enable your camera when starting a video call.',
                          value: s.cameraOnJoin,
                          onChanged: (v) => controller.updateCalling(cameraOnJoin: v),
                        ),
                        const _SectionDivider(),
                        _buildToggleSetting(
                          title: 'Microphone on when joining',
                          subtitle:
                              'Automatically enable your microphone when entering a call.',
                          value: s.micOnJoin,
                          onChanged: (v) => controller.updateCalling(micOnJoin: v),
                        ),
                        const _SectionDivider(),
                        _buildToggleSetting(
                          title: 'Noise suppression',
                          subtitle: 'Reduce background sounds during calls.',
                          value: s.noiseSuppression,
                          onChanged: (v) => controller.updateCalling(noiseSuppression: v),
                        ),
                        const _SectionDivider(),
                        _buildDropdownSetting(
                          title: 'Default call quality',
                          subtitle:
                              'Choose how aggressively Callwave adapts quality.',
                          value: s.callQuality,
                          options: ['Auto', 'High', 'Medium', 'Low'],
                          onChanged: (v) => controller.updateCalling(callQuality: v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Notifications section
                    _buildSectionCard(
                      title: 'Notifications',
                      subtitle: 'Control how Callwave alerts you.',
                      children: [
                        _buildToggleSetting(
                          title: 'Incoming call notifications',
                          subtitle:
                              'Show notifications for incoming audio and video calls.',
                          value: s.incomingCallNotif,
                          onChanged: (v) => controller.updateNotifications(incomingCallNotif: v),
                        ),
                        const _SectionDivider(),
                        _buildToggleSetting(
                          title: 'Missed call notifications',
                          subtitle: 'Notify you when you miss a call.',
                          value: s.missedCallNotif,
                          onChanged: (v) => controller.updateNotifications(missedCallNotif: v),
                        ),
                        const _SectionDivider(),
                        _buildToggleSetting(
                          title: 'Message notifications',
                          subtitle: 'Show alerts for new chat messages.',
                          value: s.messageNotif,
                          onChanged: (v) => controller.updateNotifications(messageNotif: v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Appearance section
                    _buildSectionCard(
                      title: 'Appearance',
                      subtitle: 'Customize the Callwave interface.',
                      children: [
                        _buildDropdownSetting(
                          title: 'Theme',
                          subtitle: 'Choose how Callwave looks.',
                          value: s.theme,
                          options: ['Light', 'Dark', 'System'],
                          onChanged: (v) => controller.updateAppearance(theme: v),
                        ),
                        const _SectionDivider(),
                        _buildToggleSetting(
                          title: 'Animated background',
                          subtitle:
                              'Show the soft animated shapes throughout the interface.',
                          value: s.animatedBg,
                          onChanged: (v) => controller.updateAppearance(animatedBg: v),
                        ),
                        const _SectionDivider(),
                        _buildToggleSetting(
                          title: 'Reduce motion',
                          subtitle: 'Reduce background and interface animations.',
                          value: s.reduceMotion,
                          onChanged: (v) => controller.updateAppearance(reduceMotion: v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Section card wrapper ──

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return SmoothHoverCard(
      normalColor: Colors.white.withValues(alpha: 0.65),
      hoverColor: Colors.white.withValues(alpha: 0.85),
      borderRadius: 14,
      border: Border.all(color: const Color(0xFFE0EAE2).withValues(alpha: 0.6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE8EFE9)),
          // Settings items
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Individual setting builders ──

  Widget _buildProfileRow(UserSettings settings) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      child: Row(
        children: [
          // Large avatar
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              _getInitials(settings.displayName),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${settings.displayName.toLowerCase().replaceAll(' ', '.')}@callwave.app',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.onlineGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.onlineGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    settings.status,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onlineGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Change photo button
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.accent),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Change photo',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleSetting({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSetting({
    required String title,
    required String subtitle,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: value,
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 11),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFFE0EAE2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFFE0EAE2)),
                ),
              ),
              items: options
                  .map((o) =>
                      DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ──

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
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _OnlineLabel extends StatelessWidget {
  const _OnlineLabel();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Text('•',
            style: TextStyle(color: Color(0xFF4DBB55), fontSize: 13)),
        SizedBox(width: 3),
        Text('Online',
            style: TextStyle(color: Color(0xFF4DBB55), fontSize: 9)),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 22,
      endIndent: 22,
      color: Color(0xFFE8EFE9),
    );
  }
}

class _EditableTextSetting extends StatefulWidget {
  final String title;
  final String subtitle;
  final String value;
  final ValueChanged<String> onChanged;

  const _EditableTextSetting({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<_EditableTextSetting> createState() => _EditableTextSettingState();
}

class _EditableTextSettingState extends State<_EditableTextSetting> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _EditableTextSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text && !_focusNode.hasFocus) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 180,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              onSubmitted: widget.onChanged,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.9),
                hintText: 'Enter username',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCDE8D8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFD0E0D4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
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
