import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';

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
    Key? key,
    this.callTitle = 'Design Team',
    this.participantCount = 5,
    this.duration = '42:17',
    this.quality = 'Good',
    this.onCallAgain,
    this.onBackToHome,
  }) : super(key: key);

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
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.callBackground,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  // Phone icon
                  _buildPhoneIcon(),
                  const SizedBox(height: 20),
                  // Call ended text
                  const Text(
                    'Call ended',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Subtitle
                  Text(
                    '${widget.callTitle} · ${widget.participantCount} participants',
                    style: TextStyle(
                      color: AppColors.textMuted.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Stat cards
                  _buildStatCards(),
                  const SizedBox(height: 32),
                  // Rating prompt
                  Text(
                    'How was the call quality?',
                    style: TextStyle(
                      color: AppColors.textPrimary.withOpacity(0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Star rating
                  _buildStarRating(),
                  const SizedBox(height: 32),
                  // Action buttons
                  _buildActionButtons(),
                  const SizedBox(height: 60),
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
        color: AppColors.primary.withOpacity(0.12),
      ),
      child: Icon(
        Icons.phone,
        size: 28,
        color: AppColors.primary.withOpacity(0.7),
      ),
    );
  }

  Widget _buildStatCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StatCard(
            value: widget.duration,
            label: 'Duration',
            color: AppColors.statGreenTint,
          ),
          const SizedBox(width: 14),
          _StatCard(
            value: '${widget.participantCount}',
            label: 'Participants',
            color: AppColors.statYellowTint,
          ),
          const SizedBox(width: 14),
          _StatCard(
            value: widget.quality,
            label: 'Quality',
            color: AppColors.statNeutralTint,
          ),
        ],
      ),
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

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Call again
        _ActionButton(
          label: 'Call again',
          filled: true,
          onTap: widget.onCallAgain ?? () {},
        ),
        const SizedBox(width: 14),
        // Back to home
        _ActionButton(
          label: 'Back to home',
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

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ElevatedButton(
          onPressed: widget.onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                widget.filled ? AppColors.primary : Colors.transparent,
            foregroundColor: widget.filled ? Colors.white : AppColors.primary,
            elevation: widget.filled && _hovering ? 6 : 0,
            shadowColor: AppColors.primary.withOpacity(0.3),
            side: widget.filled
                ? null
                : BorderSide(
                    color: AppColors.primary.withOpacity(0.5),
                  ),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
