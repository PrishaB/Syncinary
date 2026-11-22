import 'package:flutter/material.dart';
import '../../widgets/page_body.dart';
import '../../models/group.dart';
import '../../services/group_service.dart';
import '../../services/user_preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../widgets/success_overlay.dart';
import '../schedule_builder_page.dart';
import '../login_page.dart';
import '../trip_expenses_page.dart';
import '../user_preferences_page.dart';
import 'invite_members_dialog.dart';
import 'transfer_admin_dialog.dart';

class GroupDetailPage extends StatefulWidget {
  const GroupDetailPage({
    super.key,
    required this.group,
    GroupService? service,
    this.preferencesService,
  }) : _service = service;

  final Group group;
  final GroupService? _service;
  final UserPreferencesService? preferencesService;

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  late final GroupService _service = widget._service ?? GroupService();
  late final Stream<Group?> _groupStream = _service.groupStream(
    widget.group.id,
  );
  bool _busy = false;
  bool _deleting = false;
  bool _closing = false;

  void _closeDeletedGroup() {
    if (!mounted || _closing || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    _closing = true;
    navigator.pop();
  }

  Future<void> _renameGroup(Group group) async {
    final controller = TextEditingController(text: group.name);
    final newName = await showDialog<String>(
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
                Text('Rename Group', style: AppTextStyles.title),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: AppTextStyles.body,
                  decoration: AppDecorations.inputDecoration(
                    label: 'Group name',
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
                        label: 'Save',
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
      await showSuccessOverlay(
        context,
        '${member.username} successfully removed',
      );
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
    if (!confirmed || !mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() {
      _busy = true;
      _deleting = true;
    });
    try {
      await _service.deleteGroup(group);
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      await showSuccessOverlay(context, '${group.name} successfully deleted');
      _closeDeletedGroup();
    } catch (_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete trip. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _deleting = false;
        });
      }
    }
  }

  void _planItinerary(Group group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleBuilderPage(
          group: group,
          service: _service.scheduleService,
        ),
      ),
    );
  }

  void _trackCosts(Group group) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripExpensesPage(group: group)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Trip Overview',
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
        child: StreamBuilder<Group?>(
          stream: _groupStream,
          initialData: widget.group,
          builder: (context, snapshot) {
            final group = snapshot.data;
            if (group == null) {
              // Local deletion owns navigation until its success dialog closes.
              // Firestore can report the missing group before the write completes.
              if (!_deleting) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_deleting) _closeDeletedGroup();
                });
              }
              return const Center(child: CircularProgressIndicator());
            }

            final isAdmin = _service.isAdmin(group);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      gradient: AppColors.brandGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.group_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: isAdmin ? () => _renameGroup(group) : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            group.name,
                            style: AppTextStyles.headline,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.edit_outlined,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
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

                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      GradientButton(
                        onPressed: () => _planItinerary(group),
                        label: 'Plan Itinerary',
                        icon: Icons.map_outlined,
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            showInviteMembersDialog(context, group, _service),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Invite Members'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _trackCosts(group),
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Track Costs'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserPreferencesPage(
                              service: widget.preferencesService,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('Set Preferences'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Current Group Members',
                      style: AppTextStyles.title,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...group.members.map((member) {
                    final isSelf = member.id == _service.currentUserId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: AppDecorations.glassCard(),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                isSelf
                                    ? '${member.username} (you)'
                                    : member.username,
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
                                onPressed: _busy
                                    ? null
                                    : () => _removeMember(group, member),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Remove',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),

                  if (isAdmin) ...[
                    const SizedBox(height: 28),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: _busy ? null : () => _deleteGroup(group),
                          child: Text(
                            'Delete Trip?',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: group.members.length < 2 || _busy
                              ? null
                              : () => showTransferAdminDialog(
                                  context,
                                  group,
                                  _service,
                                ),
                          child: Text(
                            'Transfer Admin Status',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.accentEnd,
                            ),
                          ),
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
    );
  }
}
