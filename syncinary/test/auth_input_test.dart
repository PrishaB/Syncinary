import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/pages/login_page.dart';
import 'package:syncinary/pages/signup_page.dart';
import 'package:syncinary/pages/verify_email_page.dart';

class _RecordingAuth extends MockFirebaseAuth {
  _RecordingAuth({this.reject = false})
    : super(mockUser: MockUser(uid: 'input-user', isEmailVerified: false));

  final bool reject;
  final signups = <({String email, String password})>[];
  final logins = <({String email, String password})>[];

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    signups.add((email: email, password: password));
    if (reject) throw FirebaseAuthException(code: 'email-already-in-use');
    return super.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    logins.add((email: email, password: password));
    if (reject) throw FirebaseAuthException(code: 'invalid-credential');
    return super.signInWithEmailAndPassword(email: email, password: password);
  }
}

Future<void> _submit(
  WidgetTester tester, {
  required bool signup,
  required _RecordingAuth auth,
  required FakeFirebaseFirestore database,
  String name = 'Traveler',
  String email = 'traveler@example.com',
  String password = 'password123',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: signup
          ? SignUpPage(auth: auth, firestore: database)
          : LoginPage(auth: auth),
    ),
  );
  await tester.pumpAndSettle();
  final fields = find.byType(TextFormField);
  if (signup) await tester.enterText(fields.at(0), name);
  await tester.enterText(fields.at(signup ? 1 : 0), email);
  await tester.enterText(fields.at(signup ? 2 : 1), password);
  final button = find.text(signup ? 'Sign Up' : 'Sign In');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _disposePage(WidgetTester tester) async {
  // Successful signup starts the verification-email cooldown timer.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('Whitespace-only name never reaches Auth or Firestore', (
    tester,
  ) async {
    final auth = _RecordingAuth();
    final database = FakeFirebaseFirestore();
    await _submit(
      tester,
      signup: true,
      auth: auth,
      database: database,
      name: '   \t   ',
    );

    expect(find.text('Please enter your name'), findsOneWidget);
    expect(auth.signups, isEmpty);
    expect(auth.currentUser, isNull);
    expect((await database.collection('users').get()).docs, isEmpty);
    await _disposePage(tester);
  });

  final names = {
    'very long name': List.filled(4096, 'A').join(),
    'SQL-style name': "Robert'); DROP TABLE users;--",
    'script-style name': '<script>alert("name")</script>',
  };
  for (final entry in names.entries) {
    testWidgets('${entry.key} is stored as literal profile data', (
      tester,
    ) async {
      final auth = _RecordingAuth();
      final database = FakeFirebaseFirestore();
      await database.collection('users').doc('existing-user').set({
        'username': 'Existing User',
        'email': 'existing@example.com',
      });
      await _submit(
        tester,
        signup: true,
        auth: auth,
        database: database,
        name: '  ${entry.value}  ',
      );

      expect(auth.signups, hasLength(1));
      expect(auth.currentUser!.displayName, entry.value);
      final profile = await database
          .collection('users')
          .doc(auth.currentUser!.uid)
          .get();
      expect(profile.data()!['username'], entry.value);
      expect(profile.data()!['email'], 'traveler@example.com');
      expect((await database.collection('users').get()).docs, hasLength(2));
      expect(
        (await database.collection('users').doc('existing-user').get()).data(),
        {'username': 'Existing User', 'email': 'existing@example.com'},
      );
      expect(find.byType(VerifyEmailPage), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
      await _disposePage(tester);
    });
  }

  for (final signup in [true, false]) {
    final flow = signup ? 'signup' : 'login';
    for (final email in [
      '  TRAVELER@EXAMPLE.COM  ',
      '  Traveler+Trip@Example.COM  ',
    ]) {
      testWidgets('$flow normalizes $email before calling Auth', (
        tester,
      ) async {
        final auth = _RecordingAuth();
        final database = FakeFirebaseFirestore();
        await _submit(
          tester,
          signup: signup,
          auth: auth,
          database: database,
          email: email,
        );

        final requests = signup ? auth.signups : auth.logins;
        expect(requests, [
          (email: email.trim().toLowerCase(), password: 'password123'),
        ]);
        expect(auth.currentUser, isNotNull);
        expect(find.byType(VerifyEmailPage), findsOneWidget);
        if (signup) {
          final profile = await database
              .collection('users')
              .doc(auth.currentUser!.uid)
              .get();
          expect(profile.data()!['email'], email.trim().toLowerCase());
        }
        expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
        await _disposePage(tester);
      });
    }

    for (final email in ["' OR 1=1;--", '<script>alert("email")</script>']) {
      testWidgets(
        '[301-9] $flow rejects malformed injection-style email $email',
        (tester) async {
          final auth = _RecordingAuth();
          final database = FakeFirebaseFirestore();
          await _submit(
            tester,
            signup: signup,
            auth: auth,
            database: database,
            email: email,
          );

          expect(find.text('Please enter a valid email'), findsOneWidget);
          expect(auth.signups, isEmpty);
          expect(auth.logins, isEmpty);
          expect(auth.currentUser, isNull);
          expect((await database.collection('users').get()).docs, isEmpty);
          await _disposePage(tester);
        },
      );
    }

    testWidgets(
      '$flow forwards injection-style password unchanged and honors Auth rejection',
      (tester) async {
        final auth = _RecordingAuth(reject: true);
        final database = FakeFirebaseFirestore();
        const password = '  \' OR 1=1;--<script>alert("password")</script>  ';
        await _submit(
          tester,
          signup: signup,
          auth: auth,
          database: database,
          password: password,
        );

        final requests = signup ? auth.signups : auth.logins;
        expect(requests, [(email: 'traveler@example.com', password: password)]);
        expect(auth.currentUser, isNull);
        expect(find.byType(VerifyEmailPage), findsNothing);
        expect(
          find.text(
            signup
                ? 'This email address is already registered.'
                : 'Invalid email or password.',
          ),
          findsOneWidget,
        );
        expect((await database.collection('users').get()).docs, isEmpty);
        await _disposePage(tester);
      },
    );
  }
}
