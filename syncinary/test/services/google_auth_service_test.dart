import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/services/google_auth_service.dart';

import '../helpers/popup_auth.dart';
import '../helpers/wrapping_transaction_firestore.dart';

void main() {
  late FakeFirebaseFirestore db;
  late PopupAuth auth;
  late GoogleAuthService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    auth = PopupAuth(
      mockUser: MockUser(
        uid: 'google-user',
        email: ' Traveler@Example.com ',
        displayName: '  Traveler  ',
        isEmailVerified: true,
      ),
    );
    service = GoogleAuthService(auth: auth, firestore: db);
  });

  test(
    '[303-2] Google popup creates a normalized profile under the Auth UID',
    () async {
      final user = await service.signIn();

      expect(user, auth.currentUser);
      expect(user!.emailVerified, isTrue);
      final provider = auth.providers.single as GoogleAuthProvider;
      expect(provider.providerId, 'google.com');
      expect(provider.parameters['prompt'], 'select_account');
      final profile = (await db.doc('users/google-user').get()).data()!;
      expect(profile['username'], 'Traveler');
      expect(profile['email'], 'traveler@example.com');
      expect(profile['createdAt'], isA<Timestamp>());
    },
  );

  test(
    '[303-1] returning or linked account keeps its profile and preferences',
    () async {
      final profile = {
        'username': 'My chosen name',
        'email': 'traveler@example.com',
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(1234),
        'preferences': {'budget': 750},
      };
      await db.doc('users/google-user').set(profile);

      await service.signIn();
      await auth.signOut();
      await service.signIn();

      final users = await db.collection('users').get();
      expect(users.docs, hasLength(1));
      expect(users.docs.single.id, 'google-user');
      expect(users.docs.single.data(), profile);
    },
  );

  test(
    '[303-2] missing Google display name falls back to email name',
    () async {
      auth = PopupAuth(
        mockUser: MockUser(
          uid: 'no-name',
          email: 'name@example.com',
          displayName: ' ',
        ),
      );
      await GoogleAuthService(auth: auth, firestore: db).signIn();
      expect((await db.doc('users/no-name').get()).data()!['username'], 'name');
    },
  );

  for (final code in ['popup-closed-by-user', 'cancelled-popup-request']) {
    test('[303-3] $code leaves auth and profiles untouched', () async {
      auth.popupError = FirebaseAuthException(code: code);
      expect(await service.signIn(), isNull);
      expect(auth.currentUser, isNull);
      expect((await db.collection('users').get()).docs, isEmpty);
    });
  }

  for (final code in [
    'account-exists-with-different-credential',
    'network-request-failed',
    'popup-blocked',
    'operation-not-allowed',
    'unauthorized-domain',
  ]) {
    test(
      '[303-3] $code propagates without creating a second account profile',
      () async {
        auth.popupError = FirebaseAuthException(code: code);
        await expectLater(
          service.signIn(),
          throwsA(
            isA<FirebaseAuthException>().having((e) => e.code, 'code', code),
          ),
        );
        expect(auth.currentUser, isNull);
        expect((await db.collection('users').get()).docs, isEmpty);
      },
    );
  }

  test(
    '[303-3] failed profile setup signs out and permits a later retry',
    () async {
      final failingDb = WrappingTransactionFirestore(
        commitError: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      );
      await expectLater(
        GoogleAuthService(auth: auth, firestore: failingDb).signIn(),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'profile-unavailable',
          ),
        ),
      );
      expect(auth.currentUser, isNull);
      expect(await service.signIn(), isNotNull);
      expect((await db.doc('users/google-user').get()).exists, isTrue);
    },
  );
}
