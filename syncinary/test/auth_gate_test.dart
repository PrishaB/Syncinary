import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/pages/auth_gate.dart';
import 'package:syncinary/pages/groups/my_groups_page.dart';
import 'package:syncinary/pages/login_page.dart';
import 'package:syncinary/pages/verify_email_page.dart';
import 'package:syncinary/services/group_service.dart';

void main() {
  Future<void> pumpGate(WidgetTester tester, MockFirebaseAuth auth) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          auth: auth,
          groupService: GroupService(
            firestore: FakeFirebaseFirestore(),
            auth: auth,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('[301-8] Signed-out session shows Login', (tester) async {
    await pumpGate(tester, MockFirebaseAuth());
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(MyGroupsPage), findsNothing);
    expect(find.byType(VerifyEmailPage), findsNothing);
  });

  for (final verified in [false, true]) {
    testWidgets('[301-8] Signed-in session routes with verified=$verified', (
      tester,
    ) async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(
          email: 'jack@example.com',
          isEmailVerified: verified,
        ),
      );
      await pumpGate(tester, auth);
      expect(
        find.byType(verified ? MyGroupsPage : VerifyEmailPage),
        findsOneWidget,
      );
      expect(
        find.byType(verified ? VerifyEmailPage : MyGroupsPage),
        findsNothing,
      );
      expect(find.byType(LoginPage), findsNothing);

      await auth.signOut();
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(MyGroupsPage), findsNothing);
      expect(find.byType(VerifyEmailPage), findsNothing);
    });
  }

  testWidgets('[301-8] Sign-in auth event replaces Login with My Groups', (
    tester,
  ) async {
    final auth = MockFirebaseAuth(
      mockUser: MockUser(email: 'jack@example.com', isEmailVerified: true),
    );
    await pumpGate(tester, auth);
    expect(find.byType(LoginPage), findsOneWidget);
    await auth.signInWithEmailAndPassword(
      email: 'jack@example.com',
      password: 'password123',
    );
    await tester.pumpAndSettle();
    expect(find.byType(MyGroupsPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });
}
