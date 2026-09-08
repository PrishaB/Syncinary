import 'package:flutter/material.dart';
import '../../models/group.dart';
import '../../services/group_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../widgets/success_overlay.dart';
import '../itinerary_builder.dart';
import 'invite_members_dialog.dart';
import 'transfer_admin_dialog.dart';

class GroupDetailPage extends StatefulWidget {
  const GroupDetailPage({super.key, required this.group, GroupService? service})
      : _service = service;

  final Group group;
  final GroupService? _service;

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  late final GroupService _service = widget._service ?? GroupService();
  bool _busy = false;

  Future<void> _renameGroup(Group group) async {
    final controller = TextEditingController(text: group.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: AppDecorations.glassCard(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Rename Group', style: AppTextStyles.title),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                autofocus: true,
                style: AppTextStyles.body,
                decoration: AppDecorations.inputDecoration(label: 'Group name'),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text('Cancel',
                          style: AppTextStyles.button
                              .copyWith(color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      onPressed: () =>
                          Navigator.of(dialogContext).pop(controller.text.trim()),
                      label: 'Save',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (newName == null || newName.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _service.renameGroup(group, newName);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeMember(Group group, GroupMember member) async {
    final confirmed = await showConfirmationDialog(
      context,
      message: 'Are you sure you want to remove ${member.username}?',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await _service.removeMember(group, member);
      if (!mounted) return;
      await showSuccessOverlay(context, '${member.username} successfully removed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteGroup(Group group) async {
    final confirmed = await showConfirmationDialog(
      context,
      message: 'Confirm deletion of "${group.name}"?',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await _service.deleteGroup(group);
      if (!mounted) return;
      await showSuccessOverlay(context, '${group.name} successfully deleted');
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _planItinerary() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const itinerary_builder()));
  }

  void _trackCosts() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Track Costs — coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GradientAppBar(title: ''),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: StreamBuilder<Group?>(
            stream: _service.groupStream(widget.group.id),
            initialData: widget.group,
            builder: (context, snapshot) {
              final group = snapshot.data;
              if (group == null) {
                // Deleted (by this user or another admin) while viewing.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && Navigator.canPop(context)) Navigator.pop(context);
                });
                return const Center(child: CircularProgressIndicator());
              }

              final isAdmin = _service.isAdmin(group);

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 88, 24, 32),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: isAdmin
                          ? () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Photo upload — coming soon')),
                              )
                          : null,
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentStart.withValues(alpha: 0.35),
                              blurRadius: 28,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.group_rounded, color: Colors.white, size: 36),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (isAdmin)
                      Text('Add/Change photo',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: isAdmin ? () => _renameGroup(group) : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(group.name, style: AppTextStyles.headline),
                          if (isAdmin) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.edit_outlined,
                                color: AppColors.textMuted, size: 20),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Group User Status: ${isAdmin ? 'Admin' : 'User'}',
                      style: AppTextStyles.subtitle,
                    ),
                    const SizedBox(height: 28),

                    GradientButton(
                      onPressed: () => showInviteMembersDialog(context, group, _service),
                      label: 'Invite Members',
                      icon: Icons.person_add_alt_1_rounded,
                    ),
                    const SizedBox(height: 12),
                    GradientButton(
                      onPressed: _planItinerary,
                      label: 'Plan Itinerary',
                      icon: Icons.map_outlined,
                    ),
                    const SizedBox(height: 12),
                    GradientButton(
                      onPressed: _trackCosts,
                      label: 'Track Costs',
                      icon: Icons.payments_outlined,
                    ),

                    const SizedBox(height: 32),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Current Group Members', style: AppTextStyles.title),
                    ),
                    const SizedBox(height: 14),
                    ...group.members.map((member) {
                      final isSelf = member.id == _service.currentUserId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: AppDecorations.glassCard(),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isSelf ? '${member.username} (you)' : member.username,
                                  style: AppTextStyles.body,
                                ),
                              ),
                              Text(
                                member.role == GroupRole.admin ? 'Admin' : 'User',
                                style: AppTextStyles.caption,
                              ),
                              if (isAdmin && !isSelf) ...[
                                const SizedBox(width: 10),
                                TextButton(
                                  onPressed:
                                      _busy ? null : () => _removeMember(group, member),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text('Remove',
                                      style: AppTextStyles.caption
                                          .copyWith(color: AppColors.error)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),

                    if (isAdmin) ...[
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _busy ? null : () => _deleteGroup(group),
                            child: Text('Delete Trip?',
                                style: AppTextStyles.body.copyWith(color: AppColors.error)),
                          ),
                          TextButton(
                            onPressed: group.members.length < 2 || _busy
                                ? null
                                : () => showTransferAdminDialog(context, group, _service),
                            child: Text('Transfer Admin Status',
                                style:
                                    AppTextStyles.body.copyWith(color: AppColors.accentEnd)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
