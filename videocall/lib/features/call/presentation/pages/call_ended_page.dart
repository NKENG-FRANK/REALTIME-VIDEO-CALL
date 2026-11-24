import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/l10n/app_localizations.dart';

/// Call ended screen showing call summary statistics,
/// star rating for quality feedback, and action buttons.
class CallEndedPage extends StatefulWidget {
  final String callTitle;
  final int participantCount;
  final String duration;
  final String quality;
  final VoidCallback? onCallAgain;
  final VoidCallback? onBackToHome;

  const CallEndedPage({
    super.key,
    this.callTitle = 'Design Team',
    this.participantCount = 5,
    this.duration = '42:17',
    this.quality = 'Good',
    this.onCallAgain,
    this.onBackToHome,
  });

  @override
  State<CallEndedPage> createState() => _CallEndedPageState();
}

class _CallEndedPageState extends State<CallEndedPage>
    with SingleTickerProviderStateMixin {
  int _rating = 0;
  int _hoverRating = 0;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF09120E),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Phone icon
                  _buildPhoneIcon(),
                  const SizedBox(height: 20),
                  // Call ended text
                  Text(
                    l10n.callEnded,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Subtitle
                  Text(
                    '${widget.callTitle} · ${widget.participantCount} ${l10n.participants.toLowerCase()}',
                    style: TextStyle(
                      color: const Color(0xFF8DA69A),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  // Stat cards
                  _buildStatCards(),
                  const SizedBox(height: 32),
                  // Rating prompt
                  Text(
                    l10n.text(
                      fr: 'Comment était la qualité de l’appel ?',
                      en: 'How was the call quality?',
                    ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Star rating
                  _buildStarRating(),
                  const SizedBox(height: 32),
                  // Action buttons
                  _buildActionButtons(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneIcon() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.2),
      ),
      child: Icon(
        Icons.phone,
        size: 28,
        color: AppColors.primary.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildStatCards() {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // On very narrow screens fit all 3 cards side by side within available width
        final cardWidth = ((constraints.maxWidth - 40 - 24) / 3).clamp(
          80.0,
          130.0,
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(
                value: widget.duration,
                label: l10n.duration,
                color: const Color(0xFF133C2B),
                width: cardWidth,
              ),
              _StatCard(
                value: '${widget.participantCount}',
                label: l10n.participants,
                color: const Color(0xFF34290E),
                width: cardWidth,
              ),
              _StatCard(
                value: widget.quality,
                label: l10n.text(fr: 'Qualité', en: 'Quality'),
                color: const Color(0xFF1B2C23),
                width: cardWidth,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStarRating() {
    final displayRating = _hoverRating > 0 ? _hoverRating : _rating;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        final isActive = starIndex <= displayRating;
        return MouseRegion(
          onEnter: (_) => setState(() => _hoverRating = starIndex),
          onExit: (_) => setState(() => _hoverRating = 0),
          child: GestureDetector(
            onTap: () => setState(() => _rating = starIndex),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AnimatedScale(
                scale: isActive ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  isActive ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 34,
                  color: isActive
                      ? AppColors.starActive
                      : AppColors.starDefault,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 380;

    if (isNarrow) {
      // Stack buttons vertically on very small phones
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ActionButton(
              label: l10n.callAgain,
              filled: true,
              fullWidth: true,
              onTap: widget.onCallAgain ?? () {},
            ),
            const SizedBox(height: 10),
            _ActionButton(
              label: l10n.text(fr: 'Retour à l’accueil', en: 'Back to home'),
              filled: false,
              fullWidth: true,
              onTap: widget.onBackToHome ?? () {},
            ),
          ],
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 10,
      children: [
        _ActionButton(
          label: l10n.callAgain,
          filled: true,
          onTap: widget.onCallAgain ?? () {},
        ),
        _ActionButton(
          label: l10n.text(fr: 'Retour à l’accueil', en: 'Back to home'),
          filled: false,
          onTap: widget.onBackToHome ?? () {},
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final double width;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
    this.width = 110,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF8DA69A),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final bool filled;
  final bool fullWidth;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.fullWidth ? double.infinity : null,
        child: ElevatedButton(
          onPressed: widget.onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.filled
                ? AppColors.primary
                : Colors.transparent,
            foregroundColor: widget.filled
                ? Colors.white
                : const Color(0xFF3DDC97),
            elevation: widget.filled && _hovering ? 6 : 0,
            shadowColor: AppColors.primary.withValues(alpha: 0.3),
            side: widget.filled
                ? null
                : BorderSide(
                    color: const Color(0xFF3DDC97).withValues(alpha: 0.5),
                  ),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
    return button;
  }
}
