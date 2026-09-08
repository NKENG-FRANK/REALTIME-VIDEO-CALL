import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/theme/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../widgets/sign_in_form.dart';
import '../widgets/sign_up_form.dart';
import '../widgets/welcome_panel.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 760;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(color: AppColors.background),

          // Decorative shapes
          Positioned(
            left: -245,
            bottom: -265,
            child: Opacity(
              opacity: 0.88,
              child: Container(
                width: 1000,
                height: 1000,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
          Positioned(
            right: -145,
            top: -165,
            child: Container(
              width: 1000,
              height: 1000,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error,
              ),
            ),
          ),
          Positioned(
            right: 200,
            bottom: -220,
            child: Opacity(
              opacity: 0.4,
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFC9DDBD),
                ),
              ),
            ),
          ),

          // Main card
          Consumer<AuthController>(
            builder: (context, authController, _) {
              return Center(
                child: Container(
                  width: isMobile ? double.infinity : 1000,
                  height: isMobile ? null : 570,
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowColor,
                        blurRadius: 55,
                        offset: const Offset(0, 22),
                      ),
                    ],
                  ),
                  child: isMobile
                      ? _buildMobileLayout(context, authController)
                      : _buildDesktopLayout(context, authController),
                ),
              );
            },
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
                            email: authController.email,
                            password: authController.password,
                            showPassword: authController.showPassword,
                            onFullNameChanged:
                                authController.updateFullName,
                            onEmailChanged: authController.updateEmail,
                            onPasswordChanged:
                                authController.updatePassword,
                            onTogglePassword:
                                authController.togglePasswordVisibility,
                            onSignIn: () => authController.toggleAuthMode(),
                            onSignUp: () => authController.signUp(),
                            isLoading: authController.isLoading,
                          )
                        : SignInForm(
                            email: authController.email,
                            password: authController.password,
                            showPassword: authController.showPassword,
                            rememberMe: authController.rememberMe,
                            onEmailChanged: authController.updateEmail,
                            onPasswordChanged:
                                authController.updatePassword,
                            onTogglePassword:
                                authController.togglePasswordVisibility,
                            onToggleRememberMe:
                                authController.toggleRememberMe,
                            onSignUp: () => authController.toggleAuthMode(),
                            onSignIn: () => authController.signIn(),
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
                        email: authController.email,
                        password: authController.password,
                        showPassword: authController.showPassword,
                        onFullNameChanged: authController.updateFullName,
                        onEmailChanged: authController.updateEmail,
                        onPasswordChanged: authController.updatePassword,
                        onTogglePassword:
                            authController.togglePasswordVisibility,
                        onSignIn: () => authController.toggleAuthMode(),
                        onSignUp: () => authController.signUp(),
                        isLoading: authController.isLoading,
                      )
                    : SignInForm(
                        key: const ValueKey('mobile-sign-in'),
                        email: authController.email,
                        password: authController.password,
                        showPassword: authController.showPassword,
                        rememberMe: authController.rememberMe,
                        onEmailChanged: authController.updateEmail,
                        onPasswordChanged: authController.updatePassword,
                        onTogglePassword:
                            authController.togglePasswordVisibility,
                        onToggleRememberMe:
                            authController.toggleRememberMe,
                        onSignUp: () => authController.toggleAuthMode(),
                        onSignIn: () => authController.signIn(),
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
