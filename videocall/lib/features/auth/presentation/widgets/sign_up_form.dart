import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';

class SignUpForm extends StatelessWidget {
  final String fullName;
  final String email;
  final String password;
  final bool showPassword;
  final ValueChanged<String> onFullNameChanged;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;
  final bool isLoading;

  const SignUpForm({
    Key? key,
    required this.fullName,
    required this.email,
    required this.password,
    required this.showPassword,
    required this.onFullNameChanged,
    required this.onEmailChanged,
    required this.onPasswordChanged,
    required this.onTogglePassword,
    required this.onSignIn,
    required this.onSignUp,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            'Create Account',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 28),

          // Full name field
          TextField(
            onChanged: onFullNameChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person_outline, size: 13),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 38,
              ),
              hintText: 'Full name',
            ),
          ),
          const SizedBox(height: 11),

          // Email field
          TextField(
            onChanged: onEmailChanged,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.email_outlined, size: 13),
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
          const SizedBox(height: 14),

          // Terms & conditions
          Text(
            "By creating an account, you agree to Callwave's Terms of Service and Privacy Policy.",
            style: TextStyle(
              fontSize: 9,
              color: AppColors.textMuted,
              height: 1.5,
            ),
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 14),

          // Sign Up button
          ElevatedButton(
            onPressed: isLoading ? null : onSignUp,
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
                    'SIGN UP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.07,
                    ),
                  ),
          ),

          const SizedBox(height: 27),

          // Sign in link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Already have an account? ',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFFA0A7A2),
                ),
              ),
              TextButton(
                onPressed: onSignIn,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Sign In',
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
