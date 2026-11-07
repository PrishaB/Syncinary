import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syncinary/models/group.dart';
import 'package:syncinary/pages/groups/group_detail_page.dart';
import 'package:syncinary/pages/groups/join_group_page.dart';
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

  // ─────────────────────────────────────────────────────────
  // Tests tagged with Doc/Verification_Test_Inventory.md IDs
  // ─────────────────────────────────────────────────────────

  // ── 401-4: model parsing defaults ──

  test('[401-4] Group.fromDoc and GroupMember.fromMap default missing and null fields', () async {
    final firestore = FakeFirebaseFirestore();
    final groups = firestore.collection('groups');

    final missing = Group.fromDoc(await groups.doc('never-created').get());
    expect(missing.name, '');
    expect(missing.inviteCode, isNull);
    expect(missing.members, isEmpty);

    await groups.doc('null-members').set({'name': null, 'inviteCode': null, 'members': null});
    final nullMembers = Group.fromDoc(await groups.doc('null-members').get());
    expect(nullMembers.name, '');
    expect(nullMembers.inviteCode, isNull);
    expect(nullMembers.members, isEmpty);

    await groups.doc('sparse').set({
      'members': {
        'null-uid': {'username': null, 'email': null, 'role': null},
        'empty-uid': <String, dynamic>{},
      },
    });
    final sparse = Group.fromDoc(await groups.doc('sparse').get());
    for (final id in ['null-uid', 'empty-uid']) {
      final member = sparse.memberById(id)!;
      expect(member.username, 'Unknown');
      expect(member.email, '');
      expect(member.role, GroupRole.user);
    }
  });

  test('[401-4] GroupInvite.fromDoc defaults missing and null fields', () async {
    final firestore = FakeFirebaseFirestore();
    final invites = firestore.collection('invites');
    await invites.doc('nulls').set({
      'senderUsername': null,
      'groupId': null,
      'groupName': null,
      'role': null,
    });

    for (final id in ['nulls', 'never-created']) {
      final invite = GroupInvite.fromDoc(await invites.doc(id).get());
      expect(invite.id, id);
      expect(invite.senderUsername, 'Someone');
      expect(invite.groupId, '');
      expect(invite.groupName, '');
      expect(invite.role, GroupRole.user);
    }
  });

  test('[401-4] groupRoleFromString maps anything but "admin" to user', () {
    expect(groupRoleFromString('admin'), GroupRole.admin);
    for (final value in ['user', null, '', 'owner', 'ADMIN']) {
      expect(groupRoleFromString(value), GroupRole.user, reason: 'value: $value');
    }
  });

  // ── 501-3: declining an invite ──

  test('[501-3] declineInvite deletes the invite without joining the group', () async {
    final firestore = FakeFirebaseFirestore();
    final admin = await seedService(firestore,
        uid: 'admin-uid', email: 'admin@syncinary.app', username: 'Admin');
    final group = await admin.createGroup('Road Trip');
    final invitee = await seedService(firestore,
        uid: 'invitee-uid', email: 'invitee@syncinary.app', username: 'Invitee');
    await admin.inviteMemberByEmail(group, 'invitee@syncinary.app', GroupRole.user);

    final pending = await invitee.pendingInvitesStream().first;
    expect(pending, hasLength(1));
    await invitee.declineInvite(pending.single);

    expect((await firestore.collection('invites').get()).docs, isEmpty);
    expect(await membersOf(firestore, group.id), isNot(contains('invitee-uid')));
  });

  // ── 501-5: leaving (partial; see the inventory row) ──

  test('[501-5] The last member leaving deletes the group', () async {
    final firestore = FakeFirebaseFirestore();
    final admin = await seedService(firestore,
        uid: 'admin-uid', email: 'admin@syncinary.app', username: 'Admin');
    final group = await admin.createGroup('Solo Trip');

    await admin.leaveGroup(group);

    expect((await firestore.collection('groups').doc(group.id).get()).exists, isFalse);
  });

  // ── 501-7: transferring admin and role lookups ──

  test('[501-7] transferAdmin promotes the new admin, demotes the old one, leaves one admin',
      () async {
    final firestore = FakeFirebaseFirestore();
    final me =
        await seedService(firestore, uid: 'me-uid', email: 'me@syncinary.app', username: 'You');
    final group = await seedGroup(firestore, 'bali', {
      'me-uid': memberData('You', 'admin'),
      'alex-uid': memberData('Alex Chen', 'user'),
      'jordan-uid': memberData('Jordan Lee', 'user'),
    });

    await me.transferAdmin(group, group.memberById('jordan-uid')!);

    expect(await rolesOf(firestore, 'bali'),
        {'me-uid': 'user', 'alex-uid': 'user', 'jordan-uid': 'admin'});
  });

  test('[501-7] transferAdmin to a member who was already removed does not bring them back',
      () async {
    final firestore = FakeFirebaseFirestore();
    final me =
        await seedService(firestore, uid: 'me-uid', email: 'me@syncinary.app', username: 'You');
    final staleGroup = await seedGroup(firestore, 'bali', {
      'me-uid': memberData('You', 'admin'),
      'alex-uid': memberData('Alex Chen', 'user'),
    });
    final alex = staleGroup.memberById('alex-uid')!;

    await me.removeMember(staleGroup, alex);
    await me.transferAdmin(staleGroup, alex); // the screen still showed Alex

    expect(await membersOf(firestore, 'bali'), isNot(contains('alex-uid')));
    final doc = await firestore.collection('groups').doc('bali').get();
    expect(doc.data()!['memberIds'], isNot(contains('alex-uid')));
  });

  test('[501-7] roleOf / isAdmin: admin, user, and non-member (defaults to user)', () async {
    final firestore = FakeFirebaseFirestore();
    final group = await seedGroup(firestore, 'bali', {
      'me-uid': memberData('You', 'admin'),
      'alex-uid': memberData('Alex Chen', 'user'),
    });
    final me =
        await seedService(firestore, uid: 'me-uid', email: 'me@syncinary.app', username: 'You');
    final alex = await seedService(firestore,
        uid: 'alex-uid', email: 'alex@syncinary.app', username: 'Alex');
    final outsider = await seedService(firestore,
        uid: 'outsider-uid', email: 'outsider@syncinary.app', username: 'Outsider');

    expect(me.roleOf(group), GroupRole.admin);
    expect(me.isAdmin(group), isTrue);
    expect(alex.roleOf(group), GroupRole.user);
    expect(alex.isAdmin(group), isFalse);
    expect(outsider.roleOf(group), GroupRole.user);
    expect(outsider.isAdmin(group), isFalse);
  });

  // ── 501-8: invites ──

  test('[501-8] inviteMemberByEmail writes a pending invite with role, sender and lowercased email',
      () async {
    final firestore = FakeFirebaseFirestore();
    final me =
        await seedService(firestore, uid: 'me-uid', email: 'me@syncinary.app', username: 'You');
    await firestore
        .collection('users')
        .doc('jordan-uid')
        .set({'username': 'Jordan Lee', 'email': 'jordan@syncinary.app'});
    final group = await me.createGroup('Road Trip');

    await me.inviteMemberByEmail(group, '  Jordan@Syncinary.APP ', GroupRole.admin);

    final invite = (await firestore.collection('invites').get()).docs.single.data();
    expect(invite['groupId'], group.id);
    expect(invite['groupName'], 'Road Trip');
    expect(invite['senderUid'], 'me-uid');
    expect(invite['senderUsername'], 'You');
    expect(invite['recipientUid'], 'jordan-uid');
    expect(invite['recipientEmail'], 'jordan@syncinary.app');
    expect(invite['role'], 'admin');
    expect(invite['status'], 'pending');
  });

  test('[501-8] acceptInvite grants only the role on the invite', () async {
    final firestore = FakeFirebaseFirestore();
    final admin = await seedService(firestore,
        uid: 'admin-uid', email: 'admin@syncinary.app', username: 'Admin');
    final group = await admin.createGroup('Road Trip');
    final asUser = await seedService(firestore,
        uid: 'user-uid', email: 'user@syncinary.app', username: 'U');
    final asAdmin = await seedService(firestore,
        uid: 'admin2-uid', email: 'admin2@syncinary.app', username: 'A');
    await admin.inviteMemberByEmail(group, 'user@syncinary.app', GroupRole.user);
    await admin.inviteMemberByEmail(group, 'admin2@syncinary.app', GroupRole.admin);

    await asUser.acceptInvite((await asUser.pendingInvitesStream().first).single);
    await asAdmin.acceptInvite((await asAdmin.pendingInvitesStream().first).single);

    expect(await rolesOf(firestore, group.id),
        {'admin-uid': 'admin', 'user-uid': 'user', 'admin2-uid': 'admin'});
  });

  // ── 501-9: creating, renaming and deleting groups ──

  test('[501-9] createGroup makes the creator admin and registers a 6-char uppercase code',
      () async {
    final firestore = FakeFirebaseFirestore();
    final me =
        await seedService(firestore, uid: 'me-uid', email: 'me@syncinary.app', username: 'You');

    final group = await me.createGroup('Road Trip');

    final data = (await firestore.collection('groups').doc(group.id).get()).data()!;
    expect(data['name'], 'Road Trip');
    expect(data['memberIds'], ['me-uid']);
    expect(data['members']['me-uid']['role'], 'admin');
    expect(group.inviteCode, matches(RegExp(r'^[A-Z0-9]{6}$')));
    expect(data['inviteCode'], group.inviteCode);
    final mapping = await firestore.collection('inviteCodes').doc(group.inviteCode).get();
    expect(mapping.data(), {'groupId': group.id});
  });

  test('[501-9] renameGroup and deleteGroup only touch that group', () async {
    final firestore = FakeFirebaseFirestore();
    final me =
        await seedService(firestore, uid: 'me-uid', email: 'me@syncinary.app', username: 'You');
    final target = await me.createGroup('Road Trip');
    final other = await me.createGroup('Ski Weekend');
    final groups = firestore.collection('groups');

    await me.renameGroup(target, 'Road Trip 2027');
    expect((await groups.doc(target.id).get()).data()!['name'], 'Road Trip 2027');
    expect((await groups.doc(other.id).get()).data()!['name'], 'Ski Weekend');

    await me.deleteGroup(target);
    expect((await groups.doc(target.id).get()).exists, isFalse);
    expect((await groups.doc(other.id).get()).exists, isTrue);
  });

  // ── 501-10: admin-only controls on the group page ──

  testWidgets('[501-10] Admin-only controls show for an admin and are hidden for a user',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final firestore = FakeFirebaseFirestore();
    final group = await seedGroup(firestore, 'bali', {
      'me-uid': memberData('You', 'admin'),
      'alex-uid': memberData('Alex Chen', 'user'),
    });

    // ── Admin ──
    final me =
        await seedService(firestore, uid: 'me-uid', email: 'me@syncinary.app', username: 'You');
    await pumpPage(tester, GroupDetailPage(group: group, service: me));
    expect(find.text('Group User Status: Admin'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget); // rename
    expect(find.text('Remove'), findsOneWidget); // on Alex's row, not your own
    expect(find.text('Delete Trip?'), findsOneWidget);
    expect(find.text('Transfer Admin Status'), findsOneWidget);
    await tester.tap(find.text('Bali Trip 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Rename Group'), findsOneWidget);

    // ── User ──
    final alex = await seedService(firestore,
        uid: 'alex-uid', email: 'alex@syncinary.app', username: 'Alex');
    await pumpPage(tester, GroupDetailPage(group: group, service: alex));
    expect(find.text('Group User Status: User'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.text('Remove'), findsNothing);
    expect(find.text('Delete Trip?'), findsNothing);
    expect(find.text('Transfer Admin Status'), findsNothing);
    await tester.tap(find.text('Bali Trip 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Rename Group'), findsNothing);
  });

  // ── 401-6: invite flow end to end ──

  testWidgets('[401-6] Invite by email, then accept or decline from Join Group', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final firestore = FakeFirebaseFirestore();
    final admin = await seedService(firestore,
        uid: 'admin-uid', email: 'admin@syncinary.app', username: 'Admin');
    final invitee = await seedService(firestore,
        uid: 'invitee-uid', email: 'invitee@syncinary.app', username: 'Invitee');
    final decliner = await seedService(firestore,
        uid: 'decliner-uid', email: 'decliner@syncinary.app', username: 'Decliner');
    final group = await admin.createGroup('Road Trip');

    Future<void> inviteFromGroupPage(String email) async {
      await pumpPage(tester, GroupDetailPage(group: group, service: admin));
      await tester.tap(find.text('Invite Members'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Add User by Email'), email);
      await tester.tap(find.text('Send Invite'));
      await tester.pumpAndSettle();
    }

    // ── Unregistered email is rejected and no invite is written ──
    await inviteFromGroupPage('nobody@nowhere.com');
    expect(find.text('No Syncinary account found for that email.'), findsOneWidget);
    expect((await firestore.collection('invites').get()).docs, isEmpty);

    // ── Invite → the invitee sees it → accepts → appears in the member list ──
    await inviteFromGroupPage('invitee@syncinary.app');
    await letOverlayDismiss(tester);
    await pumpPage(tester, JoinGroupPage(service: invitee));
    expect(find.text('Admin — Road Trip'), findsOneWidget);
    await tester.tap(find.byTooltip('Accept'));
    await tester.pumpAndSettle();
    expect(find.text('No pending invites.'), findsOneWidget);

    await pumpPage(tester, GroupDetailPage(group: group, service: admin));
    expect(find.text('Invitee'), findsOneWidget);

    // ── Invite → decline → the invite is gone and they never join ──
    await inviteFromGroupPage('decliner@syncinary.app');
    await letOverlayDismiss(tester);
    await pumpPage(tester, JoinGroupPage(service: decliner));
    expect(find.text('Admin — Road Trip'), findsOneWidget);
    await tester.tap(find.byTooltip('Decline'));
    await tester.pumpAndSettle();
    expect(find.text('No pending invites.'), findsOneWidget);
    expect((await firestore.collection('invites').get()).docs, isEmpty);

    await pumpPage(tester, GroupDetailPage(group: group, service: admin));
    expect(find.text('Invitee'), findsOneWidget);
    expect(find.text('Decliner'), findsNothing);
  });
}

/// Shows [page] as a fresh app. The new key matters: reusing the same
/// [MaterialApp] would keep the previous page, since `home` only builds once.
Future<void> pumpPage(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(MaterialApp(key: UniqueKey(), theme: buildAppTheme(), home: page));
  await tester.pumpAndSettle();
}

Map<String, dynamic> memberData(String username, String role) => {
      'username': username,
      'email': '${username.split(' ').first.toLowerCase()}@syncinary.app',
      'role': role,
    };

Future<Group> seedGroup(
    FakeFirebaseFirestore firestore, String id, Map<String, Map<String, dynamic>> members) async {
  final ref = firestore.collection('groups').doc(id);
  await ref.set({
    'name': 'Bali Trip 2026',
    'inviteCode': 'BALI26',
    'memberIds': members.keys.toList(),
    'members': members,
  });
  return Group.fromDoc(await ref.get());
}

Future<Map<String, String>> rolesOf(FakeFirebaseFirestore firestore, String groupId) async {
  final members =
      (await firestore.collection('groups').doc(groupId).get()).data()!['members'] as Map;
  return {for (final e in members.entries) e.key as String: e.value['role'] as String};
}

Future<Iterable<String>> membersOf(FakeFirebaseFirestore firestore, String groupId) async =>
    (await rolesOf(firestore, groupId)).keys;
