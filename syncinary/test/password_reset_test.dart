import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/pages/login_page.dart';

/// Records the request at the Auth boundary without sending real email.
class _ResetAuth extends MockFirebaseAuth {
  _ResetAuth({this.error});

  final FirebaseAuthException? error;
  final requestedEmails = <String>[];

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    requestedEmails.add(email);
    if (error != null) throw error!;
  }
}

Future<void> _requestReset(
  WidgetTester tester,
  _ResetAuth auth,
  String email,
) async {
  await tester.pumpWidget(MaterialApp(home: LoginPage(auth: auth)));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, email);
  // A reset must work without entering a password or signing in.
  await tester.tap(find.text('Forgot Password?'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Valid email requests a reset and keeps the user signed out',
    (tester) async {
      final auth = _ResetAuth();

      await _requestReset(tester, auth, '  traveler@example.com  ');

      expect(auth.requestedEmails, ['traveler@example.com']);
      expect(
        find.text('Password reset link sent! Check your email.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(auth.currentUser, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Unknown email displays the Auth user-not-found error', (
    tester,
  ) async {
    final auth = _ResetAuth(
      error: FirebaseAuthException(code: 'user-not-found'),
    );

    await _requestReset(tester, auth, 'missing@example.com');

    expect(auth.requestedEmails, ['missing@example.com']);
    expect(find.text('No account found with this email.'), findsOneWidget);
    expect(
      find.text('Password reset link sent! Check your email.'),
      findsNothing,
    );
    expect(find.byType(LoginPage), findsOneWidget);
    expect(auth.currentUser, isNull);
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Forgot Password?'),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unknown email accepted by Auth shows confirmation', (
    tester,
  ) async {
    // Also cover a backend that conceals whether an account exists. This fake
    // deliberately has no registered user and accepts the reset request.
    final auth = _ResetAuth();

    await _requestReset(tester, auth, 'missing@example.com');

    expect(auth.requestedEmails, ['missing@example.com']);
    expect(
      find.text('Password reset link sent! Check your email.'),
      findsOneWidget,
    );
    expect(find.text('No account found with this email.'), findsNothing);
    expect(auth.currentUser, isNull);
    expect(tester.takeException(), isNull);
  });
}
