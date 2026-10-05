import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/pages/groups/group_detail_page.dart';
import 'package:syncinary/pages/groups/join_group_page.dart';
import 'package:syncinary/pages/groups/my_groups_page.dart';
import 'package:syncinary/pages/login_page.dart';
import 'package:syncinary/pages/schedule_builder_page.dart';
import 'package:syncinary/services/group_service.dart';
import 'package:syncinary/widgets/auth_gate.dart';

class _Credential extends Fake implements UserCredential {
  _Credential(this.user);
  @override
  final User user;
}

/// One Auth instance with two accounts, selected by the actual login form.
class _SessionAuth extends Fake implements FirebaseAuth {
  final changes = StreamController<User?>.broadcast();
  final accounts = {
    for (final id in ['alice', 'bob'])
      '$id@example.com': MockUser(
        uid: id,
        email: '$id@example.com',
        displayName: id,
        isEmailVerified: true,
      ),
  };
  final signedInEmails = <String>[];
  int signOutCount = 0;

  @override
  User? currentUser;

  @override
  Stream<User?> authStateChanges() async* {
    yield currentUser;
    yield* changes.stream;
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final user = accounts[email];
    if (user == null || password != 'password123') {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    currentUser = user;
    signedInEmails.add(email);
    changes.add(user);
    return _Credential(user);
  }

  @override
  Future<void> signOut() async {
    signOutCount++;
    currentUser = null;
    changes.add(null);
  }
}

Future<void> _seed(FakeFirebaseFirestore database, String id) async {
  await database.collection('users').doc(id).set({
    'username': id,
    'email': '$id@example.com',
  });
  final group = database.collection('groups').doc('$id-trip');
  await group.set({
    'name': '$id private trip',
    'memberIds': [id],
    'members': {
      id: {'username': id, 'email': '$id@example.com', 'role': 'admin'},
    },
  });
  await database.collection('invites').doc('$id-invite').set({
    'groupId': '$id-invited-trip',
    'groupName': '$id private invitation',
    'senderUid': 'host',
    'senderUsername': 'Host',
    'recipientUid': id,
    'recipientEmail': '$id@example.com',
    'role': 'user',
    'status': 'pending',
  });
  await group.collection('itineraryStarted').doc(id).set({
    'startedAt': Timestamp.now(),
  });
  await group.collection('scheduleDays').doc('2026-05-03').set({
    'date': Timestamp.fromDate(DateTime(2026, 5, 3)),
  });
  await group.collection('scheduleItems').doc('$id-hotel').set({
    'day': '2026-05-03',
    'type': 'hotel',
    'title': '$id private hotel',
    'details': '$id private booking',
    'addedBy': id,
    'createdAt': Timestamp.now(),
  });
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _login(WidgetTester tester, String id) async {
  expect(find.byType(LoginPage), findsOneWidget);
  await tester.enterText(find.byType(TextFormField).at(0), '$id@example.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'password123');
  await _tap(tester, 'Sign In');
  expect(find.byType(MyGroupsPage), findsOneWidget);
}

void _expectAliceAbsent() {
  for (final value in [
    'alice private trip',
    'alice private invitation',
    'alice private hotel',
    'alice private booking',
  ]) {
    // Include inactive routes so a hidden old screen cannot satisfy isolation.
    expect(find.textContaining(value, skipOffstage: false), findsNothing);
  }
}

void main() {
  for (final logoutFromDetail in [false, true]) {
    testWidgets(
      'Account switch via ${logoutFromDetail ? 'group detail' : 'My Groups'} logout isolates groups, invites and itinerary',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1100, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final database = FakeFirebaseFirestore();
        final auth = _SessionAuth();
        addTearDown(auth.changes.close);
        await _seed(database, 'alice');
        await _seed(database, 'bob');
        final service = GroupService(firestore: database, auth: auth);
        final navigatorKey = GlobalKey<NavigatorState>();

        // Mount once: retain the same navigator, Auth and Firestore across users.
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigatorKey,
            home: AuthGate(auth: auth, groupService: service),
          ),
        );
        await tester.pumpAndSettle();
        final navigator = navigatorKey.currentState;
        await _login(tester, 'alice');
        expect(find.text('alice private trip'), findsOneWidget);
        expect(find.text('bob private trip'), findsNothing);
        await _tap(tester, 'Join Group');
        expect(find.textContaining('alice private invitation'), findsOneWidget);
        expect(find.textContaining('bob private invitation'), findsNothing);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await _tap(tester, 'alice private trip');
        await _tap(tester, 'Plan Itinerary');
        expect(find.byType(ScheduleBuilderPage), findsOneWidget);
        expect(find.text('alice private hotel'), findsOneWidget);
        expect(find.text('alice private booking'), findsOneWidget);
        expect(find.text('bob private hotel'), findsNothing);
        await tester.pageBack();
        await tester.pumpAndSettle();
        if (!logoutFromDetail) {
          await tester.pageBack();
          await tester.pumpAndSettle();
        }

        await tester.tap(find.byTooltip('Log out'));
        await tester.pumpAndSettle();
        expect(auth.currentUser, isNull);
        expect(auth.signOutCount, 1);
        expect(find.byType(LoginPage), findsOneWidget);
        _expectAliceAbsent();
        expect(navigatorKey.currentState!.canPop(), isFalse);
        await _login(tester, 'bob');
        expect(auth.currentUser!.uid, 'bob');
        expect(auth.signedInEmails, ['alice@example.com', 'bob@example.com']);
        expect(navigatorKey.currentState, same(navigator));
        expect(find.text('bob private trip'), findsOneWidget);
        _expectAliceAbsent();
        expect(await navigatorKey.currentState!.maybePop(), isFalse);
        await tester.pumpAndSettle();

        await _tap(tester, 'Join Group');
        expect(find.byType(JoinGroupPage), findsOneWidget);
        expect(find.textContaining('bob private invitation'), findsOneWidget);
        _expectAliceAbsent();
        // Updates to A's data must not reappear through an old subscription.
        await database.collection('invites').doc('alice-invite').update({
          'groupName': 'alice updated invitation',
        });
        await tester.pumpAndSettle();
        expect(
          find.textContaining('alice updated invitation', skipOffstage: false),
          findsNothing,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        await _tap(tester, 'bob private trip');
        expect(find.byType(GroupDetailPage), findsOneWidget);
        _expectAliceAbsent();
        await _tap(tester, 'Plan Itinerary');
        expect(find.byType(ScheduleBuilderPage), findsOneWidget);
        expect(find.text('bob private hotel'), findsOneWidget);
        expect(find.text('bob private booking'), findsOneWidget);
        _expectAliceAbsent();
        await database
            .collection('groups')
            .doc('alice-trip')
            .collection('scheduleItems')
            .doc('alice-hotel')
            .update({'title': 'alice updated hotel'});
        await tester.pumpAndSettle();
        expect(
          find.text('alice updated hotel', skipOffstage: false),
          findsNothing,
        );
        expect(find.text('bob private hotel'), findsOneWidget);
        // Isolation must not be achieved by deleting the first user's data.
        expect(
          (await database.collection('groups').doc('alice-trip').get()).exists,
          isTrue,
        );
        expect(
          (await database.collection('invites').doc('alice-invite').get())
              .exists,
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
