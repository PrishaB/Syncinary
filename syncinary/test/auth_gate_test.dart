import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/pages/groups/my_groups_page.dart';
import 'package:syncinary/pages/login_page.dart';
import 'package:syncinary/pages/verify_email_page.dart';
import 'package:syncinary/services/group_service.dart';
import 'package:syncinary/widgets/auth_gate.dart';

Future<void> _pumpGate(WidgetTester tester, MockFirebaseAuth auth) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AuthGate(
        auth: auth,
        groupService: GroupService(
          auth: auth,
          firestore: FakeFirebaseFirestore(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectOnlyPage(Type page) {
  for (final candidate in [LoginPage, VerifyEmailPage, MyGroupsPage]) {
    expect(
      find.byType(candidate),
      candidate == page ? findsOneWidget : findsNothing,
    );
  }
  expect(find.byType(AuthGate), findsOneWidget);
}

void main() {
  testWidgets('Signed-out user sees Login', (tester) async {
    final auth = MockFirebaseAuth();

    await _pumpGate(tester, auth);

    _expectOnlyPage(LoginPage);
    expect(find.text('Sign In'), findsOneWidget);
    expect(auth.currentUser, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Signed-in unverified user sees Verify Email', (
    tester,
  ) async {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(
        uid: 'unverified-user',
        email: 'unverified@example.com',
        isEmailVerified: false,
      ),
    );

    await _pumpGate(tester, auth);

    _expectOnlyPage(VerifyEmailPage);
    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('unverified@example.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Signed-in verified user sees My Groups', (tester) async {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(
        uid: 'verified-user',
        email: 'verified@example.com',
        isEmailVerified: true,
      ),
    );

    await _pumpGate(tester, auth);

    _expectOnlyPage(MyGroupsPage);
    expect(find.text('My Groups'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final verified in [false, true]) {
    testWidgets(
      'Sign-out replaces ${verified ? 'My Groups' : 'Verify Email'} with Login',
      (tester) async {
        final auth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(
            uid: 'session-user',
            email: 'session@example.com',
            isEmailVerified: verified,
          ),
        );
        await _pumpGate(tester, auth);
        _expectOnlyPage(verified ? MyGroupsPage : VerifyEmailPage);
        final gateElement = tester.element(find.byType(AuthGate));

        // Exercise the stream-driven transition on the already-mounted gate.
        // Page buttons navigate themselves and could hide a broken subscription.
        await auth.signOut();
        await tester.pumpAndSettle();

        expect(auth.currentUser, isNull);
        _expectOnlyPage(LoginPage);
        expect(tester.element(find.byType(AuthGate)), same(gateElement));
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.text('session@example.com'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
