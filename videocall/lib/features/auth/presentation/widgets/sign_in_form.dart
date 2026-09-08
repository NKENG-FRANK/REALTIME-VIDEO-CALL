import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';

class SignInForm extends StatelessWidget {
  final String email;
  final String password;
  final bool showPassword;
  final bool rememberMe;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleRememberMe;
  final VoidCallback onSignUp;
  final VoidCallback onSignIn;
  final bool isLoading;

  const SignInForm({
    Key? key,
    required this.email,
    required this.password,
    required this.showPassword,
    required this.rememberMe,
    required this.onEmailChanged,
    required this.onPasswordChanged,
    required this.onTogglePassword,
    required this.onToggleRememberMe,
    required this.onSignUp,
    required this.onSignIn,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            'Sign In',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 28),

          // Email field
          TextField(
            onChanged: onEmailChanged,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person_outline, size: 13),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 38,
              ),
              hintText: 'Email address',
            ),
          ),
          const SizedBox(height: 11),

          // Password field
          TextField(
            onChanged: onPasswordChanged,
            obscureText: !showPassword,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline, size: 13),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 38,
              ),
              suffixIcon: GestureDetector(
                onTap: onTogglePassword,
                child: Padding(
                  padding: const EdgeInsets.only(right: 11),
                  child: Text(
                    showPassword ? '◌' : '◉',
                    style: const TextStyle(
                      color: Color(0xFF9AA29D),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              hintText: 'Password',
            ),
          ),
          const SizedBox(height: 13),

          // Remember me & Forgot password
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: rememberMe,
                    onChanged: (_) => onToggleRememberMe(),
                    activeColor: AppColors.primary,
                  ),
                  const Text(
                    'Remember me',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Sign In button
          ElevatedButton(
            onPressed: isLoading ? null : onSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 42,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 7,
              shadowColor: const Color.fromRGBO(45, 80, 22, 0.2),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'SIGN IN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.07,
                    ),
                  ),
          ),

          const SizedBox(height: 27),

          // Sign up link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Don't have an account? ",
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFFA0A7A2),
                ),
              ),
              TextButton(
                onPressed: onSignUp,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
