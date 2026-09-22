import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../contacts/presentation/controllers/contacts_controller.dart';
import '../../../../core/services/signaling_service.dart';

import '../pages/call_page.dart';

/// Shows the Launch Group Call modal screen.
void showGroupCallLaunchDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => const _GroupCallLaunchDialog(),
  );
}

/// Shows the Start 1-on-1 Call modal screen.
void showOneToOneCallLaunchDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => const _OneToOneCallLaunchDialog(),
  );
}

/// Shows a dialog prompting the user to select Audio Call or Video Call for a contact.
void showCallTypeSelectionDialog(
  BuildContext context, {
  required String recipientName,
  required String recipientMatricule,
  required String recipientUserId,
}) {
  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.call, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Call $recipientName',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  if (recipientMatricule.isNotEmpty)
                    Text(
                      recipientMatricule,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
          ],
        ),
        content: const Text(
          'Please choose the call mode you would like to initiate:',
          style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.phone_rounded, size: 18),
                  label: const Text('Audio Call'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _launchDirectCall(
                      context,
                      isVideo: false,
                      recipientUserId: recipientUserId,
                      recipientName: recipientName,
                      recipientMatricule: recipientMatricule,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.videocam_rounded, size: 18),
                  label: const Text('Video Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _launchDirectCall(
                      context,
                      isVideo: true,
                      recipientUserId: recipientUserId,
                      recipientName: recipientName,
                      recipientMatricule: recipientMatricule,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

/// Build a deterministic room ID from two user IDs so both parties always
/// land in the same room regardless of who initiated.
String _buildRoomId(String userIdA, String userIdB) {
  final ids = [userIdA, userIdB]..sort();
  return 'direct-${ids[0]}-${ids[1]}';
}

/// Shared helper: emit call:invite then navigate to CallPage.
void _launchDirectCall(
  BuildContext context, {
  required bool isVideo,
  required String recipientUserId,
  required String recipientName,
  required String recipientMatricule,
}) {
  final authCtrl = context.read<AuthController>();
  final myUserId = authCtrl.currentUser?['id'] as String? ?? '';
  final myName = authCtrl.currentUser?['fullName'] as String? ??
      authCtrl.currentUser?['name'] as String? ?? 'Unknown';
  final myMatricule = authCtrl.currentUser?['matricule'] as String? ?? '';

  final roomId = _buildRoomId(myUserId, recipientUserId);

  // Notify callee via the persistent signaling socket
  context.read<SignalingService>().sendCallInvite(
        calleeUserId: recipientUserId,
        roomId: roomId,
        isVideoCall: isVideo,
        callerName: myName,
        callerMatricule: myMatricule,
      );

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CallPage(
        callTitle: isVideo
            ? 'Video Call – $recipientName'
            : 'Audio Call – $recipientName',
        roomId: roomId,
        participantCount: 2,
      ),
    ),
  );
}

class _GroupCallLaunchDialog extends StatefulWidget {
  const _GroupCallLaunchDialog({Key? key}) : super(key: key);

  @override
  State<_GroupCallLaunchDialog> createState() => _GroupCallLaunchDialogState();
}

