import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/pages/login_page.dart';
import 'package:syncinary/services/account_service.dart';
import 'package:syncinary/widgets/delete_account_dialog.dart';
import 'package:syncinary/widgets/settings_panel.dart';

import 'helpers/deletable_user.dart';
import 'helpers/wrapping_transaction_firestore.dart';

class _FailingDeletionService extends AccountService {
  _FailingDeletionService({required super.auth, required this.error});

  final Object error;

  @override
  Future<void> deleteAccount({
    required String password,
    required String expectedUserId,
  }) async {
    throw error;
  }
}

class RecordingAuth extends MockFirebaseAuth {
  RecordingAuth()
    : super(mockUser: MockUser(email: 'traveler@example.com'), signedIn: true);

  final completion = Completer<void>();
  final emails = <String>[];

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) {
    emails.add(email);
    return completion.future;
  }
}

void main() {
  testWidgets(
    '[301-7] reset sends to signed-in email and prevents duplicate taps',
    (tester) async {
      final auth = RecordingAuth();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPanel(service: AccountService(auth: auth)),
          ),
        ),
      );
      await tester.tap(find.text('Change password'));
      await tester.pump();
      await tester.tap(find.text('Change password'));
      expect(auth.emails, ['traveler@example.com']);
      auth.completion.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('Password reset email sent.'), findsOneWidget);
    },
  );

  testWidgets('[301-7] reset failure shows an error and permits retry', (
    tester,
  ) async {
    final auth = RecordingAuth();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPanel(service: AccountService(auth: auth)),
        ),
      ),
    );
    await tester.tap(find.text('Change password'));
    await tester.pump();
    auth.completion.completeError(
      FirebaseAuthException(code: 'network-request-failed'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Check your internet connection and try again.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'Change password'))
          .onTap,
      isNotNull,
    );
  });

  group('Permanent account deletion', () {
    late DeletableUser user;
    late MockFirebaseAuth auth;
    late FakeFirebaseFirestore db;
    late AccountService service;

    setUp(() async {
      user = DeletableUser();
      auth = MockFirebaseAuth(mockUser: user, signedIn: true);
      user.onDelete = auth.signOut;
      db = FakeFirebaseFirestore();
      service = AccountService(auth: auth, firestore: db);
      await db.collection('users').doc(user.uid).set({'email': user.email});
    });

    Future<void> openDeletion(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: [SettingsButton(service: service)]),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
    }

    Future<void> confirm(WidgetTester tester) async {
      await tester.enterText(find.byType(TextFormField), 'password123');
      await tester.tap(find.byKey(const Key('delete_account_confirm')));
      await tester.pumpAndSettle();
    }

    for (final failure in {
      'permission-denied': 'Account deletion is blocked by access permissions.',
      'unavailable': 'The account data service could not be reached.',
      'deadline-exceeded': 'The account data service could not be reached.',
      'unauthenticated': 'Your session expired.',
      'failed-precondition':
          'Account deletion requires a server configuration update.',
      'resource-exhausted': 'The account data service has reached its limit.',
      'unknown': 'Could not remove your account data.',
    }.entries) {
      testWidgets(
        '[301-12] ${failure.key} shows its cause and keeps the account',
        (tester) async {
          service = _FailingDeletionService(
            auth: auth,
            error: FirebaseException(
              plugin: 'cloud_firestore',
              code: failure.key,
            ),
          );
          await openDeletion(tester);
          await confirm(tester);

          expect(find.textContaining(failure.value), findsOneWidget);
          expect(
            find.text(
              'Could not delete your account. Check your connection and try again.',
            ),
            findsNothing,
          );
          expect(auth.currentUser, user);
          expect(user.deleteCalls, 0);
          expect(
            (await db.collection('users').doc(user.uid).get()).exists,
            isTrue,
          );
          expect(
            tester
                .widget<TextButton>(
                  find.byKey(const Key('delete_account_confirm')),
                )
                .onPressed,
            isNotNull,
          );
        },
      );
    }

    testWidgets(
      '[301-12] unexpected failures are not mislabeled as connection errors',
      (tester) async {
        service = _FailingDeletionService(
          auth: auth,
          error: StateError('test failure'),
        );
        await openDeletion(tester);
        await confirm(tester);

        expect(
          find.textContaining('because of an unexpected error.'),
          findsOneWidget,
        );
        expect(find.textContaining('Check your connection'), findsNothing);
        expect(user.deleteCalls, 0);
      },
    );

    testWidgets('[301-12] cancel and empty password never delete the account', (
      tester,
    ) async {
      await openDeletion(tester);
      expect(find.textContaining('This cannot be undone.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete_account_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Enter your current password.'), findsOneWidget);
      expect(user.credentials, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(DeleteAccountDialog), findsNothing);
      expect(find.byType(SettingsPanel), findsOneWidget);
      expect(user.deleteCalls, 0);
      expect((await db.collection('users').doc(user.uid).get()).exists, isTrue);
    });

    testWidgets('[301-12] wrong password shows a retryable error', (
      tester,
    ) async {
      user.reauthenticationError = FirebaseAuthException(
        code: 'wrong-password',
      );
      await openDeletion(tester);
      await confirm(tester);
      expect(
        find.text('Incorrect password. Please try again.'),
        findsOneWidget,
      );
      expect(user.deleteCalls, 0);
      user.reauthenticationError = null;
      await confirm(tester);
      expect(user.deleteCalls, 1);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(auth.currentUser, isNull);
    });

    testWidgets(
      '[301-12] pending deletion blocks duplicate taps, cancel and Back',
      (tester) async {
        final pending = Completer<void>();
        user.onDelete = () async {
          await pending.future;
          await auth.signOut();
        };
        await openDeletion(tester);
        await tester.enterText(find.byType(TextFormField), 'password123');
        final button = find.byKey(const Key('delete_account_confirm'));
        await tester.tap(button);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(button);
        expect(tester.widget<TextButton>(button).onPressed, isNull);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
              .onPressed,
          isNull,
        );
        expect(find.text('Deleting account...'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(DeleteAccountDialog), findsOneWidget);
        pending.complete();
        await tester.pumpAndSettle();
        expect(user.deleteCalls, 1);
        expect(find.byType(LoginPage), findsOneWidget);
      },
    );

    testWidgets(
      '[301-12] deletion removes nested pages and settings from navigation',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          actions: [SettingsButton(service: service)],
                        ),
                        body: const Text('Private trip'),
                      ),
                    ),
                  ),
                  child: const Text('Open trip'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open trip'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete account'));
        await tester.pumpAndSettle();
        await confirm(tester);

        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.text('Private trip', skipOffstage: false), findsNothing);
        expect(find.text('Open trip', skipOffstage: false), findsNothing);
        expect(find.byType(SettingsPanel, skipOffstage: false), findsNothing);
        expect(
          Navigator.of(tester.element(find.byType(LoginPage))).canPop(),
          isFalse,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '[301-12] switching accounts while confirmation is open blocks deletion',
      (tester) async {
        await openDeletion(tester);
        auth.mockUser = MockUser(uid: 'other', email: 'other@example.com');
        await confirm(tester);
        expect(
          find.textContaining('Your account session changed.'),
          findsOneWidget,
        );
        expect(user.credentials, isEmpty);
        expect(user.deleteCalls, 0);
        expect(
          (await db.collection('users').doc(user.uid).get()).exists,
          isTrue,
        );
      },
    );

    testWidgets('[301-12] group admin warning preserves the account', (
      tester,
    ) async {
      db = WrappingTransactionFirestore();
      service = AccountService(auth: auth, firestore: db);
      await db.doc('users/${user.uid}').set({'email': user.email});
      await db.collection('groups').doc('trip').set({
        'memberIds': [user.uid],
        'members': {
          user.uid: {'role': 'admin'},
        },
      });
      await openDeletion(tester);
      await confirm(tester);

      expect(
        find.textContaining('You are the only admin or member'),
        findsOneWidget,
      );
      expect(user.deleteCalls, 0);
      expect(auth.currentUser, user);
      expect((await db.collection('users').doc(user.uid).get()).exists, isTrue);
      expect(find.byType(DeleteAccountDialog), findsOneWidget);
    });

    testWidgets(
      '[301-12] incomplete deletion explains removed data and permits retry',
      (tester) async {
        user.onDelete = () async {
          throw FirebaseAuthException(code: 'network-request-failed');
        };
        await openDeletion(tester);
        await confirm(tester);

        expect(
          find.textContaining(
            'Your profile, invitations and memberships were removed',
          ),
          findsOneWidget,
        );
        expect(find.byType(LoginPage), findsNothing);
        expect(auth.currentUser, user);
        user.onDelete = auth.signOut;
        await confirm(tester);
        expect(user.deleteCalls, 2);
        expect(find.byType(LoginPage), findsOneWidget);
      },
    );
  });
}
