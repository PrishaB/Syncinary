import 'package:flutter/material.dart';
import '../../models/group.dart';
import '../../services/group_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_app_bar.dart';

class JoinGroupPage extends StatefulWidget {
  const JoinGroupPage({super.key, GroupService? service}) : _service = service;

  final GroupService? _service;

  @override
  State<JoinGroupPage> createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends State<JoinGroupPage> {
  late final GroupService _service = widget._service ?? GroupService();
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _respond(GroupInvite invite, {required bool accept}) async {
    setState(() => _busy = true);
    try {
      if (accept) {
        await _service.acceptInvite(invite);
      } else {
        await _service.declineInvite(invite);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not ${accept ? 'accept' : 'decline'} invite: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinWithCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final joined = await _service.joinByCode(_codeController.text);
      if (!mounted) return;
      if (joined) {
        Navigator.pop(context);
      } else {
        setState(() => _error = 'No group found for that code.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not join: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GradientAppBar(
        title: 'Join Group',
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 100, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pending Group Invites', style: AppTextStyles.title),
                const SizedBox(height: 14),
                StreamBuilder<List<GroupInvite>>(
                  stream: _service.pendingInvitesStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final invites = snapshot.data!;
                    if (invites.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No pending invites.',
                          style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                        ),
                      );
                    }
                    return Column(
                      children: invites
                          .map(
                            (invite) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 14),
                                decoration: AppDecorations.glassCard(),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${invite.senderUsername} — ${invite.groupName}',
                                        style: AppTextStyles.body,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Accept',
                                      onPressed: _busy
                                          ? null
                                          : () => _respond(invite, accept: true),
                                      icon: const Icon(Icons.check_circle_outline,
                                          color: AppColors.success),
                                    ),
                                    IconButton(
                                      tooltip: 'Decline',
                                      onPressed: _busy
                                          ? null
                                          : () => _respond(invite, accept: false),
                                      icon: const Icon(Icons.cancel_outlined,
                                          color: AppColors.error),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 28),
                Text('Join Through Invite Code', style: AppTextStyles.title),
                const SizedBox(height: 14),
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  style: AppTextStyles.body,
                  decoration: AppDecorations.inputDecoration(
                    label: 'Enter code',
                    prefixIcon: Icons.confirmation_number_outlined,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                ],
                const SizedBox(height: 18),
                GradientButton(
                  onPressed: _busy ? null : _joinWithCode,
                  label: 'Join',
                  icon: Icons.login_rounded,
                  isLoading: _busy,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
