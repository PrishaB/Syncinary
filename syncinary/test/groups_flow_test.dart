import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syncinary/models/group.dart';
import 'package:syncinary/pages/groups/my_groups_page.dart';
import 'package:syncinary/services/group_service.dart';
import 'package:syncinary/theme/app_theme.dart';

Widget makeTestableWidget(Widget child) {
  return MaterialApp(theme: buildAppTheme(), home: child);
}

Future<void> letOverlayDismiss(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1400));
  await tester.pumpAndSettle();
}

/// Seeds the fake Firestore `users` collection and returns a [GroupService]
/// wired to fakes, with "me" already signed in as the given user.
Future<GroupService> seedService(
  FakeFirebaseFirestore firestore, {
  required String uid,
  required String email,
  required String username,
}) async {
  await firestore.collection('users').doc(uid).set({
    'username': username,
    'email': email,
    'createdAt': FieldValue.serverTimestamp(),
  });
  final auth = MockFirebaseAuth(
    mockUser: MockUser(uid: uid, email: email, displayName: username),
    signedIn: true,
  );
  return GroupService(firestore: firestore, auth: auth);
}

void main() {
  testWidgets('Group creation and management flow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final firestore = FakeFirebaseFirestore();
    final service = await seedService(
      firestore,
      uid: 'me-uid',
      email: 'me@syncinary.app',
      username: 'You',
    );

    // Seed two other users so they can be found/invited by email, plus two
    // groups: one where "me" is admin, one where "me" is a regular member.
    await firestore.collection('users').doc('alex-uid').set({
      'username': 'Alex Chen',
      'email': 'alex@syncinary.app',
    });
    await firestore.collection('users').doc('jordan-uid').set({
      'username': 'Jordan Lee',
      'email': 'jordan@syncinary.app',
    });

    await firestore.collection('groups').doc('bali').set({
      'name': 'Bali Trip 2026',
      'inviteCode': 'BALI26',
      'memberIds': ['me-uid', 'alex-uid', 'jordan-uid'],
      'members': {
        'me-uid': {'username': 'You', 'email': 'me@syncinary.app', 'role': 'admin'},
        'alex-uid': {'username': 'Alex Chen', 'email': 'alex@syncinary.app', 'role': 'user'},
        'jordan-uid': {'username': 'Jordan Lee', 'email': 'jordan@syncinary.app', 'role': 'user'},
      },
    });
    await firestore.collection('groups').doc('ski').set({
      'name': 'Ski Weekend',
      'inviteCode': 'SKIWK',
      'memberIds': ['sam-uid', 'me-uid'],
      'members': {
        'sam-uid': {'username': 'Sam Patel', 'email': 'sam@syncinary.app', 'role': 'admin'},
        'me-uid': {'username': 'You', 'email': 'me@syncinary.app', 'role': 'user'},
      },
    });
    await firestore.collection('invites').doc('inv1').set({
      'groupId': 'nyc',
      'groupName': 'NYC Food Tour',
      'senderUid': 'riley-uid',
      'senderUsername': 'Riley Ortiz',
      'recipientUid': 'me-uid',
      'recipientEmail': 'me@syncinary.app',
      'role': 'user',
      'status': 'pending',
    });

    await tester.pumpWidget(makeTestableWidget(MyGroupsPage(service: service)));
    await tester.pumpAndSettle();

    // ── My Groups list shows seeded groups ──
    expect(find.text('My Groups'), findsOneWidget);
    expect(find.text('Bali Trip 2026'), findsOneWidget);
    expect(find.text('Ski Weekend'), findsOneWidget);

    // ── Open the group where "me" is admin ──
    await tester.tap(find.text('Bali Trip 2026'));
    await tester.pumpAndSettle();

    expect(find.text('Invite Members'), findsOneWidget);
    expect(find.text('Plan Itinerary'), findsOneWidget);
    expect(find.text('Track Costs'), findsOneWidget);
    expect(find.text('Current Group Members'), findsOneWidget);
    expect(find.text('Delete Trip?'), findsOneWidget);
    expect(find.text('Transfer Admin Status'), findsOneWidget);
    expect(find.text('Alex Chen'), findsOneWidget);

    // ── Remove a member ──
    await tester.tap(find.text('Remove').first);
    await tester.pumpAndSettle();
    expect(find.text('Are you sure you want to remove Alex Chen?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmation_dialog_confirm')));
    await tester.pumpAndSettle();
    await letOverlayDismiss(tester);
    expect(find.text('Alex Chen'), findsNothing);

    // ── Invite a member by email: unknown email is rejected ──
    await tester.tap(find.text('Invite Members'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Add User by Email'), 'nobody@nowhere.com');
    await tester.tap(find.text('Send Invite'));
    await tester.pumpAndSettle();
    expect(find.text('No Syncinary account found for that email.'), findsOneWidget);

    // ── Invite a member by email: known email creates a pending invite ──
    await tester.enterText(
        find.widgetWithText(TextField, 'Add User by Email'), 'jordan@syncinary.app');
    await tester.tap(find.text('Send Invite'));
    await tester.pumpAndSettle();
    await letOverlayDismiss(tester);
    expect(find.text('Invite sent to jordan@syncinary.app'), findsNothing); // overlay dismissed
    final pendingInvites = await firestore
        .collection('invites')
        .where('recipientEmail', isEqualTo: 'jordan@syncinary.app')
        .get();
    expect(pendingInvites.docs, hasLength(1));

    // ── Transfer admin status away from "me" ──
    await tester.tap(find.text('Transfer Admin Status'));
    await tester.pumpAndSettle();
    expect(find.text('Transfer Admin Status to...'), findsOneWidget);
    expect(find.text('Jordan Lee'), findsWidgets);
    await tester.tap(find.text('Jordan Lee').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Selection'));
    await tester.pumpAndSettle();
    await letOverlayDismiss(tester);

    // No longer admin: admin-only controls are gone.
    expect(find.text('Delete Trip?'), findsNothing);
    expect(find.text('Transfer Admin Status'), findsNothing);
    expect(find.text('Group User Status: User'), findsOneWidget);

    final baliDoc = await firestore.collection('groups').doc('bali').get();
    expect(baliDoc.data()!['members']['jordan-uid']['role'], 'admin');
    expect(baliDoc.data()!['members']['me-uid']['role'], 'user');

    // ── Back to My Groups ──
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('My Groups'), findsOneWidget);

    // ── Add a new group and delete it (tests the admin delete-trip path) ──
    await tester.tap(find.text('Add Group'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Group name'), 'Delete Test Group');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Test Group'), findsOneWidget);

    await tester.tap(find.text('Delete Test Group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Trip?'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm deletion of "Delete Test Group"?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmation_dialog_confirm')));
    await tester.pumpAndSettle();
    await letOverlayDismiss(tester);
    expect(find.text('My Groups'), findsOneWidget);
    expect(find.text('Delete Test Group'), findsNothing);

    // ── Leave a group ──
    await tester.tap(find.text('Leave Group'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmation_dialog_confirm')));
    await tester.pumpAndSettle();

    // ── Join Group screen: pending invite + invite-code join ──
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join Group'));
    await tester.pumpAndSettle();
    expect(find.text('Pending Group Invites'), findsOneWidget);
    expect(find.text('Riley Ortiz — NYC Food Tour'), findsOneWidget);
    expect(find.text('Join Through Invite Code'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Enter code'), 'BOGUS');
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();
    expect(find.text('No group found for that code.'), findsOneWidget);
  });

  test('removeMember actually removes the member from Firestore', () async {
    final firestore = FakeFirebaseFirestore();
    final service = await seedService(
      firestore,
      uid: 'me-uid',
      email: 'me@syncinary.app',
      username: 'You',
    );
    await firestore.collection('groups').doc('bali').set({
      'name': 'Bali Trip 2026',
      'inviteCode': 'BALI26',
      'memberIds': ['me-uid', 'alex-uid'],
      'members': {
        'me-uid': {'username': 'You', 'email': 'me@syncinary.app', 'role': 'admin'},
        'alex-uid': {'username': 'Alex Chen', 'email': 'alex@syncinary.app', 'role': 'user'},
      },
    });
    final before = await firestore.collection('groups').doc('bali').get();
    final group = Group.fromDoc(before);
    final alex = group.memberById('alex-uid')!;

    await service.removeMember(group, alex);

    final after = await firestore.collection('groups').doc('bali').get();
    expect((after.data()!['members'] as Map).containsKey('alex-uid'), isFalse);
  });

  test('joinByCode looks up inviteCodes and adds the joiner as a member', () async {
    final firestore = FakeFirebaseFirestore();
    final admin = await seedService(
      firestore,
      uid: 'admin-uid',
      email: 'admin@syncinary.app',
      username: 'Admin',
    );
    final group = await admin.createGroup('Road Trip');

    final joiner = await seedService(
      firestore,
      uid: 'joiner-uid',
      email: 'joiner@syncinary.app',
      username: 'Joiner',
    );
    final joined = await joiner.joinByCode(group.inviteCode!);
    expect(joined, isTrue);

    final after = await firestore.collection('groups').doc(group.id).get();
    final members = after.data()!['members'] as Map;
    expect(members.containsKey('joiner-uid'), isTrue);
    expect(members['joiner-uid']['role'], 'user');
    expect((after.data()!['memberIds'] as List), contains('joiner-uid'));
  });

  test('acceptInvite adds the invitee as a member and removes the invite', () async {
    final firestore = FakeFirebaseFirestore();
    final admin = await seedService(
      firestore,
      uid: 'admin-uid',
      email: 'admin@syncinary.app',
      username: 'Admin',
    );
    final group = await admin.createGroup('Road Trip');

    final invitee = await seedService(
      firestore,
      uid: 'invitee-uid',
      email: 'invitee@syncinary.app',
      username: 'Invitee',
    );
    await firestore.collection('invites').doc('inv-1').set({
      'groupId': group.id,
      'groupName': group.name,
      'senderUid': 'admin-uid',
      'senderUsername': 'Admin',
      'recipientUid': 'invitee-uid',
      'recipientEmail': 'invitee@syncinary.app',
      'role': 'admin',
      'status': 'pending',
    });
    final invite = GroupInvite.fromDoc(await firestore.collection('invites').doc('inv-1').get());

    await invitee.acceptInvite(invite);

    final after = await firestore.collection('groups').doc(group.id).get();
    final members = after.data()!['members'] as Map;
    expect(members.containsKey('invitee-uid'), isTrue);
    expect(members['invitee-uid']['role'], 'admin');
    expect((await firestore.collection('invites').doc('inv-1').get()).exists, isFalse);
  });

  test('inviteMemberByEmail throws for an unregistered email', () async {
    final firestore = FakeFirebaseFirestore();
    final service = await seedService(
      firestore,
      uid: 'me-uid',
      email: 'me@syncinary.app',
      username: 'You',
    );
    final group = await service.createGroup('Solo Trip');

    expect(
      () => service.inviteMemberByEmail(group, 'nobody@nowhere.com', GroupRole.user),
      throwsA(isA<UserNotFoundException>()),
    );
  });
}
