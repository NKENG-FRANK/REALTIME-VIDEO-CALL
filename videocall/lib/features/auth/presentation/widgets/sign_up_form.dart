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
    super.key,
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
  });

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
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.error.withValues(alpha: 0.06),
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
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: AppColors.error,
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
          badgeText: l10n.text(fr: '8 caractères', en: '8 characters'),
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
          badgeText: l10n.text(
            fr: 'Min. 6 caractères',
            en: 'Min. 6 characters',
          ),
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
              color: AppColors.textMuted,
            ),
            tooltip: showPassword
                ? l10n.hidePasswordText
                : l10n.showPasswordText,
            onPressed: onTogglePassword,
          ),
        ),
        const SizedBox(height: 14),

        // Terms Notice
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.termsAgreement,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
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
              colors: [AppColors.primaryLight, AppColors.primaryDark],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          strokeWidth: 2.2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              l10n.signUp.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
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
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 6,
          children: [
            Text(
              l10n.alreadyHaveAccount,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
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
