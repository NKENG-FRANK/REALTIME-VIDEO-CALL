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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 400;
        final vPadding = isCompact ? 14.0 : 42.0;
        final hPadding = isCompact ? 20.0 : 42.0;

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
                padding: EdgeInsets.symmetric(
                  horizontal: hPadding,
                  vertical: vPadding,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand
                    Row(
                      children: [
                        Container(
                          width: isCompact ? 26 : 30,
                          height: isCompact ? 26 : 30,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(isCompact ? 6 : 8),
                          ),
                          child: Center(
                            child: Text(
                              'C',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: isCompact ? 12 : 14,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: isCompact ? 7 : 9),
                        Text(
                          'Callwave',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 12 : 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),

                    // Welcome content
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isSignUp ? 'Join Us!' : AppLocalizations.of(context).welcomeTitle,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 22 : 29,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: isCompact ? 6 : 14),
                        Text(
                          isSignUp
                              ? AppLocalizations.of(context).welcomeSubtitle
                              : AppLocalizations.of(context).welcomeSubtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.78),
                            fontSize: isCompact ? 11 : 12,
                            height: isCompact ? 1.4 : 1.7,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: isCompact ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isCompact ? 12 : 28),
                        ElevatedButton(
                          onPressed: onSignInTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.85),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: isCompact ? 28 : 42,
                              vertical: isCompact ? 8 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            isSignUp
                                ? AppLocalizations.of(context).signUpLink.toUpperCase()
                                : AppLocalizations.of(context).signInLink.toUpperCase(),
                            style: TextStyle(
                              fontSize: isCompact ? 10 : 11,
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
      },
    );
  }
}
