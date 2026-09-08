import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

import 'package:syncinary/pages/login_page.dart';

/// Helper to wrap any widget in a MaterialApp for testing.
Widget makeTestableWidget(Widget child) {
  return MaterialApp(
    home: child,
  );
}

void main() {
  // ─────────────────────────────────────────────────────────
  // Form validation tests (no Firebase interaction)
  // ─────────────────────────────────────────────────────────
  group('Form Validation', () {
    testWidgets('Renders email and password fields', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const LoginPage()));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Syncinary'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('Shows error for empty email', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const LoginPage()));
      await tester.pumpAndSettle();

      // Tap Sign In with empty fields
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('Shows error for invalid email format', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const LoginPage()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'notanemail');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('Shows error for short password', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const LoginPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'test@test.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'abcefgh');

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    });

    testWidgets('Shows error for empty password', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const LoginPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'test@test.com');
      // Leave password empty

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your password'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────
  // Firebase Auth mock tests
  // ─────────────────────────────────────────────────────────
  group('Firebase Auth - Sign In', () {
    late MockUser mockUser;

    setUp(() {
      mockUser = MockUser(
        uid: 'test-uid-123',
        email: 'test@test.com',
        displayName: 'Test User',
      );
    });

    testWidgets('Successful sign-in authenticates and navigates',
        (tester) async {
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);

      await tester.pumpWidget(makeTestableWidget(LoginPage(auth: mockAuth)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'test@test.com');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'password123');

      await tester.tap(find.text('Sign In'));

      // Pump enough to let the async sign-in future resolve.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The mock auth should now have the user signed in.
      expect(mockAuth.currentUser, isNotNull);
      expect(mockAuth.currentUser!.uid, 'test-uid-123');
      expect(mockAuth.currentUser!.email, 'test@test.com');
    });

    testWidgets('Shows friendly error for wrong-password code',
        (tester) async {
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(mockAuth)
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));

      await tester.pumpWidget(makeTestableWidget(LoginPage(auth: mockAuth)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'test@test.com');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'wrongpassword');

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(
          find.text('Incorrect password. Please try again.'), findsOneWidget);
    });

    testWidgets('Shows friendly error for user-not-found code',
        (tester) async {
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(mockAuth)
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));

      await tester.pumpWidget(makeTestableWidget(LoginPage(auth: mockAuth)));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).at(0), 'nobody@test.com');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'password123');

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('No account found with this email.'), findsOneWidget);
    });

    testWidgets('Shows friendly error for invalid-email code',
        (tester) async {
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(mockAuth)
          .thenThrow(FirebaseAuthException(code: 'invalid-email'));

      await tester.pumpWidget(makeTestableWidget(LoginPage(auth: mockAuth)));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).at(0), 'bad@email.com');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'password123');

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(
          find.text('Please enter a valid email address.'), findsOneWidget);
    });

    testWidgets('Shows friendly error for user-disabled code',
        (tester) async {
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(mockAuth)
          .thenThrow(FirebaseAuthException(code: 'user-disabled'));

      await tester.pumpWidget(makeTestableWidget(LoginPage(auth: mockAuth)));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).at(0), 'disabled@test.com');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'password123');

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('This account has been disabled.'), findsOneWidget);
    });

    testWidgets('Shows friendly error for too-many-requests code',
        (tester) async {
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(mockAuth)
          .thenThrow(FirebaseAuthException(code: 'too-many-requests'));

      await tester.pumpWidget(makeTestableWidget(LoginPage(auth: mockAuth)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'test@test.com');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'password123');

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Too many attempts. Please try again later.'),
          findsOneWidget);
    });

    testWidgets('Shows friendly error for invalid-credential code',
        (tester) async {
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(mockAuth)
          .thenThrow(FirebaseAuthException(code: 'invalid-credential'));

      await tester.pumpWidget(makeTestableWidget(LoginPage(auth: mockAuth)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'test@test.com');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'password123');

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password.'), findsOneWidget);
    });

    testWidgets('Shows fallback error for unknown Firebase error code',
        (tester) async {
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(mockAuth)
          .thenThrow(FirebaseAuthException(code: 'some-unknown-code'));

      await tester.pumpWidget(makeTestableWidget(LoginPage(auth: mockAuth)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'test@test.com');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'password123');

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Sign-in failed. Please check your credentials.'),
          findsOneWidget);
    });

    testWidgets('Shows generic error for non-Firebase exceptions',
        (tester) async {
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(mockAuth)
          .thenThrow(Exception('Network error'));

      await tester.pumpWidget(makeTestableWidget(LoginPage(auth: mockAuth)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'test@test.com');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'password123');

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(
          find.text('An unexpected error occurred. Please try again.'),
          findsOneWidget);
    });

    testWidgets('No error banner shown after successful sign-in',
        (tester) async {
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);

      await tester.pumpWidget(makeTestableWidget(LoginPage(auth: mockAuth)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'test@test.com');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'password123');

      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // No error banner should be visible after a successful sign-in.
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    });
  });
}
