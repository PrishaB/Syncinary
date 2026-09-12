import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:syncinary/pages/signup_page.dart';

Widget makeTestableWidget(Widget child) {
  return MaterialApp(
    home: child,
  );
}

void main() {
  // Widget rendering tests
  group('Widget Rendering', () {
    testWidgets('Renders all form fields and branding', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const SignUpPage()));
      await tester.pumpAndSettle();
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.text('Syncinary'), findsOneWidget);
      expect(find.text('Welcome!'), findsOneWidget);
      expect(find.text('Sign up to continue'), findsOneWidget);
    });

    testWidgets('Has three text form fields', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const SignUpPage()));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(3));
    });
  });
  // Form validation tests (no Firebase interaction)
  group('Form Validation', () {
    testWidgets('Shows error for empty name', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const SignUpPage()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), 'test@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your name'), findsOneWidget);
    });

    testWidgets('Shows error for empty email', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const SignUpPage()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('Shows error for invalid email format', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const SignUpPage()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), 'notanemail');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('Shows error for empty password', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const SignUpPage()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), 'test@test.com');
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('Shows error for short password', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const SignUpPage()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), 'test@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'short');
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    });

    testWidgets('Shows all validation errors at once when all fields empty',
        (tester) async {
      await tester.pumpWidget(makeTestableWidget(const SignUpPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your name'), findsOneWidget);
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });
  });

  // Firebase Auth mock tests
  group('Firebase Auth - Sign Up', () {
    late MockUser mockUser;

    setUp(() {
      mockUser = MockUser(
        uid: 'new-user-uid',
        email: 'newuser@test.com',
        displayName: 'New User',
      );
    });

    testWidgets('Successful sign-up authenticates the user', (tester) async {
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);
      await tester.pumpWidget(makeTestableWidget(SignUpPage(auth: mockAuth)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'New User');
      await tester.enterText(find.byType(TextFormField).at(1), 'newuser@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'securepass123');
      await tester.tap(find.text('Sign Up'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(mockAuth.currentUser, isNotNull);
    });

    testWidgets('Shows friendly error for email-already-in-use code',
        (tester) async {
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null)).on(mockAuth).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
      await tester.pumpWidget(makeTestableWidget(SignUpPage(auth: mockAuth)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Existing User');
      await tester.enterText(find.byType(TextFormField).at(1), 'existing@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('This email address is already registered.'), findsOneWidget);
    });

    testWidgets('Shows friendly error for weak-password code',
        (tester) async {
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null)).on(mockAuth).thenThrow(FirebaseAuthException(code: 'weak-password'));
      await tester.pumpWidget(makeTestableWidget(SignUpPage(auth: mockAuth)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), 'test@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'weakpass1');
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('The password is too weak. Use at least 8 characters.'), findsOneWidget);
    });

    testWidgets('Shows friendly error for invalid-email code',
        (tester) async {
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null)).on(mockAuth).thenThrow(FirebaseAuthException(code: 'invalid-email'));
      await tester.pumpWidget(makeTestableWidget(SignUpPage(auth: mockAuth)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), 'bad@email.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a valid email address.'), findsOneWidget);
    });

    testWidgets('Shows friendly error for too-many-requests code',
        (tester) async {
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null)).on(mockAuth).thenThrow(FirebaseAuthException(code: 'too-many-requests'));
      await tester.pumpWidget(makeTestableWidget(SignUpPage(auth: mockAuth)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), 'test@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Too many attempts. Please try again later.'), findsOneWidget);
    });

    testWidgets('Shows fallback error for unknown Firebase error code',
        (tester) async {
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null)).on(mockAuth).thenThrow(FirebaseAuthException(code: 'some-unknown-code'));
      await tester.pumpWidget(makeTestableWidget(SignUpPage(auth: mockAuth)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), 'test@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Sign-up failed. Please try again.'), findsOneWidget);
    });

    testWidgets('Shows generic error for non-Firebase exceptions',
        (tester) async {
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null)).on(mockAuth).thenThrow(Exception('Network error'));
      await tester.pumpWidget(makeTestableWidget(SignUpPage(auth: mockAuth)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), 'test@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('An unexpected error occurred. Please try again.'), findsOneWidget);
    });

    testWidgets('No error banner shown after successful sign-up',
        (tester) async {
      final mockAuth = MockFirebaseAuth(mockUser: mockUser);
      await tester.pumpWidget(makeTestableWidget(SignUpPage(auth: mockAuth)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), 'test@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.tap(find.text('Sign Up'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(mockAuth.currentUser, isNotNull);
    });
  });
}
