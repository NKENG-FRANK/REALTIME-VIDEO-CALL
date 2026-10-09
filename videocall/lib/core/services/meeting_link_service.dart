import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme/app_colors.dart';

/// Parsed representation of a meeting join link or code.
class ParsedMeetingLink {
  final String roomId;
  final bool isVideo;
  final String? title;

  const ParsedMeetingLink({
    required this.roomId,
    this.isVideo = true,
    this.title,
  });
}

/// Service for generating, parsing, and sharing meeting join links and codes.
class MeetingLinkService {
  static const String baseUrl = 'https://callwave.cenadi.cm/join';

  /// Generates a standardized shareable URL for any meeting room.
  static String generateMeetingLink({
    required String roomId,
    bool isVideo = true,
    String? title,
  }) {
    final queryParams = <String, String>{
      'room': roomId.trim(),
      'video': isVideo.toString(),
    };
    if (title != null && title.trim().isNotEmpty) {
      queryParams['title'] = title.trim();
    }
    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
    return uri.toString();
  }

  /// Formats a complete, professional invitation message to send via chat/email.
  static String formatInviteMessage({
    required String roomId,
    bool isVideo = true,
    String? title,
    String? hostName,
  }) {
    final link = generateMeetingLink(roomId: roomId, isVideo: isVideo, title: title);
    final buffer = StringBuffer();
    if (hostName != null && hostName.isNotEmpty) {
      buffer.writeln('$hostName is inviting you to a Callwave meeting.');
    } else {
      buffer.writeln('You have been invited to a Callwave meeting.');
    }
    if (title != null && title.isNotEmpty) {
      buffer.writeln('Topic: $title');
    }
    buffer.writeln('Mode: ${isVideo ? "Video Call" : "Audio Call"}');
    buffer.writeln('Room ID: $roomId');
    buffer.writeln('Join Link: $link');
    return buffer.toString().trim();
  }

  /// Parses raw input which can be:
  /// 1. A full URL (e.g. `https://callwave.cenadi.cm/join?room=group-123&video=false&title=Sync`)
  /// 2. A deep link scheme (e.g. `callwave://join?room=group-123`)
  /// 3. A raw room code (e.g. `group-1728472910` or `123-456`)
  static ParsedMeetingLink parseInput(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) {
      return const ParsedMeetingLink(roomId: '');
    }

    try {
      final uri = Uri.parse(trimmed);
      if (uri.queryParameters.containsKey('room')) {
        final roomId = uri.queryParameters['room'] ?? '';
        final isVideo = uri.queryParameters['video'] != 'false';
        final title = uri.queryParameters['title'];
        return ParsedMeetingLink(
          roomId: roomId,
          isVideo: isVideo,
          title: title,
        );
      }
    } catch (_) {}

    // Fallback: treat the entire string as the room code
    return ParsedMeetingLink(roomId: trimmed);
  }

  /// Copies meeting link to device clipboard with user feedback.
  static Future<void> copyLinkToClipboard(
    BuildContext context, {
    required String roomId,
    bool isVideo = true,
    String? title,
  }) async {
    final link = generateMeetingLink(roomId: roomId, isVideo: isVideo, title: title);
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Meeting link copied to clipboard!'),
            ],
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  /// Copies full invite text to clipboard.
  static Future<void> copyFullInviteToClipboard(
    BuildContext context, {
    required String roomId,
    bool isVideo = true,
    String? title,
    String? hostName,
  }) async {
    final text = formatInviteMessage(
      roomId: roomId,
      isVideo: isVideo,
      title: title,
      hostName: hostName,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Full invitation copied to clipboard!'),
            ],
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  /// Shows the "Share Meeting Link" modal bottom sheet / dialog.
  static void showShareModal(
    BuildContext context, {
    required String roomId,
    bool isVideo = true,
    String? title,
    String? hostName,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ShareMeetingModal(
        roomId: roomId,
        isVideo: isVideo,
        title: title,
        hostName: hostName,
      ),
    );
  }
}

class _ShareMeetingModal extends StatelessWidget {
  final String roomId;
  final bool isVideo;
  final String? title;
  final String? hostName;

  const _ShareMeetingModal({
    required this.roomId,
    required this.isVideo,
    this.title,
    this.hostName,
  });

  @override
  Widget build(BuildContext context) {
    final link = MeetingLinkService.generateMeetingLink(
      roomId: roomId,
      isVideo: isVideo,
      title: title,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.link_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title != null && title!.isNotEmpty ? title! : 'Share Meeting Link',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Anyone with this link can join this call',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Link box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDCE7DF)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MEETING LINK',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        link,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                  tooltip: 'Copy Link',
                  onPressed: () {
                    MeetingLinkService.copyLinkToClipboard(
                      context,
                      roomId: roomId,
                      isVideo: isVideo,
                      title: title,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Room ID badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2EBE5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Room ID: $roomId',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: roomId));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Room ID copied!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  child: const Text('Copy ID', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy_all_rounded, size: 18),
                  label: const Text('Copy Invitation'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    MeetingLinkService.copyFullInviteToClipboard(
                      context,
                      roomId: roomId,
                      isVideo: isVideo,
                      title: title,
                      hostName: hostName,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy Link'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    MeetingLinkService.copyLinkToClipboard(
                      context,
                      roomId: roomId,
                      isVideo: isVideo,
                      title: title,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
