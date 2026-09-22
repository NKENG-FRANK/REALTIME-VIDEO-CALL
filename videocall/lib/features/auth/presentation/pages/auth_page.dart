import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/widgets/animated_background.dart';
import '../controllers/auth_controller.dart';
import '../widgets/sign_in_form.dart';
import '../widgets/sign_up_form.dart';
import '../widgets/welcome_panel.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({Key? key}) : super(key: key);

  /// Navigate to calls history after successful auth
  void _navigateAfterAuth(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/calls');
  }

  @override
  Widget build(BuildContext context) {
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
                    child: authController.isSignUp
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
    return SingleChildScrollView(
      child: Column(
        children: [
          // Welcome panel
          SizedBox(
            height: 300,
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
            padding: const EdgeInsets.all(40),
            child: SizedBox(
              width: double.infinity,
              child: AnimatedSwitcher(
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
            ),
          ),
        ],
      ),
    );
  }
}
