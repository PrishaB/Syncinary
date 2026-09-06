import 'package:flutter/material.dart';
import '../../models/group.dart';
import '../../services/group_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/gradient_app_bar.dart';
import 'group_detail_page.dart';
import 'join_group_page.dart';

class MyGroupsPage extends StatefulWidget {
  const MyGroupsPage({super.key, GroupService? service}) : _service = service;

  final GroupService? _service;

  @override
  State<MyGroupsPage> createState() => _MyGroupsPageState();
}

class _MyGroupsPageState extends State<MyGroupsPage> {
  late final GroupService _service = widget._service ?? GroupService();
  bool _leaveMode = false;
  bool _busy = false;

  void _openGroup(Group group) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupDetailPage(group: group, service: _service)),
    );
  }

  Future<void> _addGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
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
              Text('New Group', style: AppTextStyles.title),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                autofocus: true,
                style: AppTextStyles.body,
                decoration: AppDecorations.inputDecoration(
                  label: 'Group name',
                  prefixIcon: Icons.group_outlined,
                ),
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
                      onPressed: () => Navigator.of(dialogContext)
                          .pop(controller.text.trim()),
                      label: 'Create',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (name == null || name.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _service.createGroup(name);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _joinGroup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JoinGroupPage(service: _service)),
    );
  }

  void _toggleLeaveMode() {
    setState(() => _leaveMode = !_leaveMode);
  }

  Future<void> _confirmLeave(Group group) async {
    final confirmed = await showConfirmationDialog(
      context,
      message: 'Leave "${group.name}"?',
      confirmLabel: 'Leave',
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await _service.leaveGroup(group);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GradientAppBar(
        title: 'My Groups',
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.account_circle_outlined, color: AppColors.textMuted),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 100, 20, 24),
            child: StreamBuilder<List<Group>>(
              stream: _service.myGroupsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Something went wrong loading your groups.',
                        style: AppTextStyles.body.copyWith(color: AppColors.error)),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final groups = snapshot.data!;

                return Column(
                  children: [
                    Expanded(
                      child: groups.isEmpty
                          ? Center(
                              child: Text(
                                'No groups yet.\nCreate or join one to get started.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.subtitle
                                    .copyWith(color: AppColors.textMuted),
                              ),
                            )
                          : ListView.separated(
                              itemCount: groups.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (_, i) {
                                final group = groups[i];
                                final role = _service.roleOf(group);
                                return _GroupTile(
                                  group: group,
                                  role: role,
                                  leaveMode: _leaveMode,
                                  onTap: _leaveMode ? null : () => _openGroup(group),
                                  onRemove:
                                      _leaveMode ? () => _confirmLeave(group) : null,
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    if (_leaveMode)
                      SizedBox(
                        width: double.infinity,
                        child: _SecondaryPillButton(
                          label: 'Cancel',
                          onTap: _toggleLeaveMode,
                        ),
                      )
                    else ...[
                      _SecondaryPillButton(
                        label: 'Add Group',
                        onTap: _busy ? null : _addGroup,
                      ),
                      const SizedBox(height: 10),
                      _SecondaryPillButton(
                        label: 'Join Group',
                        onTap: _busy ? null : _joinGroup,
                      ),
                      const SizedBox(height: 10),
                      _SecondaryPillButton(
                        label: 'Leave Group',
                        onTap: groups.isEmpty ? null : _toggleLeaveMode,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.role,
    required this.leaveMode,
    this.onTap,
    this.onRemove,
  });

  final Group group;
  final GroupRole role;
  final bool leaveMode;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: AppDecorations.glassCard(),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: AppTextStyles.title.copyWith(fontSize: 17)),
                    const SizedBox(height: 4),
                    Text(
                      role == GroupRole.admin ? 'Admin' : 'User',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              if (leaveMode)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, color: AppColors.error),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryPillButton extends StatelessWidget {
  const _SecondaryPillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.surfaceLight.withValues(alpha: disabled ? 0.5 : 1),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTextStyles.button.copyWith(
                color: disabled ? AppColors.textMuted : AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
