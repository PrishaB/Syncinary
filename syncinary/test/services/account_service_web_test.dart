@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/services/account_service.dart';

import '../helpers/deletable_user.dart';

class _PromiseFirestore extends FakeFirebaseFirestore {
  Object? bridgeError;

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    late T result;
    Future<JSAny?> callback() async {
      result = await super.runTransaction(transactionHandler);
      return null;
    }

    try {
      // Match FlutterFire's Dart Future -> JavaScript Promise -> Dart bridge.
      // A callback exception is boxed in a real JS Error by the Dart runtime.
      await callback().toJS.toDart;
    } catch (error) {
      bridgeError = error;
      rethrow;
    }
    return result;
  }
}

void main() {
  test(
    '[301-12] browser Promise wrapper preserves the only-member warning',
    () async {
      final db = _PromiseFirestore();
      final user = DeletableUser();
      final auth = MockFirebaseAuth(mockUser: user, signedIn: true);
      final service = AccountService(auth: auth, firestore: db);
      await db.doc('users/${user.uid}').set({'email': user.email});
      await db.doc('groups/solo').set({
        'memberIds': [user.uid],
        'members': {
          user.uid: {'role': 'admin'},
        },
      });

      await expectLater(
        service.deleteAccount(
          password: 'password123',
          expectedUserId: user.uid,
        ),
        throwsA(
          isA<FirebaseAuthException>().having(
            (error) => error.code,
            'code',
            'group-admin-required',
          ),
        ),
      );

      expect(db.bridgeError, isNotNull);
      expect(db.bridgeError, isNot(isA<FirebaseAuthException>()));
      expect((await db.doc('users/${user.uid}').get()).exists, isTrue);
      expect((await db.doc('groups/solo').get()).data()!['memberIds'], [
        user.uid,
      ]);
      expect(user.deleteCalls, 0);
      expect(auth.currentUser, user);
    },
  );
}
