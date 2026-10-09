import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/services/meeting_link_service.dart';
import '../pages/connecting_page.dart';

/// Shows the Join Meeting modal dialog where users can paste a link or enter a Room ID.
void showJoinMeetingDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => const _JoinMeetingDialog(),
  );
}

class _JoinMeetingDialog extends StatefulWidget {
  const _JoinMeetingDialog({Key? key}) : super(key: key);

  @override
  State<_JoinMeetingDialog> createState() => _JoinMeetingDialogState();
}

class _JoinMeetingDialogState extends State<_JoinMeetingDialog> {
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  bool _isVideo = true;
  String _detectedRoomId = '';
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _linkController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _linkController.removeListener(_onInputChanged);
    _linkController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    final text = _linkController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _detectedRoomId = '';
        _errorText = null;
      });
      return;
    }

    final parsed = MeetingLinkService.parseInput(text);
    setState(() {
      _detectedRoomId = parsed.roomId;
      _isVideo = parsed.isVideo;
      if (parsed.title != null && parsed.title!.isNotEmpty && _titleController.text.isEmpty) {
        _titleController.text = parsed.title!;
      }
      _errorText = null;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _linkController.text = data.text!.trim();
    }
  }

  void _joinMeeting() {
    final rawInput = _linkController.text.trim();
    if (rawInput.isEmpty) {
      setState(() {
        _errorText = 'Please enter a meeting link or Room ID';
      });
      return;
    }

    final parsed = MeetingLinkService.parseInput(rawInput);
    if (parsed.roomId.isEmpty) {
      setState(() {
        _errorText = 'Invalid meeting link or Room ID';
      });
      return;
    }

    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : (parsed.title ?? 'Meeting ${parsed.roomId}');

    Navigator.of(context).pop();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConnectingPage(
          callTitle: title,
          roomId: parsed.roomId,
          isVideoCall: _isVideo,
          isGroupCall: true,
          participantCount: 2,
          recipientUserId: '',
          recipientName: title,
          recipientMatricule: parsed.roomId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                color: Color(0xFFF0F6F2),
                border: Border(bottom: BorderSide(color: Color(0xFFDCE7DF))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_link_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Join Meeting',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Enter an invite link or room ID to connect',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Form Body
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meeting Link / ID input
                  const Text(
                    'MEETING LINK OR ROOM ID',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _linkController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. https://callwave.cenadi.cm/join?room=... or room-123',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.link_rounded, color: AppColors.primary, size: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.content_paste_rounded, size: 18),
                        tooltip: 'Paste from clipboard',
                        onPressed: _pasteFromClipboard,
                      ),
                      errorText: _errorText,
                      filled: true,
                      fillColor: const Color(0xFFF7FAF8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFDCE7DF)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFDCE7DF)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => _joinMeeting(),
                  ),

                  // Detected Room ID Badge
                  if (_detectedRoomId.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 13, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Room detected: $_detectedRoomId',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Optional Meeting Title
                  const Text(
                    'MEETING TOPIC (OPTIONAL)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. Design Review, Weekly Sync',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.title_rounded, color: AppColors.textMuted, size: 19),
                      filled: true,
                      fillColor: const Color(0xFFF7FAF8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFDCE7DF)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFDCE7DF)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Call Type Selector
                  const Text(
                    'JOIN WITH',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _CallModeChoice(
                          icon: Icons.videocam_rounded,
                          label: 'Video & Audio',
                          isSelected: _isVideo,
                          onTap: () => setState(() => _isVideo = true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CallModeChoice(
                          icon: Icons.mic_rounded,
                          label: 'Audio Only',
                          isSelected: !_isVideo,
                          onTap: () => setState(() => _isVideo = false),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 26),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textMuted,
                            side: const BorderSide(color: Color(0xFFDCE7DF)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _joinMeeting,
                          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                          label: const Text('Join Meeting'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
      ),
    );
  }
}

class _CallModeChoice extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CallModeChoice({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.10)
              : const Color(0xFFF7FAF8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFDCE7DF),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
