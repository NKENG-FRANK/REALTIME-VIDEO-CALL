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
import '../widgets/welcome_panel.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({Key? key}) : super(key: key);

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

  Widget _buildPendingJoinBanner() {
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
                  'Join Meeting: ${pending.title ?? pending.roomId}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Sign in or register to join immediately',
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
      backgroundColor: const Color(0xFFF6F8F7),
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
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Center(
        child: Container(
          width: 960,
          height: 610,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              // Left Showcase Panel
              Expanded(
                flex: 9,
                child: WelcomePanel(
                  isSignUp: authController.isSignUp,
                  onSignInTap: () => authController.toggleAuthMode(),
                ),
              ),

              // Right Form Container
              Expanded(
                flex: 11,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 36),
                  child: Center(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildPendingJoinBanner(),

                            // Segmented Switcher
                            SegmentedAuthSwitch(
                              isSignUp: authController.isSignUp,
                              onModeChanged: (_) => authController.toggleAuthMode(),
                            ),
                            const SizedBox(height: 24),

                            // Form with smooth animated transition
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                              child: authController.isSignUp
                                  ? SignUpForm(
                                      key: const ValueKey('desktop-signup'),
                                      fullName: authController.fullName,
                                      matricule: authController.matricule,
                                      password: authController.password,
                                      showPassword: authController.showPassword,
                                      errorMessage: authController.errorMessage,
                                      onFullNameChanged: authController.updateFullName,
                                      onMatriculeChanged: authController.updateMatricule,
                                      onPasswordChanged: authController.updatePassword,
                                      onTogglePassword: authController.togglePasswordVisibility,
                                      onSignIn: () => authController.toggleAuthMode(),
                                      onSignUp: () async {
                                        final success = await authController.signUp();
                                        if (success && context.mounted) {
                                          _navigateAfterAuth(context);
                                        }
                                      },
                                      isLoading: authController.isLoading,
                                    )
                                  : SignInForm(
                                      key: const ValueKey('desktop-signin'),
                                      matricule: authController.matricule,
                                      password: authController.password,
                                      showPassword: authController.showPassword,
                                      rememberMe: authController.rememberMe,
                                      errorMessage: authController.errorMessage,
                                      onMatriculeChanged: authController.updateMatricule,
                                      onPasswordChanged: authController.updatePassword,
                                      onTogglePassword: authController.togglePasswordVisibility,
                                      onToggleRememberMe: authController.toggleRememberMe,
                                      onSignUp: () => authController.toggleAuthMode(),
                                      onSignIn: () async {
                                        final success = await authController.signIn();
                                        if (success && context.mounted) {
                                          _navigateAfterAuth(context);
                                        }
                                      },
                                      isLoading: authController.isLoading,
                                    ),
                            ),
                            const SizedBox(height: 20),

                            // Footer security badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 13,
                                  color: Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  AppLocalizations.of(context).officialSecurityTag,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mobile Layout ──
  Widget _buildMobileLayout(
    BuildContext context,
    AuthController authController,
  ) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),

              // Top Brand Header with Logo & Institutional Badge
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                child: Image.asset(
                  'assets/logo/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'Callwave',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),

              // Institutional verified badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF134E2B).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF134E2B).withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'CENADI • RÉPUBLIQUE DU CAMEROUN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF134E2B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Main Auth Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPendingJoinBanner(),

                    // Segmented Pill Switcher
                    SegmentedAuthSwitch(
                      isSignUp: authController.isSignUp,
                      onModeChanged: (_) => authController.toggleAuthMode(),
                    ),
                    const SizedBox(height: 22),

                    // Forms with smooth animated transition
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: authController.isSignUp
                          ? SignUpForm(
                              key: const ValueKey('mobile-signup'),
                              fullName: authController.fullName,
                              matricule: authController.matricule,
                              password: authController.password,
                              showPassword: authController.showPassword,
                              errorMessage: authController.errorMessage,
                              onFullNameChanged: authController.updateFullName,
                              onMatriculeChanged: authController.updateMatricule,
                              onPasswordChanged: authController.updatePassword,
                              onTogglePassword: authController.togglePasswordVisibility,
                              onSignIn: () => authController.toggleAuthMode(),
                              onSignUp: () async {
                                final success = await authController.signUp();
                                if (success && context.mounted) {
                                  _navigateAfterAuth(context);
                                }
                              },
                              isLoading: authController.isLoading,
                            )
                          : SignInForm(
                              key: const ValueKey('mobile-signin'),
                              matricule: authController.matricule,
                              password: authController.password,
                              showPassword: authController.showPassword,
                              rememberMe: authController.rememberMe,
                              errorMessage: authController.errorMessage,
                              onMatriculeChanged: authController.updateMatricule,
                              onPasswordChanged: authController.updatePassword,
                              onTogglePassword: authController.togglePasswordVisibility,
                              onToggleRememberMe: authController.toggleRememberMe,
                              onSignUp: () => authController.toggleAuthMode(),
                              onSignIn: () async {
                                final success = await authController.signIn();
                                if (success && context.mounted) {
                                  _navigateAfterAuth(context);
                                }
                              },
                              isLoading: authController.isLoading,
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Trust & Security Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 13,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.officialSecurityTag,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }
}
