import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/pages/auth_gate.dart';
import 'package:syncinary/pages/groups/group_detail_page.dart';
import 'package:syncinary/pages/groups/join_group_page.dart';
import 'package:syncinary/pages/groups/my_groups_page.dart';
import 'package:syncinary/pages/login_page.dart';
import 'package:syncinary/pages/itinerary_builder.dart';
import 'package:syncinary/pages/schedule_builder_page.dart';
import 'package:syncinary/pages/verify_email_page.dart';
import 'package:syncinary/services/group_service.dart';

void main() {
  testWidgets(
    '[301-10] Switching accounts replaces groups and pending invites',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth();
      final service = GroupService(firestore: firestore, auth: auth);
      for (final uid in ['alice', 'bob']) {
        await firestore.collection('groups').doc(uid).set({
          'name': '$uid private trip',
          'memberIds': [uid],
          'members': {
            uid: {
              'username': uid,
              'email': '$uid@example.com',
              'role': 'admin',
            },
          },
        });
        await firestore.collection('invites').doc(uid).set({
          'recipientEmail': '$uid@example.com',
          'status': 'pending',
          'groupName': '$uid invited trip',
          'groupId': 'invited-$uid',
          'senderUsername': 'Host',
        });
      }
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: AuthGate(auth: auth, groupService: service),
        ),
      );
      await tester.pumpAndSettle();

      for (final uid in ['alice', 'bob']) {
        auth.mockUser = MockUser(
          uid: uid,
          email: '$uid@example.com',
          isEmailVerified: true,
        );
        await auth.signInWithEmailAndPassword(
          email: '$uid@example.com',
          password: 'password123',
        );
        await tester.pumpAndSettle();
        final other = uid == 'alice' ? 'bob' : 'alice';
        expect(find.text('$uid private trip'), findsOneWidget);
        expect(find.text('$other private trip'), findsNothing);

        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => JoinGroupPage(service: service),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('$uid invited trip'), findsOneWidget);
        expect(find.textContaining('$other invited trip'), findsNothing);
        navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();

        await auth.signOut();
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(MyGroupsPage), findsNothing);
        expect(
          find.textContaining('$uid private trip', skipOffstage: false),
          findsNothing,
        );
      }
    },
  );

  testWidgets(
    '[301-11] Unverified login cannot continue or go back into trip screens',
    (tester) async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(email: 'new@example.com', isEmailVerified: false),
      );
      final service = GroupService(
        firestore: FakeFirebaseFirestore(),
        auth: auth,
      );
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: LoginPage(auth: auth, groupService: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'new@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(find.byType(VerifyEmailPage), findsOneWidget);

      await tester.tap(find.text('Check verification'));
      await tester.pumpAndSettle();
      await navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(VerifyEmailPage), findsOneWidget);
      expect(find.byType(MyGroupsPage, skipOffstage: false), findsNothing);
      expect(find.byType(GroupDetailPage, skipOffstage: false), findsNothing);
      expect(find.byType(itinerary_builder, skipOffstage: false), findsNothing);
      expect(
        find.byType(ScheduleBuilderPage, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.textContaining('Your email is not verified yet.'),
        findsOneWidget,
      );
      expect(auth.currentUser!.emailVerified, isFalse);
    },
  );
}
