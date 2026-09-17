import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/l10n/app_localizations.dart';

class WelcomePanel extends StatelessWidget {
  final VoidCallback onSignInTap;
  final bool isSignUp;

  const WelcomePanel({
    Key? key,
    required this.onSignInTap,
    required this.isSignUp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryLight,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            left: -180,
            bottom: -130,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.textLight.withOpacity(0.11),
                ),
              ),
            ),
          ),
          Positioned(
            right: -90,
            top: 95,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.textLight.withOpacity(0.11),
                ),
              ),
            ),
          ),
          Positioned(
            right: 45,
            bottom: 35,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.textLight.withOpacity(0.11),
                ),
              ),
            ),
          ),

          // Diamond shapes
          Positioned(
            right: 54,
            top: 42,
            child: Transform.rotate(
              angle: 0.785,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.textLight.withOpacity(0.11),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 42,
            bottom: 120,
            child: Transform.rotate(
              angle: 0.785,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.textLight.withOpacity(0.11),
                  ),
                ),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(42),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Brand
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'C',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'Callwave',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),

                // Welcome content
                Column(
                  children: [
                    Text(
                      isSignUp ? 'Join Us!' : AppLocalizations.of(context).welcomeTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isSignUp
                          ? AppLocalizations.of(context).welcomeSubtitle
                          : AppLocalizations.of(context).welcomeSubtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 12,
                        height: 1.7,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: onSignInTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.85),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 42,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        isSignUp
                            ? AppLocalizations.of(context).signUpLink.toUpperCase()
                            : AppLocalizations.of(context).signInLink.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.05,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
