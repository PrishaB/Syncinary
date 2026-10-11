import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/services/group_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late GroupService service;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    service = GroupService(
      firestore: firestore,
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'joiner', email: 'joiner@example.com'),
      ),
    );
    await firestore.collection('groups').doc('trip').set({
      'name': 'Trip',
      'memberIds': ['admin'],
      'members': {
        'admin': {
          'username': 'Admin',
          'email': 'admin@example.com',
          'role': 'admin',
        },
      },
    });
    await firestore.collection('inviteCodes').doc('ABC123').set({
      'groupId': 'trip',
    });
  });

  for (final code in ['abc123', '  ABC123  ', '  abc123\n']) {
    test(
      '[501-6] joinByCode normalizes ${code.trim()} with ${code.length} characters',
      () async {
        expect(await service.joinByCode(code), isTrue);
        final data = (await firestore.collection('groups').doc('trip').get())
            .data()!;
        expect(data['memberIds'], unorderedEquals(['admin', 'joiner']));
        expect(data['members']['joiner']['role'], 'user');
        expect(data['members']['admin']['role'], 'admin');
      },
    );
  }

  for (final code in ['', ' \t\n', 'UNKNOWN']) {
    test(
      '[501-6] joinByCode rejects ${code.trim().isEmpty ? 'blank (${code.length})' : code} without mutation',
      () async {
        final ref = firestore.collection('groups').doc('trip');
        final before = (await ref.get()).data();
        expect(await service.joinByCode(code), isFalse);
        expect((await ref.get()).data(), before);
      },
    );
  }

  test('[501-6] Joining twice does not duplicate the member', () async {
    expect(await service.joinByCode('ABC123'), isTrue);
    final ref = firestore.collection('groups').doc('trip');
    final before = (await ref.get()).data();
    expect(await service.joinByCode('abc123'), isTrue);
    expect((await ref.get()).data(), before);
    expect(
      (await ref.get()).data()!['memberIds'],
      unorderedEquals(['admin', 'joiner']),
    );
  });
}
