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
      appBar: GradientAppBar(
        title: 'Join Group',
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.account_circle_outlined, color: AppColors.of(context).textMuted),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.of(context).backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 100, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pending Group Invites', style: AppTextStyles.of(context).title),
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
                          style: AppTextStyles.of(context).body.copyWith(color: AppColors.of(context).textMuted),
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
                                decoration: AppDecorations.glassCard(context),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${invite.senderUsername} — ${invite.groupName}',
                                        style: AppTextStyles.of(context).body,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Accept',
                                      onPressed: _busy
                                          ? null
                                          : () => _respond(invite, accept: true),
                                      icon: Icon(Icons.check_circle_outline,
                                          color: AppColors.of(context).success),
                                    ),
                                    IconButton(
                                      tooltip: 'Decline',
                                      onPressed: _busy
                                          ? null
                                          : () => _respond(invite, accept: false),
                                      icon: Icon(Icons.cancel_outlined,
                                          color: AppColors.of(context).error),
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
                Text('Join Through Invite Code', style: AppTextStyles.of(context).title),
                const SizedBox(height: 14),
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  style: AppTextStyles.of(context).body,
                  decoration: AppDecorations.inputDecoration(context,
                    label: 'Enter code',
                    prefixIcon: Icons.confirmation_number_outlined,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: AppTextStyles.of(context).caption.copyWith(color: AppColors.of(context).error)),
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
