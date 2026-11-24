import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/services/meeting_link_service.dart';
import '../../../../core/widgets/animated_background.dart';
import '../../../call/presentation/pages/audio_call_page.dart';
import '../../../call/presentation/pages/call_page.dart';
import '../controllers/auth_controller.dart';
import '../widgets/segmented_auth_switch.dart';
import '../widgets/sign_in_form.dart';
import '../widgets/sign_up_form.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  /// Navigate to call or calls history after successful auth
  void _navigateAfterAuth(BuildContext context) {
    final pending = MeetingLinkService.consumePendingJoin();
    if (pending != null && pending.roomId.isNotEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => pending.isVideo
              ? CallPage(
                  callTitle: pending.title ?? 'Meeting ${pending.roomId}',
                  roomId: pending.roomId,
                  isVideoCall: true,
                  isGroupCall: true,
                  participantCount: 2,
                )
              : AudioCallPage(
                  callTitle: pending.title ?? 'Meeting ${pending.roomId}',
                  roomId: pending.roomId,
                  contactName: pending.title ?? 'Meeting',
                  contactMatricule: pending.roomId,
                  isGroupCall: true,
                  participantCount: 2,
                ),
        ),
      );
      return;
    }
    Navigator.of(context).pushReplacementNamed('/calls');
  }

  Widget _buildPendingJoinBanner(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pending = MeetingLinkService.pendingJoinLink;
    if (pending == null || pending.roomId.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.meeting_room_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.join}: ${pending.title ?? pending.roomId}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.text(
                    fr: 'Connectez-vous ou créez un compte pour rejoindre la réunion.',
                    en: 'Sign in or register to join the meeting.',
                  ),
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authCtrl = context.watch<AuthController>();
    if (authCtrl.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          _navigateAfterAuth(context);
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient animated soft gradient blobs matching app shell
          const AnimatedBackground(),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 780;
                return Center(
                  child: isMobile
                      ? _buildMobileLayout(context, authCtrl)
                      : _buildDesktopLayout(context, authCtrl),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Desktop / Tablet Layout ──
  Widget _buildDesktopLayout(
    BuildContext context,
    AuthController authController,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Container(
            height: 660,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowColor,
                  blurRadius: 42,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: _buildBrandPanel(context)),
                Expanded(
                  flex: 6,
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.88),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 40,
                    ),
                    child: Center(
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: _buildFormContent(context, authController),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandPanel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF27B576), Color(0xFF117A4D)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Image.asset('assets/logo/logo.png', fit: BoxFit.contain),
          ),
          const Spacer(),
          const Text(
            'Callwave',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.text(
              fr: 'Vos conversations,\nplus proches et plus claires.',
              en: 'Your conversations,\ncloser and clearer.',
            ),
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              height: 1.18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.text(
              fr: 'Des appels audio et vidéo privés pour les personnes et les équipes qui comptent.',
              en: 'Private voice and video calls for the people and teams that matter.',
            ),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _brandFeature(
                Icons.hub_outlined,
                l10n.text(fr: 'Hébergement privé', en: 'Private hosting'),
              ),
              _brandFeature(
                Icons.graphic_eq_rounded,
                l10n.text(fr: 'Voix claire', en: 'Clear voice'),
              ),
              _brandFeature(
                Icons.videocam_outlined,
                l10n.text(fr: 'Vidéo HD', en: 'HD video'),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).officialSecurityTag,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _brandFeature(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent(
    BuildContext context,
    AuthController authController, {
    bool mobile = false,
  }) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPendingJoinBanner(context),
        Text(
          authController.isSignUp
              ? l10n.createAccountTitle
              : mobile
              ? l10n.signIn
              : l10n.welcomeTitle,
          style: TextStyle(
            fontSize: mobile ? 24 : 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        if (!mobile) ...[
          const SizedBox(height: 6),
          Text(
            authController.isSignUp
                ? l10n.text(
                    fr: 'Créez votre compte Callwave pour commencer.',
                    en: 'Set up your Callwave account to get started.',
                  )
                : l10n.text(
                    fr: 'Connectez-vous pour reprendre là où vous en étiez.',
                    en: 'Sign in to pick up where you left off.',
                  ),
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          SegmentedAuthSwitch(
            isSignUp: authController.isSignUp,
            onModeChanged: (_) => authController.toggleAuthMode(),
          ),
          const SizedBox(height: 22),
        ] else
          const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: authController.isSignUp
              ? SignUpForm(
                  key: const ValueKey('signup-form'),
                  fullName: authController.fullName,
                  matricule: authController.matricule,
                  password: authController.password,
                  showPassword: authController.showPassword,
                  errorMessage: authController.errorMessage,
                  onFullNameChanged: authController.updateFullName,
                  onMatriculeChanged: authController.updateMatricule,
                  onPasswordChanged: authController.updatePassword,
                  onTogglePassword: authController.togglePasswordVisibility,
                  onSignIn: authController.toggleAuthMode,
                  onSignUp: () async {
                    final success = await authController.signUp();
                    if (success && context.mounted) _navigateAfterAuth(context);
                  },
                  isLoading: authController.isLoading,
                )
              : SignInForm(
                  key: const ValueKey('signin-form'),
                  matricule: authController.matricule,
                  password: authController.password,
                  showPassword: authController.showPassword,
                  rememberMe: authController.rememberMe,
                  errorMessage: authController.errorMessage,
                  onMatriculeChanged: authController.updateMatricule,
                  onPasswordChanged: authController.updatePassword,
                  onTogglePassword: authController.togglePasswordVisibility,
                  onToggleRememberMe: authController.toggleRememberMe,
                  onSignUp: authController.toggleAuthMode,
                  onSignIn: () async {
                    final success = await authController.signIn();
                    if (success && context.mounted) _navigateAfterAuth(context);
                  },
                  isLoading: authController.isLoading,
                ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            l10n.officialSecurityTag,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  // ── Mobile Layout ──
  Widget _buildMobileLayout(
    BuildContext context,
    AuthController authController,
  ) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final preferredHeight = authController.isSignUp ? 176.0 : 236.0;
        final headerHeight = preferredHeight
            .clamp(0, constraints.maxHeight * 0.34)
            .toDouble();
        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: headerHeight + 40,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF22B573), Color(0xFF0E6B4A)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (headerHeight > 160) ...[
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              'assets/logo/logo.png',
                              width: 44,
                              height: 44,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Callwave',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    Flexible(
                      child: Text(
                        authController.isSignUp
                            ? l10n.createAccountTitle
                            : l10n.welcomeTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: headerHeight,
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                  child: _buildFormContent(
                    context,
                    authController,
                    mobile: true,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
