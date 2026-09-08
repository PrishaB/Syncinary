import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/group.dart';
import '../../services/group_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/success_overlay.dart';

Future<void> showInviteMembersDialog(BuildContext context, Group group, GroupService service) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (dialogContext) => _InviteMembersDialog(group: group, service: service),
  );
}

class _InviteMembersDialog extends StatefulWidget {
  const _InviteMembersDialog({required this.group, required this.service});

  final Group group;
  final GroupService service;

  @override
  State<_InviteMembersDialog> createState() => _InviteMembersDialogState();
}

class _InviteMembersDialogState extends State<_InviteMembersDialog> {
  final _emailController = TextEditingController();
  GroupRole _inviteRole = GroupRole.user;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String get _inviteLink => 'syncinary.app/join/${widget.group.inviteCode ?? widget.group.id}';

  Future<void> _sendInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.inviteMemberByEmail(widget.group, email, _inviteRole);
      if (!mounted) return;
      Navigator.of(context).pop();
      await showSuccessOverlay(context, 'Invite sent to $email');
    } on UserNotFoundException {
      if (mounted) {
        setState(() => _error = 'No Syncinary account found for that email.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _inviteLink));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite link copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentStart.withValues(alpha: 0.4),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Invite Members', style: AppTextStyles.title.copyWith(color: Colors.white)),
            const SizedBox(height: 18),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: AppTextStyles.body.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Add User by Email',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.15),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_error!,
                    style: AppTextStyles.caption.copyWith(color: Colors.white)),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _inviteLink,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(color: Colors.white),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _copyLink,
                          icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<GroupRole>(
                      value: _inviteRole,
                      dropdownColor: AppColors.surface,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      style: AppTextStyles.body.copyWith(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: GroupRole.user, child: Text('User')),
                        DropdownMenuItem(value: GroupRole.admin, child: Text('Admin')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _inviteRole = value);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.accentStart,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _busy ? null : _sendInvite,
                child: Text('Send Invite',
                    style: AppTextStyles.button.copyWith(color: AppColors.accentStart)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: AppTextStyles.button.copyWith(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
