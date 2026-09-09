import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/pages/login_page.dart';
import 'package:syncinary/pages/verify_email_page.dart';

void main() {
  testWidgets('Sends verification on signup and prevents immediate resend', (
    tester,
  ) async {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(email: 'new@example.com', isEmailVerified: false),
    );
    await tester.pumpWidget(
      MaterialApp(home: VerifyEmailPage(auth: auth, sendOnOpen: true)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Verification email sent. Check your inbox and spam folder.'),
      findsOneWidget,
    );
    expect(find.text('You can resend after 60 seconds'), findsOneWidget);
    await tester.pump(const Duration(seconds: 60));
    expect(find.text('Resend verification email'), findsOneWidget);
  });

  testWidgets('Unverified account cannot continue', (tester) async {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(email: 'new@example.com', isEmailVerified: false),
    );
    await tester.pumpWidget(MaterialApp(home: VerifyEmailPage(auth: auth)));
    await tester.tap(find.text("Check verification"));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Your email is not verified yet. Open the link in your email and try again.',
      ),
      findsOneWidget,
    );
    expect(find.byType(VerifyEmailPage), findsOneWidget);
  });

  testWidgets('Back to sign in signs out the unverified account', (
    tester,
  ) async {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(email: 'new@example.com', isEmailVerified: false),
    );
    await tester.pumpWidget(MaterialApp(home: VerifyEmailPage(auth: auth)));
    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    expect(auth.currentUser, isNull);
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
