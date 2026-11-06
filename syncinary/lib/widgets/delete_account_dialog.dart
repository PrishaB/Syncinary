import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/account_service.dart';
import '../theme/app_theme.dart';

/// Explicit confirmation and fresh authentication for permanent deletion.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key, required this.service});

  final AccountService service;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  late final String? _userId;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _userId = widget.service.auth.currentUser?.uid;
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_deleting || !_formKey.currentState!.validate()) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.service.deleteAccount(
        password: _password.text,
        expectedUserId: _userId ?? '',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(
        () => _error = switch (error.code) {
          'wrong-password' ||
          'invalid-credential' => 'Incorrect password. Please try again.',
          'requires-recent-login' =>
            'Your session expired. Sign in again, then retry deletion.',
          'not-signed-in' || 'user-changed' || 'user-not-found' =>
            'Your account session changed. Close this dialog and sign in again.',
          'missing-email' => 'Please sign in with an email account first.',
          'group-admin-required' =>
            'You are the only admin or member of a group. Transfer admin access '
                'to another member or delete that group, then try again.',
          'too-many-requests' => 'Too many attempts. Please try again later.',
          'network-request-failed' =>
            'Check your internet connection and try again.',
          'account-delete-incomplete' =>
            'Your profile, invitations and memberships were removed, but account '
                'deletion did not finish. Please retry to finish deleting your account.',
          _ => 'Could not delete your account. Please try again.',
        },
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(
        () => _error = switch (error.code) {
          'permission-denied' =>
            'Account deletion is blocked by access permissions. '
                'Please contact the app administrator.',
          'unavailable' || 'deadline-exceeded' =>
            'The account data service could not be reached. '
                'Check your connection and try again shortly.',
          'unauthenticated' =>
            'Your session expired. Sign in again, then retry deletion.',
          'failed-precondition' =>
            'Account deletion requires a server configuration update. '
                'Please contact the app administrator.',
          'resource-exhausted' =>
            'The account data service has reached its limit. Please try again later.',
          _ => 'Could not remove your account data. Please try again later.',
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error =
            'Could not delete your account because of an unexpected error. '
            'Please try again.',
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_deleting,
      child: AlertDialog(
        title: const Text('Permanently delete account?'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This cannot be undone. Your account, profile, preferences, '
                  'invitations and group memberships will be removed. '
                  'Shared trips and contributions will remain for other members. '
                  'Transfer admin access or delete any group where you are '
                  'the only admin or member first.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _password,
                  enabled: !_deleting,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Enter your current password.'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
                if (_deleting) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Deleting account...'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _deleting
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('delete_account_confirm'),
            onPressed: _deleting ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
  }
}
