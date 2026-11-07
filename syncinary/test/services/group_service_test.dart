import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syncinary/models/group.dart';
import 'package:syncinary/services/group_service.dart';

GroupService serviceAs(FakeFirebaseFirestore firestore, String uid) {
  final auth = MockFirebaseAuth(
    mockUser: MockUser(uid: uid, email: '$uid@syncinary.app', displayName: uid),
    signedIn: true,
  );
  return GroupService(firestore: firestore, auth: auth);
}

Map<String, dynamic> member(String uid, String role) =>
    {'username': uid, 'email': '$uid@syncinary.app', 'role': role};

/// Seeds `groups/trip` with [memberIds] in join order (the first is admin
/// unless [roles] says otherwise).
Future<void> seedGroup(
  FakeFirebaseFirestore firestore,
  List<String> memberIds, {
  Map<String, String> roles = const {},
}) {
  return firestore.collection('groups').doc('trip').set({
    'name': 'Trip',
    'inviteCode': 'TRIP01',
    'memberIds': memberIds,
    'members': {
      for (final (i, uid) in memberIds.indexed)
        uid: member(uid, roles[uid] ?? (i == 0 ? 'admin' : 'user')),
    },
  });
}

Future<Map<String, dynamic>?> readGroup(FakeFirebaseFirestore firestore) async =>
    (await firestore.collection('groups').doc('trip').get()).data();

Future<Group> loadGroup(FakeFirebaseFirestore firestore) async =>
    Group.fromDoc(await firestore.collection('groups').doc('trip').get());

String roleIn(Map<String, dynamic> data, String uid) =>
    (data['members'] as Map)[uid]['role'] as String;

void main() {
  test('[501-5] sole admin leaving promotes the longest-tenured member', () async {
    final firestore = FakeFirebaseFirestore();
    // Join order is a, then c, then b; deliberately not alphabetical.
    await seedGroup(firestore, ['a', 'c', 'b']);

    await serviceAs(firestore, 'a').leaveGroup(await loadGroup(firestore));

    final data = (await readGroup(firestore))!;
    expect(data['memberIds'], ['c', 'b']);
    expect(roleIn(data, 'c'), 'admin');
    expect(roleIn(data, 'b'), 'user');
  });

  test('[501-5] promotion follows join order after members have joined by code',
      () async {
    final firestore = FakeFirebaseFirestore();
    final admin = serviceAs(firestore, 'zed');
    final group = await admin.createGroup('Trip');
    final code = group.inviteCode!;

    await serviceAs(firestore, 'mia').joinByCode(code);
    await serviceAs(firestore, 'abe').joinByCode(code);

    await admin.leaveGroup(group);

    final data = (await firestore.collection('groups').doc(group.id).get()).data()!;
    expect(data['memberIds'], ['mia', 'abe']);
    expect(roleIn(data, 'mia'), 'admin');
    expect(roleIn(data, 'abe'), 'user');
  });

  test('[501-5] admin leaving when another admin remains promotes nobody', () async {
    final firestore = FakeFirebaseFirestore();
    await seedGroup(firestore, ['a', 'b', 'c'], roles: {'c': 'admin'});

    await serviceAs(firestore, 'a').leaveGroup(await loadGroup(firestore));

    final data = (await readGroup(firestore))!;
    expect(roleIn(data, 'b'), 'user');
    expect(roleIn(data, 'c'), 'admin');
  });

  test('[501-5] non-admin leaving changes no roles', () async {
    final firestore = FakeFirebaseFirestore();
    await seedGroup(firestore, ['a', 'b', 'c']);

    await serviceAs(firestore, 'b').leaveGroup(await loadGroup(firestore));

    final data = (await readGroup(firestore))!;
    expect(data['memberIds'], ['a', 'c']);
    expect(roleIn(data, 'a'), 'admin');
    expect(roleIn(data, 'c'), 'user');
  });

  test('[501-5] last member leaving deletes the group', () async {
    final firestore = FakeFirebaseFirestore();
    await seedGroup(firestore, ['a']);

    await serviceAs(firestore, 'a').leaveGroup(await loadGroup(firestore));

    expect(await readGroup(firestore), isNull);
  });

  test('[501-5] removing a member keeps the remaining join order', () async {
    final firestore = FakeFirebaseFirestore();
    await seedGroup(firestore, ['a', 'd', 'c', 'b']);

    final group = await loadGroup(firestore);
    await serviceAs(firestore, 'a')
        .removeMember(group, group.memberById('c')!);

    expect((await readGroup(firestore))!['memberIds'], ['a', 'd', 'b']);
  });
}
