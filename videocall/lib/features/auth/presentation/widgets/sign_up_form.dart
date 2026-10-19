import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/l10n/app_localizations.dart';
import 'auth_text_field.dart';

class SignUpForm extends StatelessWidget {
  final String fullName;
  final String matricule;
  final String password;
  final bool showPassword;
  final String? errorMessage;
  final ValueChanged<String> onFullNameChanged;
  final ValueChanged<String> onMatriculeChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;
  final bool isLoading;

  const SignUpForm({
    Key? key,
    required this.fullName,
    required this.matricule,
    required this.password,
    required this.showPassword,
    this.errorMessage,
    required this.onFullNameChanged,
    required this.onMatriculeChanged,
    required this.onPasswordChanged,
    required this.onTogglePassword,
    required this.onSignIn,
    required this.onSignUp,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Error Feedback Banner
        if (errorMessage != null && errorMessage!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFF991B1B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Full Name Field
        AuthTextField(
          label: l10n.fullName,
          hintText: l10n.fullNameHint,
          prefixIcon: Icons.person_outline_rounded,
          initialValue: fullName,
          onChanged: onFullNameChanged,
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 14),

        // Matricule Field
        AuthTextField(
          label: l10n.matricule,
          badgeText: '8 caractères',
          hintText: l10n.matriculeHint,
          prefixIcon: Icons.badge_outlined,
          initialValue: matricule,
          onChanged: onMatriculeChanged,
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 14),

        // Password Field
        AuthTextField(
          label: l10n.password,
          badgeText: 'Min. 6 car.',
          hintText: l10n.passwordPlaceholder,
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: !showPassword,
          initialValue: password,
          onChanged: onPasswordChanged,
          onSubmitted: onSignUp,
          suffix: IconButton(
            icon: Icon(
              showPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
              color: const Color(0xFF64748B),
            ),
            tooltip: showPassword ? l10n.hidePasswordText : l10n.showPasswordText,
            onPressed: onTogglePassword,
          ),
        ),
        const SizedBox(height: 14),

        // Terms Notice
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.termsAgreement,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Primary Sign Up Button
        Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF134E2B),
                Color(0xFF1B6E3D),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF134E2B).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : onSignUp,
              borderRadius: BorderRadius.circular(14),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2.2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.signUp.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 22),

        // Sign In Switch Prompt
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.alreadyHaveAccount,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            InkWell(
              onTap: onSignIn,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  l10n.signInLink,
                  style: TextStyle(
                    fontSize: 12,
                    color: primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