class _GroupCallLaunchDialogState extends State<_GroupCallLaunchDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _searchController;
  final Set<String> _selectedContactIds = {};
  late final String _roomLink;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'Group Sync Call');
    _searchController = TextEditingController();
    final randomCode = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    _roomLink = 'https://callwave.ngomna.cm/room/grp-$randomCode';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _roomLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Group call link copied to clipboard!'),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _launchCall(bool isVideo) {
    // For group calls, generate a unique room ID
    final randomCode = DateTime.now().millisecondsSinceEpoch.toString();
    final roomId = 'group-$randomCode';
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallPage(
          callTitle: _titleController.text.trim().isNotEmpty
              ? _titleController.text.trim()
              : 'Group Call',
          roomId: roomId,
          participantCount: _selectedContactIds.length + 1,
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
        width: 580,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFEAF4EE),
                border: Border(bottom: BorderSide(color: Color(0xFFDCE7DF))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.groups_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Launch Group Call',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Add members or share a call join link',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group Title Input
                    const Text(
                      'Group Call Title',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'e.g. Ministry Engineering Sync',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        filled: true,
                        fillColor: const Color(0xFFF6FAF7),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFD0E0D4))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFD0E0D4))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Copy Room Link Box
                    const Text(
                      'Share Join Link',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF4EE).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: const Color(0xFFCDE8D8)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link_rounded, color: AppColors.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _roomLink,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _copyLink,
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            label: const Text('Copy Link'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Add Members Section
                    Row(
                      children: [
                        const Text(
                          'Add Members to Group',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_selectedContactIds.length} Selected',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 11),
                      decoration: InputDecoration(
                        hintText: 'Search contacts by name or matricule...',
                        prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textMuted),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        filled: true,
                        fillColor: const Color(0xFFF6FAF7),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE0EAE2))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE0EAE2))),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Contacts Multi-Select List
                    Consumer<ContactsController>(
                      builder: (context, contactsCtrl, _) {
                        final query = _searchController.text.trim().toLowerCase();
                        final contacts = contactsCtrl.contacts.where((c) {
                          return query.isEmpty ||
                              c.name.toLowerCase().contains(query) ||
                              c.matricule.toLowerCase().contains(query);
                        }).toList();

                        if (contacts.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                'No matching contacts found.',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ),
                          );
                        }

                        return Material(
                          color: const Color(0xFFFAFDFA),
                          borderRadius: BorderRadius.circular(9),
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 190),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: const Color(0xFFE0EAE2)),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: contacts.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEF5EF)),
                              itemBuilder: (context, idx) {
                                final contact = contacts[idx];
                                final isSelected = _selectedContactIds.contains(contact.id);
                                return CheckboxListTile(
                                value: isSelected,
                                activeColor: AppColors.primary,
                                visualDensity: VisualDensity.compact,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedContactIds.add(contact.id);
                                    } else {
                                      _selectedContactIds.remove(contact.id);
                                    }
                                  });
                                },
                                title: Text(
                                  contact.name,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  contact.matricule,
                                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                ),
                                secondary: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: contact.color,
                                  child: Text(
                                    contact.initials,
                                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Footer Action Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF5FAF6),
                border: Border(top: BorderSide(color: Color(0xFFDCE7DF))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _launchCall(false),
                      icon: const Icon(Icons.phone_rounded, size: 16),
                      label: const Text('Group Audio Call'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _launchCall(true),
                      icon: const Icon(Icons.videocam_rounded, size: 16),
                      label: const Text('Group Video Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
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

class _OneToOneCallLaunchDialog extends StatefulWidget {
  const _OneToOneCallLaunchDialog({Key? key}) : super(key: key);

  @override
  State<_OneToOneCallLaunchDialog> createState() => _OneToOneCallLaunchDialogState();
}

class _OneToOneCallLaunchDialogState extends State<_OneToOneCallLaunchDialog> {
  late final TextEditingController _searchController;
  String? _selectedContactId;
  late final String _directCallLink;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    final randomCode = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    _directCallLink = 'https://callwave.ngomna.cm/call/direct-$randomCode';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _directCallLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Direct call link copied to clipboard!'),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _launchCall(bool isVideo) {
    if (_selectedContactId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a contact first.'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final contactsCtrl = context.read<ContactsController>();
    final contact = contactsCtrl.contacts.firstWhere(
      (c) => c.id == _selectedContactId,
    );
    Navigator.pop(context);
    _launchDirectCall(
      context,
      isVideo: isVideo,
      recipientUserId: contact.id,
      recipientName: contact.name,
      recipientMatricule: contact.matricule,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 620),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFEAF4EE),
                border: Border(bottom: BorderSide(color: Color(0xFFDCE7DF))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start 1-on-1 Call',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Select a contact or share a direct call link',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            // Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Copy Direct Call Link
                    const Text(
                      'Direct Call Link',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF4EE).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: const Color(0xFFCDE8D8)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link_rounded, color: AppColors.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _directCallLink,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _copyLink,
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            label: const Text('Copy Link'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Select Recipient Section
                    const Text(
                      'Select Recipient',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 11),
                      decoration: InputDecoration(
                        hintText: 'Search by name or matricule...',
                        prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textMuted),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        filled: true,
                        fillColor: const Color(0xFFF6FAF7),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE0EAE2))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE0EAE2))),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Contacts List
                    Consumer<ContactsController>(
                      builder: (context, contactsCtrl, _) {
                        final query = _searchController.text.trim().toLowerCase();
                        final contacts = contactsCtrl.contacts.where((c) {
                          return !c.group && (query.isEmpty ||
                              c.name.toLowerCase().contains(query) ||
                              c.matricule.toLowerCase().contains(query));
                        }).toList();

                        if (contacts.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                'No contacts found.',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ),
                          );
                        }

                        return Material(
                          color: const Color(0xFFFAFDFA),
                          borderRadius: BorderRadius.circular(9),
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 210),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: const Color(0xFFE0EAE2)),
                            ),
                            child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: contacts.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEF5EF)),
                            itemBuilder: (context, idx) {
                              final contact = contacts[idx];
                              return RadioListTile<String>(
                                value: contact.id,
                                groupValue: _selectedContactId,
                                activeColor: AppColors.primary,
                                visualDensity: VisualDensity.compact,
                                onChanged: (val) {
                                  setState(() {
                                    _selectedContactId = val;
                                  });
                                },
                                title: Text(
                                  contact.name,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  contact.matricule,
                                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                ),
                                secondary: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: contact.color,
                                  child: Text(
                                    contact.initials,
                                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Footer Action Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF5FAF6),
                border: Border(top: BorderSide(color: Color(0xFFDCE7DF))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _launchCall(false),
                      icon: const Icon(Icons.phone_rounded, size: 16),
                      label: const Text('Start Audio Call'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _launchCall(true),
                      icon: const Icon(Icons.videocam_rounded, size: 16),
                      label: const Text('Start Video Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
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
