import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/services/account_service.dart';

import '../helpers/deletable_user.dart';
import '../helpers/wrapping_transaction_firestore.dart';

class _UnavailableFirestore extends FakeFirebaseFirestore {
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
  }
}

Matcher authError(String code) =>
    isA<FirebaseAuthException>().having((error) => error.code, 'code', code);

void main() {
  late FakeFirebaseFirestore db;
  late DeletableUser user;
  late MockFirebaseAuth auth;
  late AccountService service;

  Future<void> delete() => service.deleteAccount(
    password: ' password123 ',
    expectedUserId: user.uid,
  );

  Future<void> seedGroup(String id, Map<String, dynamic> members) =>
      db.collection('groups').doc(id).set({
        'name': id,
        'memberIds': members.keys.toList(),
        'members': members,
        'inviteCode': 'ABC123',
      });

  setUp(() async {
    db = FakeFirebaseFirestore();
    user = DeletableUser();
    auth = MockFirebaseAuth(mockUser: user, signedIn: true);
    user.onDelete = auth.signOut;
    service = AccountService(auth: auth, firestore: db);
    await db.collection('users').doc(user.uid).set({
      'email': user.email,
      'preferences': {'budget': 100},
    });
    await db.collection('users').doc('other').set({'username': 'Other'});
    await db.collection('invites').doc('unrelated').set({'senderUid': 'other'});
  });

  test(
    '[301-12] deletion cleans owned data and preserves shared trip history',
    () async {
      await seedGroup('shared', {
        user.uid: {'role': 'user', 'email': user.email},
        'other': {'role': 'admin', 'username': 'Other'},
      });
      final expense = db.collection('groups/shared/expenses').doc('bill');
      await expense.set({'addedBy': user.uid, 'amount': 20});
      final invites = db.collection('invites');
      await invites.doc('sent').set({'senderUid': user.uid});
      await invites.doc('received').set({
        'senderUid': 'other',
        'recipientUid': user.uid,
        'recipientEmail': user.email,
      });
      await invites.doc('legacy').set({'recipientEmail': user.email});
      await invites.doc('self-invite').set({
        'senderUid': user.uid,
        'recipientUid': user.uid,
        'recipientEmail': user.email,
      });
      await invites.doc('unrelated').set({'senderUid': 'other'});
      user.onDelete = () async {
        // Firestore must be cleaned while the user is still authenticated.
        expect(
          (await db.collection('users').doc(user.uid).get()).exists,
          isFalse,
        );
        expect(auth.currentUser?.uid, user.uid);
        await auth.signOut();
      };

      await delete();

      expect(user.credentials.single.email, user.email);
      expect(user.credentials.single.password, ' password123 ');
      expect(user.deleteCalls, 1);
      expect(auth.currentUser, isNull);
      final group = (await db.collection('groups').doc('shared').get()).data()!;
      expect(group['memberIds'], ['other']);
      expect((group['members'] as Map).keys, ['other']);
      expect(group['inviteCode'], 'ABC123');
      expect((await expense.get()).data(), {'addedBy': user.uid, 'amount': 20});
      expect((await invites.get()).docs.map((doc) => doc.id), ['unrelated']);
      expect((await db.collection('users').doc('other').get()).exists, isTrue);
    },
  );

  test(
    '[301-12] incorrect password leaves every record and Auth intact',
    () async {
      user.reauthenticationError = FirebaseAuthException(
        code: 'wrong-password',
      );
      final before = db.dump();

      await expectLater(delete(), throwsA(authError('wrong-password')));

      expect(db.dump(), before);
      expect(user.deleteCalls, 0);
      expect(auth.currentUser, user);
    },
  );

  for (final alone in [true, false]) {
    test(
      '[301-12] ${alone ? 'last member' : 'sole admin'} cannot orphan a group',
      () async {
        await seedGroup('other-trip', {
          user.uid: {'role': 'user'},
          'other': {'role': 'admin'},
        });
        await seedGroup('managed', {
          user.uid: {'role': 'admin'},
          if (!alone) 'other': {'role': 'user'},
        });
        final before = db.dump();

        await expectLater(delete(), throwsA(authError('group-admin-required')));

        expect(db.dump(), before);
        expect(user.deleteCalls, 0);
        expect(auth.currentUser, user);
      },
    );
  }

  test('[301-12] an admin can delete once another admin remains', () async {
    await seedGroup('shared', {
      user.uid: {'role': 'admin'},
      'other': {'role': 'admin'},
    });

    await delete();

    expect(user.deleteCalls, 1);
    expect(
      (await db.collection('groups').doc('shared').get()).data()!['memberIds'],
      ['other'],
    );
  });

  test(
    '[301-12] signed-out deletion fails before authenticating or writing',
    () async {
      await auth.signOut();
      final before = db.dump();

      await expectLater(delete(), throwsA(authError('not-signed-in')));

      expect(db.dump(), before);
      expect(user.credentials, isEmpty);
      expect(user.deleteCalls, 0);
    },
  );

  test(
    '[301-12] account switch during password verification aborts cleanup',
    () async {
      user.onReauthenticate = () async {
        auth.mockUser = MockUser(uid: 'other', email: 'other@example.com');
      };
      final before = db.dump();

      await expectLater(delete(), throwsA(authError('user-changed')));

      expect(db.dump(), before);
      expect(user.deleteCalls, 0);
      expect(auth.currentUser?.uid, 'other');
    },
  );

  test(
    '[301-12] failed Auth deletion reports partial completion and can retry',
    () async {
      user.onDelete = () async {
        throw FirebaseAuthException(code: 'network-request-failed');
      };

      await expectLater(
        delete(),
        throwsA(authError('account-delete-incomplete')),
      );

      expect(auth.currentUser, user);
      expect(
        (await db.collection('users').doc(user.uid).get()).exists,
        isFalse,
      );
      user.onDelete = auth.signOut;
      await delete();
      expect(user.deleteCalls, 2);
      expect(auth.currentUser, isNull);
    },
  );

  test(
    '[301-12] Firestore cleanup failure never deletes the Auth account',
    () async {
      final messages = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) messages.add(message);
      };
      addTearDown(() => debugPrint = originalDebugPrint);
      final unavailableDb = _UnavailableFirestore();
      final profile = unavailableDb.collection('users').doc(user.uid);
      await profile.set({'email': user.email});
      service = AccountService(auth: auth, firestore: unavailableDb);

      await expectLater(delete(), throwsA(isA<FirebaseException>()));

      expect((await profile.get()).data(), {'email': user.email});
      expect(user.deleteCalls, 0);
      expect(auth.currentUser, user);
      expect(
        messages,
        contains(
          'Account deletion failed while removing account data: cloud_firestore/unavailable',
        ),
      );
      expect(messages.join(), isNot(contains(user.email!)));
      expect(messages.join(), isNot(contains('password123')));
    },
  );

  test(
    '[301-12] wrapped web callback preserves the only-member warning and data',
    () async {
      db = WrappingTransactionFirestore();
      service = AccountService(auth: auth, firestore: db);
      await db.doc('users/${user.uid}').set({'email': user.email});
      await db.doc('invites/received').set({'recipientEmail': user.email});
      await seedGroup('solo-trip', {
        user.uid: {'role': 'admin'},
      });
      final before = db.dump();

      await expectLater(delete(), throwsA(authError('group-admin-required')));

      expect(db.dump(), before);
      expect(user.deleteCalls, 0);
      expect(auth.currentUser, user);
    },
  );

  test(
    '[301-12] successful retry does not restore an earlier callback error',
    () async {
      db = WrappingTransactionFirestore(
        onRetry: () => seedGroup('shared', {
          user.uid: {'role': 'admin'},
          'other': {'role': 'admin'},
        }),
      );
      service = AccountService(auth: auth, firestore: db);
      await seedGroup('shared', {
        user.uid: {'role': 'admin'},
      });

      await delete();

      expect(user.deleteCalls, 1);
      expect(auth.currentUser, isNull);
    },
  );

  test(
    '[301-12] commit failure after retry keeps its own error code',
    () async {
      db = WrappingTransactionFirestore(
        onRetry: () => seedGroup('shared', {
          user.uid: {'role': 'admin'},
          'other': {'role': 'admin'},
        }),
        commitError: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      );
      service = AccountService(auth: auth, firestore: db);
      await seedGroup('shared', {
        user.uid: {'role': 'admin'},
      });

      await expectLater(
        delete(),
        throwsA(
          isA<FirebaseException>().having(
            (error) => error.code,
            'code',
            'permission-denied',
          ),
        ),
      );

      expect(user.deleteCalls, 0);
      expect(auth.currentUser, user);
    },
  );
}
