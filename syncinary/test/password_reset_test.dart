import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/pages/groups/my_groups_page.dart';
import 'package:syncinary/pages/login_page.dart';
import 'package:syncinary/services/group_service.dart';

/// Records the request at the Auth boundary without sending real email.
class _ResetAuth extends MockFirebaseAuth {
  _ResetAuth({this.error, MockUser? user}) : super(mockUser: user);

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

/// Models the Auth boundary after a reset completed on Firebase's hosted page.
/// The hosted email/link flow itself is outside this widget test.
class _PasswordAuth extends _ResetAuth {
  _PasswordAuth()
    : super(
        user: MockUser(
          uid: 'reset-user',
          email: 'traveler@example.com',
          isEmailVerified: true,
        ),
      );

  String acceptedPassword = 'old-password123';
  final loginAttempts = <({String email, String password})>[];

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    loginAttempts.add((email: email, password: password));
    if (email != 'traveler@example.com' || password != acceptedPassword) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    return super.signInWithEmailAndPassword(email: email, password: password);
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
    '[301-6] Login after a hosted password reset rejects the old password and accepts the new one',
    (tester) async {
      final auth = _PasswordAuth();
      final service = GroupService(
        auth: auth,
        firestore: FakeFirebaseFirestore(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(auth: auth, groupService: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'traveler@example.com',
      );
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();
      expect(auth.requestedEmails, ['traveler@example.com']);
      expect(auth.currentUser, isNull);
      expect(
        find.text('Password reset link sent! Check your email.'),
        findsOneWidget,
      );

      // Simulate the provider accepting a new password outside the app.
      auth.acceptedPassword = 'new-password456';
      // The reset confirmation expires while the user follows the email link.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).last,
        'old-password123',
      );
      await tester.ensureVisible(find.text('Sign In'));
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid email or password.'), findsOneWidget);
      expect(auth.currentUser, isNull);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(MyGroupsPage), findsNothing);

      await tester.enterText(
        find.byType(TextFormField).last,
        'new-password456',
      );
      await tester.ensureVisible(find.text('Sign In'));
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(auth.loginAttempts, [
        (email: 'traveler@example.com', password: 'old-password123'),
        (email: 'traveler@example.com', password: 'new-password456'),
      ]);
      expect(auth.currentUser!.uid, 'reset-user');
      expect(find.byType(MyGroupsPage), findsOneWidget);
      expect(find.byType(LoginPage, skipOffstage: false), findsNothing);
      expect(find.text('Invalid email or password.'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    '[301-7] Valid email requests a reset and keeps the user signed out',
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

  testWidgets('[301-7] Unknown email displays the Auth user-not-found error', (
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

  testWidgets('[301-7] Unknown email accepted by Auth shows confirmation', (
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
