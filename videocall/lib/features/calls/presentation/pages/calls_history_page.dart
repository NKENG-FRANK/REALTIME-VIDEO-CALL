import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/widgets/animated_background.dart';
import '../../../../core/widgets/hover_widgets.dart';
import '../../../../core/widgets/app_shell.dart';
import 'package:videocall/features/call/presentation/widgets/call_launcher_dialogs.dart';
import '../../domain/models/call_log.dart';
import '../../../../core/services/signaling_service.dart';
import '../controllers/calls_controller.dart';

class CallsHistoryPage extends StatefulWidget {
  const CallsHistoryPage({Key? key}) : super(key: key);

  @override
  State<CallsHistoryPage> createState() => _CallsHistoryPageState();
}

class _CallsHistoryPageState extends State<CallsHistoryPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SignalingService>().ensureConnected();
      }
    });
  }

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
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.74),
              ),
              clipBehavior: Clip.antiAlias,
              child: AppShell(
                activePage: 'calls',
                child: _buildContent(),
              ),
            ),
          ),
        ],
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
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
              if (isMobile) ...[
                IconButton(
                  icon: const Icon(Icons.groups_rounded, color: AppColors.primary),
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary.withOpacity(0.1)),
                  onPressed: () => showGroupCallLaunchDialog(context),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
                  style: IconButton.styleFrom(backgroundColor: AppColors.accent),
                  onPressed: () => showOneToOneCallLaunchDialog(context),
                ),
              ] else ...[
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
            ],
          ),
        );
      },
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
            recipientUserId: call.contactUserId ?? '',
          );
        }
      },
      normalColor: call.isMissed
          ? const Color(0xFFFDE8E8).withOpacity(0.45)
          : Colors.transparent,
      hoverColor: call.isMissed
          ? const Color(0xFFFCDADA).withOpacity(0.65)
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
                    Flexible(
                      child: Text(
                        call.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
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
                    color: AppColors.callDecline.withOpacity(0.5),
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
