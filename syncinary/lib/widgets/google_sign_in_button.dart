import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1F1F1F),
            disabledBackgroundColor: Colors.white70,
            disabledForegroundColor: const Color(0xFF747775),
            side: const BorderSide(color: Color(0xFF747775)),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Image.asset(
            'assets/google_g.png',
            width: 20,
            height: 20,
            excludeFromSemantics: true,
          ),
          label: const Text('Continue with Google'),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('or', style: AppTextStyles.caption),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

String googleSignInError(String code) => switch (code) {
  'popup-blocked' =>
    'Your browser blocked the Google sign-in popup. Allow popups for this site and try again.',
  'account-exists-with-different-credential' || 'email-already-in-use' =>
    'An account already uses this email. Sign in with your existing sign-in method.',
  'network-request-failed' =>
    'Check your internet connection and try Google sign-in again.',
  'user-disabled' => 'This account has been disabled.',
  'too-many-requests' => 'Too many attempts. Please try again later.',
  'operation-not-allowed' || 'unauthorized-domain' =>
    'Google sign-in is not available on this site yet. Please use email and password.',
  'profile-unavailable' =>
    'Could not finish setting up your profile. Please try Google sign-in again.',
  _ => 'Google sign-in failed. Please try again.',
};
