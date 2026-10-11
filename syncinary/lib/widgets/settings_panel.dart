import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/account_service.dart';
import '../theme/app_theme.dart';

/// Opens the shared account settings panel from any app bar.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Settings',
      icon: const Icon(Icons.settings_outlined, color: AppColors.textMuted),
      onPressed: () => showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) => const Align(
          alignment: Alignment.centerRight,
          child: SettingsPanel(),
        ),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  ),
                ),
            child: child,
          );
        },
      ),
    );
  }
}

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key, this.service});

  final AccountService? service;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  bool _sending = false;
  String? _message;
  bool _failed = false;

  Future<void> _resetPassword() async {
    setState(() {
      _sending = true;
      _message = null;
      _failed = false;
    });
    try {
      await (widget.service ?? AccountService()).sendPasswordResetEmail();
      if (!mounted) return;
      setState(
        () => _message =
            'Password reset email sent. Check your inbox to choose a new password.',
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _message = switch (error.code) {
          'missing-email' => 'Please sign in with an email account first.',
          'too-many-requests' => 'Too many requests. Please try again later.',
          'network-request-failed' =>
            'Check your internet connection and try again.',
          _ => 'Could not send the reset email. Please try again.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _message = 'Could not send the reset email. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showComingSoon(BuildContext context, String action) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action),
        content: const Text('This account action is not available yet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 360,
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(child: Text('Settings', style: AppTextStyles.title)),
                IconButton(
                  tooltip: 'Close settings',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Account', style: AppTextStyles.subtitle),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline_rounded),
              title: const Text('Change password'),
              subtitle: Text(
                _sending
                    ? 'Sending reset email...'
                    : 'Send a password reset email',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _sending ? null : _resetPassword,
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _message!,
                    style: AppTextStyles.body.copyWith(
                      color: _failed ? AppColors.error : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            const Divider(color: AppColors.border),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.person_off_outlined,
                color: AppColors.error,
              ),
              title: const Text(
                'Deactivate account',
                style: TextStyle(color: AppColors.error),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.error,
              ),
              onTap: () => _showComingSoon(context, 'Deactivate account'),
            ),
          ],
        ),
      ),
    );
  }
}
