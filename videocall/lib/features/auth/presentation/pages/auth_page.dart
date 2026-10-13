import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/services/meeting_link_service.dart';
import '../../../../core/widgets/animated_background.dart';
import '../../../call/presentation/pages/audio_call_page.dart';
import '../../../call/presentation/pages/call_page.dart';
import '../controllers/auth_controller.dart';
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
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.meeting_room_rounded, color: AppColors.primary, size: 20),
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated gradient blob background matching calls/contacts/settings
          const AnimatedBackground(),

          // Centered responsive card inside SafeArea
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 760;
                return Center(
                  child: SingleChildScrollView(
                    child: Container(
                      width: isMobile ? double.infinity : 1000,
                      height: isMobile ? null : 570,
                      margin: EdgeInsets.all(isMobile ? 0 : 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(isMobile ? 0 : 18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowColor,
                            blurRadius: 55,
                            offset: Offset(0, 22),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Consumer<AuthController>(
                        builder: (context, authController, _) {
                          return isMobile
                              ? _buildMobileLayout(context, authController)
                              : _buildDesktopLayout(context, authController);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    AuthController authController,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final welcomeWidth = constraints.maxWidth * 0.38;
        final formWidth = constraints.maxWidth * 0.62;
        final isSignUp = authController.isSignUp;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 650),
              curve: const Cubic(0.77, 0, 0.18, 1),
              left: isSignUp ? formWidth : 0,
              top: 0,
              bottom: 0,
              width: welcomeWidth,
              child: WelcomePanel(
                isSignUp: isSignUp,
                onSignInTap: () => authController.toggleAuthMode(),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 650),
              curve: const Cubic(0.77, 0, 0.18, 1),
              left: isSignUp ? 0 : welcomeWidth,
              top: 0,
              bottom: 0,
              width: formWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 70,
                  vertical: 40,
                ),
                child: Center(
                  child: SizedBox(
                    width: 360,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPendingJoinBanner(),
                        authController.isSignUp
                            ? SignUpForm(
                            fullName: authController.fullName,
                            matricule: authController.matricule,
                            password: authController.password,
                            showPassword: authController.showPassword,
                            errorMessage: authController.errorMessage,
                            onFullNameChanged:
                                authController.updateFullName,
                            onMatriculeChanged: authController.updateMatricule,
                            onPasswordChanged:
                                authController.updatePassword,
                            onTogglePassword:
                                authController.togglePasswordVisibility,
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
                            matricule: authController.matricule,
                            password: authController.password,
                            showPassword: authController.showPassword,
                            rememberMe: authController.rememberMe,
                            errorMessage: authController.errorMessage,
                            onMatriculeChanged: authController.updateMatricule,
                            onPasswordChanged:
                                authController.updatePassword,
                            onTogglePassword:
                                authController.togglePasswordVisibility,
                            onToggleRememberMe:
                                authController.toggleRememberMe,
                            onSignUp: () => authController.toggleAuthMode(),
                            onSignIn: () async {
                              final success = await authController.signIn();
                              if (success && context.mounted) {
                                _navigateAfterAuth(context);
                              }
                            },
                            isLoading: authController.isLoading,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 35,
              bottom: 34,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error,
                ),
              ),
            ),
            Positioned(
              right: 28,
              top: 34,
              child: Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _slideTransition(Widget child, Animation<double> animation) {
    final offsetAnimation = Tween<Offset>(
      begin: const Offset(0.12, 0),
      end: Offset.zero,
    ).animate(animation);

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: offsetAnimation, child: child),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    AuthController authController,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    // Proportional banner panel on mobile devices
    final panelHeight = screenHeight < 700 ? 190.0 : 230.0;
    // Reduce horizontal padding on narrow screens
    final hPadding = screenWidth < 380 ? 20.0 : 28.0;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Welcome panel
          SizedBox(
            height: panelHeight,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: _slideTransition,
              child: WelcomePanel(
                key: ValueKey(authController.isSignUp),
                isSignUp: authController.isSignUp,
                onSignInTap: () => authController.toggleAuthMode(),
              ),
            ),
          ),

          // Form
          Padding(
            padding: EdgeInsets.fromLTRB(hPadding, 24, hPadding, 32),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPendingJoinBanner(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    transitionBuilder: _slideTransition,
                    child: authController.isSignUp
                    ? SignUpForm(
                        key: const ValueKey('mobile-sign-up'),
                        fullName: authController.fullName,
                        matricule: authController.matricule,
                        password: authController.password,
                        showPassword: authController.showPassword,
                        errorMessage: authController.errorMessage,
                        onFullNameChanged: authController.updateFullName,
                        onMatriculeChanged: authController.updateMatricule,
                        onPasswordChanged: authController.updatePassword,
                        onTogglePassword:
                            authController.togglePasswordVisibility,
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
                        key: const ValueKey('mobile-sign-in'),
                        matricule: authController.matricule,
                        password: authController.password,
                        showPassword: authController.showPassword,
                        rememberMe: authController.rememberMe,
                        errorMessage: authController.errorMessage,
                        onMatriculeChanged: authController.updateMatricule,
                        onPasswordChanged: authController.updatePassword,
                        onTogglePassword:
                            authController.togglePasswordVisibility,
                        onToggleRememberMe:
                            authController.toggleRememberMe,
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
      ),
        ],
      ),
    );
  }
}
