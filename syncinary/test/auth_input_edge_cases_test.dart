import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/pages/login_page.dart';
import 'package:syncinary/pages/signup_page.dart';

/// Records the actual credentials sent by the form and stops at the backend
/// boundary, so no real Firebase profile write or navigation is needed.
class RecordingAuth extends MockFirebaseAuth {
  String? submittedEmail;
  String? submittedPassword;
  int calls = 0;

  Future<UserCredential> record(String email, String password) async {
    calls++;
    submittedEmail = email;
    submittedPassword = password;
    throw FirebaseAuthException(code: 'too-many-requests');
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) => record(email, password);

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) => record(email, password);
}

void main() {
  testWidgets('[301-9] Whitespace-only signup name is rejected before auth', (
    tester,
  ) async {
    final auth = RecordingAuth();
    await tester.pumpWidget(MaterialApp(home: SignUpPage(auth: auth)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '   ');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'jack@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your name'), findsOneWidget);
    expect(auth.calls, 0);
  });

  for (final signup in [true, false]) {
    final action = signup ? 'Sign Up' : 'Sign In';
    final emailIndex = signup ? 1 : 0;
    for (final email in ['  jack+trip@example.com  ', '  JACK@EXAMPLE.COM  ']) {
      testWidgets('[301-9] $action accepts and trims $email', (tester) async {
        final auth = RecordingAuth();
        await tester.pumpWidget(
          MaterialApp(
            home: signup ? SignUpPage(auth: auth) : LoginPage(auth: auth),
          ),
        );
        await tester.pumpAndSettle();
        if (signup) {
          await tester.enterText(find.byType(TextFormField).at(0), 'Jack');
        }
        await tester.enterText(
          find.byType(TextFormField).at(emailIndex),
          email,
        );
        await tester.enterText(
          find.byType(TextFormField).at(emailIndex + 1),
          ' password123 ',
        );
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(auth.calls, 1);
        // Case is currently passed to Firebase unchanged; this does not claim
        // client-side lowercase normalization is implemented.
        expect(auth.submittedEmail, email.trim());
        expect(auth.submittedPassword, ' password123 ');
        expect(
          find.text('Too many attempts. Please try again later.'),
          findsOneWidget,
        );
      });
    }

    testWidgets('[301-9] $action rejects an injection-style invalid email', (
      tester,
    ) async {
      final auth = RecordingAuth();
      await tester.pumpWidget(
        MaterialApp(
          home: signup ? SignUpPage(auth: auth) : LoginPage(auth: auth),
        ),
      );
      await tester.pumpAndSettle();
      if (signup) {
        await tester.enterText(find.byType(TextFormField).at(0), 'Jack');
      }
      await tester.enterText(
        find.byType(TextFormField).at(emailIndex),
        "' OR 1=1 --",
      );
      await tester.enterText(
        find.byType(TextFormField).at(emailIndex + 1),
        'password123',
      );
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a valid email'), findsOneWidget);
      expect(auth.calls, 0);
    });
  }

  for (final name in ['Jack ' * 200, '<script>alert(1)</script>']) {
    testWidgets(
      '[301-9] Signup handles ${name.length > 100 ? 'a long' : 'an injection-style'} name without a layout error',
      (tester) async {
        final auth = RecordingAuth();
        await tester.pumpWidget(MaterialApp(home: SignUpPage(auth: auth)));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(0), name);
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'jack@example.com',
        );
        await tester.enterText(find.byType(TextFormField).at(2), 'password123');
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).at(0))
              .controller!
              .text,
          name,
        );
        await tester.tap(find.text('Sign Up'));
        await tester.pumpAndSettle();
        expect(auth.calls, 1);
        expect(
          find.text('Too many attempts. Please try again later.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
