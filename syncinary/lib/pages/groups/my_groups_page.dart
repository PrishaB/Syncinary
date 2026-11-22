import 'package:flutter/material.dart';
import '../../widgets/page_body.dart';
import '../../models/group.dart';
import '../../services/group_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/gradient_app_bar.dart';
import '../login_page.dart';
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
      MaterialPageRoute(
        builder: (_) => GroupDetailPage(group: group, service: _service),
      ),
    );
  }

  Future<void> _addGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        constraints: const BoxConstraints(maxWidth: 480),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
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
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.button.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GradientButton(
                        onPressed: () => Navigator.of(
                          dialogContext,
                        ).pop(controller.text.trim()),
                        label: 'Create',
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
      appBar: GradientAppBar(
        title: 'My Groups',
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textMuted),
            tooltip: 'Log out',
            onPressed: () async {
              await _service.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) =>
                        LoginPage(auth: _service.auth, groupService: _service),
                  ),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: PageBody(
        maxWidth: 880,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: StreamBuilder<List<Group>>(
            stream: _service.myGroupsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Something went wrong loading your groups.',
                    style: AppTextStyles.body.copyWith(color: AppColors.error),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final groups = snapshot.data!;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your next adventure starts here.',
                          style: AppTextStyles.headline,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Keep your people, plans, and shared costs together.',
                          style: AppTextStyles.subtitle,
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _leaveMode
                              ? [
                                  OutlinedButton(
                                    onPressed: _toggleLeaveMode,
                                    child: const Text('Cancel'),
                                  ),
                                ]
                              : [
                                  GradientButton(
                                    label: 'Add Group',
                                    icon: Icons.add_rounded,
                                    onPressed: _busy ? null : _addGroup,
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _busy ? null : _joinGroup,
                                    icon: const Icon(Icons.group_add_outlined),
                                    label: const Text('Join Group'),
                                  ),
                                  TextButton(
                                    onPressed: groups.isEmpty || _busy
                                        ? null
                                        : _toggleLeaveMode,
                                    child: const Text('Leave Group'),
                                  ),
                                ],
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                  if (groups.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.travel_explore_rounded,
                            size: 56,
                            color: AppColors.accentEnd,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No groups yet.\nCreate or join one to get started.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.subtitle,
                          ),
                        ],
                      ),
                    )
                  else
                    SliverList.separated(
                      itemCount: groups.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final group = groups[i];
                        return _GroupTile(
                          group: group,
                          role: _service.roleOf(group),
                          leaveMode: _leaveMode,
                          onTap: _leaveMode ? null : () => _openGroup(group),
                          onRemove: _leaveMode
                              ? () => _confirmLeave(group)
                              : null,
                        );
                      },
                    ),
                ],
              );
            },
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
                child: const Icon(
                  Icons.group_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: AppTextStyles.title.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${group.members.length} ${group.members.length == 1 ? 'member' : 'members'} · ${role == GroupRole.admin ? 'Admin' : 'Member'}',
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
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
