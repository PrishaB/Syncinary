import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'itinerary_builder.dart';
import 'login_page.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key, this.auth, this.sendOnOpen = false});

  final FirebaseAuth? auth;
  final bool sendOnOpen;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  FirebaseAuth get _auth => widget.auth ?? FirebaseAuth.instance;
  bool _busy = false;
  bool _canResend = true;
  Timer? _cooldown;
  String _message =
      'Open the verification link in your email, then return here. Check your spam folder too.';

  @override
  void initState() {
    super.initState();
    if (widget.sendOnOpen) _sendEmail();
  }

  @override
  void dispose() {
    _cooldown?.cancel();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    if (_busy || !_canResend) return;
    setState(() => _busy = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw StateError('Signed out');
      await user.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _message = 'Verification email sent. Check your inbox and spam folder.';
        _canResend = false;
      });
      _cooldown = Timer(const Duration(seconds: 60), () {
        if (mounted) setState(() => _canResend = true);
      });
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(
          () => _message = e.code == 'too-many-requests'
              ? 'Too many requests. Please wait before trying again.'
              : 'Could not send the verification email. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Could not send the email. Try again or sign in again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkVerification() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _auth.currentUser?.reload();
      final user = _auth.currentUser;
      if (user != null && user.emailVerified) {
        await user.getIdToken(true);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const itinerary_builder()),
          (_) => false,
        );
      } else if (mounted) {
        setState(
          () => _message =
              'Your email is not verified yet. Open the link in your email and try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not check verification. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginPage(auth: widget.auth)),
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not sign out. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.mark_email_unread_outlined,
                        size: 64,
                        color: AppColors.accentStart,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Verify your email',
                        style: AppTextStyles.title,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _auth.currentUser?.email ?? '',
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _message,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 24),
                      GradientButton(
                        onPressed: _busy ? null : _checkVerification,
                        label: "Check verification",
                        isLoading: _busy,
                      ),
                      TextButton(
                        onPressed: _busy || !_canResend ? null : _sendEmail,
                        child: Text(
                          _canResend
                              ? 'Resend verification email'
                              : 'You can resend after 60 seconds',
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _signOut,
                        child: const Text('Back to sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
