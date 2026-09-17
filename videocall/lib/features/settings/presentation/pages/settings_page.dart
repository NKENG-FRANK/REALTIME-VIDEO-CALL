import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/widgets/animated_background.dart';
import '../../../../core/widgets/hover_widgets.dart';
import '../../../contacts/domain/models/contact.dart';
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
          _appNavItem(context, Icons.phone, AppLocalizations.of(context).navCalls, selected: false, route: '/calls'),
          _appNavItem(context, Icons.people_alt, AppLocalizations.of(context).navContacts, selected: false, route: '/contacts'),
          _appNavItem(context, Icons.settings, AppLocalizations.of(context).navSettings, selected: true, route: '/settings'),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).settingsTitle,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppLocalizations.of(context).settingsSubtitle,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context).savedSuccessfully),
                  duration: const Duration(seconds: 2),
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
            child: Text(AppLocalizations.of(context).saveChanges),
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
                      title: AppLocalizations.of(context).profileSection,
                      subtitle: AppLocalizations.of(context).profileSubtitle,
                      children: [
                        _buildProfileRow(s, context),
                        const _SectionDivider(),
                        _EditableTextSetting(
                          title: AppLocalizations.of(context).displayName,
                          subtitle: AppLocalizations.of(context).displayNameSubtitle,
                          value: s.displayName,
                          onChanged: (v) => controller.updateProfile(displayName: v),
                        ),
                        const _SectionDivider(),
                        _buildDropdownSetting(
                          title: AppLocalizations.of(context).statusLabel,
                          subtitle: AppLocalizations.of(context).statusSubtitle,
                          value: s.status,
                          options: ['Available', 'Busy', 'Away', 'Do Not Disturb'],
                          displayOptions: [
                            AppLocalizations.of(context).statusAvailable,
                            AppLocalizations.of(context).statusBusy,
                            AppLocalizations.of(context).statusAway,
                            AppLocalizations.of(context).statusDnd,
                          ],
                          onChanged: (v) => controller.updateProfile(status: v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Organizational Information section
                    _buildSectionCard(
                      title: AppLocalizations.of(context).orgSection,
                      subtitle: AppLocalizations.of(context).orgSubtitle,
                      children: [
                        _EditableTextSetting(
                          title: AppLocalizations.of(context).matriculeId,
                          subtitle: AppLocalizations.of(context).matriculeIdSubtitle,
                          value: s.matricule,
                          validator: (val) {
                            if (val.trim().isNotEmpty && !Contact.isValidMatricule(val)) {
                              return AppLocalizations.of(context).matriculeValidationError;
                            }
                            return null;
                          },
                          onChanged: (v) => controller.updateProfile(matricule: v),
                        ),
                        const _SectionDivider(),
                        _EditableTextSetting(
                          title: AppLocalizations.of(context).ministryOrg,
                          subtitle: AppLocalizations.of(context).ministryOrgSubtitle,
                          value: s.ministry,
                          onChanged: (v) => controller.updateProfile(ministry: v),
                        ),
                        const _SectionDivider(),
                        _EditableTextSetting(
                          title: AppLocalizations.of(context).department,
                          subtitle: AppLocalizations.of(context).departmentSubtitle,
                          value: s.department,
                          onChanged: (v) => controller.updateProfile(department: v),
                        ),
                        const _SectionDivider(),
                        _EditableTextSetting(
                          title: AppLocalizations.of(context).division,
                          subtitle: AppLocalizations.of(context).divisionSubtitle,
                          value: s.division,
                          onChanged: (v) => controller.updateProfile(division: v),
                        ),
                        const _SectionDivider(),
                        _EditableTextSetting(
                          title: AppLocalizations.of(context).positionTitle,
                          subtitle: AppLocalizations.of(context).positionTitleSubtitle,
                          value: s.positionTitle,
                          onChanged: (v) => controller.updateProfile(positionTitle: v),
                        ),
                        const _SectionDivider(),
                        _EditableTextSetting(
                          title: AppLocalizations.of(context).officeLocation,
                          subtitle: AppLocalizations.of(context).officeLocationSubtitle,
                          value: s.officeLocation,
                          onChanged: (v) => controller.updateProfile(officeLocation: v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Directory Privacy section
                    _buildSectionCard(
                      title: AppLocalizations.of(context).privacySection,
                      subtitle: AppLocalizations.of(context).privacySubtitle,
                      children: [
                        _buildToggleSetting(
                          title: AppLocalizations.of(context).hidePhoneMatricule,
                          subtitle: AppLocalizations.of(context).hidePhoneMatriculeSubtitle,
                          value: s.hidePhoneEmail,
                          onChanged: (v) => controller.updateProfile(hidePhoneEmail: v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Calling section
                    _buildSectionCard(
                      title: AppLocalizations.of(context).callingSection,
                      subtitle: AppLocalizations.of(context).callingSubtitle,
                      children: [
                        _buildToggleSetting(
                          title: AppLocalizations.of(context).cameraOnJoin,
                          subtitle: AppLocalizations.of(context).cameraOnJoinSubtitle,
                          value: s.cameraOnJoin,
                          onChanged: (v) => controller.updateCalling(cameraOnJoin: v),
                        ),
                        const _SectionDivider(),
                        _buildToggleSetting(
                          title: AppLocalizations.of(context).micOnJoin,
                          subtitle: AppLocalizations.of(context).micOnJoinSubtitle,
                          value: s.micOnJoin,
                          onChanged: (v) => controller.updateCalling(micOnJoin: v),
                        ),
                        const _SectionDivider(),
                        _buildToggleSetting(
                          title: AppLocalizations.of(context).noiseSuppression,
                          subtitle: AppLocalizations.of(context).noiseSuppressionSubtitle,
                          value: s.noiseSuppression,
                          onChanged: (v) => controller.updateCalling(noiseSuppression: v),
                        ),
                        const _SectionDivider(),
                        _buildToggleSetting(
                          title: AppLocalizations.of(context).lowDataMode,
                          subtitle: AppLocalizations.of(context).lowDataModeSubtitle,
                          value: s.lowDataMode,
                          onChanged: (v) => controller.updateCalling(lowDataMode: v),
                        ),
                        const _SectionDivider(),
                        _buildDropdownSetting(
                          title: AppLocalizations.of(context).defaultCallQuality,
                          subtitle: AppLocalizations.of(context).defaultCallQualitySubtitle,
                          value: s.callQuality,
                          options: ['Auto', 'High', 'Medium', 'Low'],
                          onChanged: (v) => controller.updateCalling(callQuality: v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Notifications section
                    _buildSectionCard(
                      title: AppLocalizations.of(context).notificationsSection,
                      subtitle: AppLocalizations.of(context).notificationsSubtitle,
                      children: [
                        _buildToggleSetting(
                          title: AppLocalizations.of(context).incomingCallNotif,
                          subtitle: AppLocalizations.of(context).incomingCallNotifSubtitle,
                          value: s.incomingCallNotif,
                          onChanged: (v) => controller.updateNotifications(incomingCallNotif: v),
                        ),
                        const _SectionDivider(),
                        _buildToggleSetting(
                          title: AppLocalizations.of(context).missedCallNotif,
                          subtitle: AppLocalizations.of(context).missedCallNotifSubtitle,
                          value: s.missedCallNotif,
                          onChanged: (v) => controller.updateNotifications(missedCallNotif: v),
                        ),
                        const _SectionDivider(),
                        _buildToggleSetting(
                          title: AppLocalizations.of(context).messageNotif,
                          subtitle: AppLocalizations.of(context).messageNotifSubtitle,
                          value: s.messageNotif,
                          onChanged: (v) => controller.updateNotifications(messageNotif: v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Appearance section
                    _buildSectionCard(
                      title: AppLocalizations.of(context).appearanceSection,
                      subtitle: AppLocalizations.of(context).appearanceSubtitle,
                      children: [
                        _buildDropdownSetting(
                          title: AppLocalizations.of(context).themeLabel,
                          subtitle: AppLocalizations.of(context).themeSubtitle,
                          value: s.theme,
                          options: ['Light', 'Dark', 'System'],
                          displayOptions: [
                            AppLocalizations.of(context).themeLight,
                            AppLocalizations.of(context).themeDark,
                            AppLocalizations.of(context).themeSystem,
                          ],
                          onChanged: (v) => controller.updateAppearance(theme: v),
                        ),
                        const _SectionDivider(),
                        _buildDropdownSetting(
                          title: AppLocalizations.of(context).languageLabel,
                          subtitle: AppLocalizations.of(context).languageSubtitle,
                          value: s.language,
                          options: ['French', 'English'],
                          displayOptions: [
                            AppLocalizations.of(context).languageFrench,
                            AppLocalizations.of(context).languageEnglish,
                          ],
                          onChanged: (v) => controller.updateAppearance(language: v),
                        ),
                        const _SectionDivider(),
                        _buildToggleSetting(
                          title: AppLocalizations.of(context).animatedBg,
                          subtitle: AppLocalizations.of(context).animatedBgSubtitle,
                          value: s.animatedBg,
                          onChanged: (v) => controller.updateAppearance(animatedBg: v),
                        ),
                        const _SectionDivider(),
                        _buildToggleSetting(
                          title: AppLocalizations.of(context).reduceMotion,
                          subtitle: AppLocalizations.of(context).reduceMotionSubtitle,
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

  Widget _buildProfileRow(UserSettings settings, BuildContext context) {
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
            child: Text(
              AppLocalizations.of(context).changePhoto,
              style: const TextStyle(
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
    List<String>? displayOptions, // localised labels, parallel to options
    required ValueChanged<String> onChanged,
  }) {
    final displays = displayOptions ?? options;
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
              items: List.generate(options.length, (i) =>
                  DropdownMenuItem(
                    value: options[i],
                    child: Text(displays[i]),
                  )
              ),
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
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        const Text('•',
            style: TextStyle(color: Color(0xFF4DBB55), fontSize: 13)),
        const SizedBox(width: 3),
        Text(l10n.online,
            style: const TextStyle(color: Color(0xFF4DBB55), fontSize: 9)),
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
  final String? Function(String)? validator;

  const _EditableTextSetting({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.validator,
  }) : super(key: key);

  @override
  State<_EditableTextSetting> createState() => _EditableTextSettingState();
}

class _EditableTextSettingState extends State<_EditableTextSetting> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  String? _errorText;

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

  void _handleChange(String val) {
    if (widget.validator != null) {
      setState(() {
        _errorText = widget.validator!(val);
      });
    }
    if (_errorText == null) {
      widget.onChanged(val);
    }
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
                if (_errorText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _errorText!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 180,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _handleChange,
              onSubmitted: _handleChange,
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
                hintText: 'Enter text',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _errorText != null ? Colors.redAccent : const Color(0xFFCDE8D8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _errorText != null ? Colors.redAccent : const Color(0xFFD0E0D4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _errorText != null ? Colors.redAccent : AppColors.primary, width: 1.5),
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
