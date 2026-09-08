import 'package:flutter/material.dart';
import '../../models/group.dart';
import '../../services/group_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/success_overlay.dart';

/// Returns true if admin status was transferred.
Future<bool> showTransferAdminDialog(
  BuildContext context,
  Group group,
  GroupService service,
) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (dialogContext) => _TransferAdminDialog(group: group, service: service),
  );
  return result ?? false;
}

class _TransferAdminDialog extends StatefulWidget {
  const _TransferAdminDialog({required this.group, required this.service});

  final Group group;
  final GroupService service;

  @override
  State<_TransferAdminDialog> createState() => _TransferAdminDialogState();
}

class _TransferAdminDialogState extends State<_TransferAdminDialog> {
  GroupMember? _selected;
  bool _busy = false;

  Future<void> _confirm() async {
    final selected = _selected;
    if (selected == null) return;
    setState(() => _busy = true);
    await widget.service.transferAdmin(widget.group, selected);
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop(true);
    await showSuccessOverlay(context, '${selected.username} is now the admin');
  }

  @override
  Widget build(BuildContext context) {
    final others = widget.group.members
        .where((m) => m.id != widget.service.currentUserId)
        .toList();

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
            Text('Transfer Admin Status to...',
                textAlign: TextAlign.center,
                style: AppTextStyles.title.copyWith(color: Colors.white)),
            const SizedBox(height: 18),
            if (others.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No other members to transfer to.',
                  style: AppTextStyles.body.copyWith(color: Colors.white70),
                ),
              )
            else
              ...others.map((member) {
                final isSelected = _selected?.id == member.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selected = member),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white.withValues(alpha: 0.25),
                              child: Text(
                                member.username.isNotEmpty
                                    ? member.username[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(member.username,
                                  style: AppTextStyles.body.copyWith(color: Colors.white)),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 14),
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
                onPressed: _selected == null || _busy ? null : _confirm,
                child: Text('Confirm Selection',
                    style: AppTextStyles.button.copyWith(color: AppColors.accentStart)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: AppTextStyles.button.copyWith(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
