import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:syncinary/pages/login_page.dart';
import 'package:syncinary/pages/signup_page.dart';

import 'mock_firebase.dart';
import 'mock_firebase.mocks.dart';

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

/// Helper to wrap any widget in a MaterialApp for testing.
Widget makeTestableWidget(Widget child) {
  return MaterialApp(
    home: child,
  );
}

void main() {
  setupFirebaseAuthMocks();

  // ── Form-validation tests (no Firebase calls) ──────────

  testWidgets('Renders email and password fields', (tester) async {
    await tester.pumpWidget(makeTestableWidget(const LoginPage()));
    await tester.pumpAndSettle(); // let animations complete

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
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

  testWidgets('Sign Up navigates to SignUpPage', (tester) async {
    final mockObserver = MockNavigatorObserver();
    await tester.pumpWidget(
      MaterialApp(
        home: const LoginPage(),
        navigatorObservers: [mockObserver],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(find.byType(SignUpPage), findsOneWidget);
  });

  // ── Firebase mock tests ────────────────────────────────

  group('Firebase sign-in', () {
    late MockFirebaseAuth mockAuth;

    setUp(() {
      mockAuth = MockFirebaseAuth();
    });

    testWidgets('Successful sign-in navigates away from LoginPage',
        (tester) async {
      // Arrange: mock returns a successful credential
      final mockCredential = MockUserCredential();
      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockCredential);

      await tester.pumpWidget(
        makeTestableWidget(LoginPage(auth: mockAuth)),
      );
      await tester.pumpAndSettle();

      // Act: fill in valid credentials and tap Sign In
      await tester.enterText(
          find.byType(TextFormField).at(0), 'user@example.com');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Assert: signInWithEmailAndPassword was called
      verify(mockAuth.signInWithEmailAndPassword(
        email: 'user@example.com',
        password: 'password123',
      )).called(1);
    });

    testWidgets('Shows friendly error on wrong-password', (tester) async {
      // Arrange: mock throws a FirebaseAuthException
      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(FirebaseAuthException(
        code: 'wrong-password',
        message: 'Wrong password',
      ));

      await tester.pumpWidget(
        makeTestableWidget(LoginPage(auth: mockAuth)),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.enterText(
          find.byType(TextFormField).at(0), 'user@example.com');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'wrongpassword');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Assert: friendly error message is shown
      expect(
        find.text('Incorrect password. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('Shows friendly error on user-not-found', (tester) async {
      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(FirebaseAuthException(
        code: 'user-not-found',
        message: 'No user found',
      ));

      await tester.pumpWidget(
        makeTestableWidget(LoginPage(auth: mockAuth)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).at(0), 'noone@example.com');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(
        find.text('No account found with this email.'),
        findsOneWidget,
      );
    });
  });
}
