import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:syncinary/pages/groups/my_groups_page.dart';
import 'package:syncinary/pages/login_page.dart';
import 'package:syncinary/pages/signup_page.dart';
import 'package:syncinary/pages/verify_email_page.dart';
import 'package:syncinary/services/group_service.dart';
import 'package:syncinary/theme/app_theme.dart';

import 'helpers/popup_auth.dart';

void main() {
  late PopupAuth auth;
  late FakeFirebaseFirestore db;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Syncinary',
      packageName: 'syncinary',
      version: 'test',
      buildNumber: '1',
      buildSignature: '',
    );
    db = FakeFirebaseFirestore();
    auth = PopupAuth(
      mockUser: MockUser(
        uid: 'google-user',
        email: 'traveler@example.com',
        displayName: 'Traveler',
        isEmailVerified: true,
      ),
    );
  });

  Future<void> openPage(WidgetTester tester, bool signup) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final groups = GroupService(auth: auth, firestore: db);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: signup
            ? SignUpPage(auth: auth, firestore: db, groupService: groups)
            : LoginPage(auth: auth, firestore: db, groupService: groups),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final signup in [false, true]) {
    final page = signup ? 'Sign Up' : 'Sign In';
    testWidgets('[303-2] $page offers Google only on web', (tester) async {
      await openPage(tester, signup);
      expect(
        find.text('Continue with Google'),
        kIsWeb ? findsOneWidget : findsNothing,
      );
    });

    testWidgets(
      '[303-2] $page accepts Google with empty email/password fields',
      (tester) async {
        await openPage(tester, signup);
        await tester.tap(find.text('Continue with Google'));
        await tester.pumpAndSettle();
        expect(auth.providers, hasLength(1));
        expect(find.byType(MyGroupsPage), findsOneWidget);
        expect(find.byType(VerifyEmailPage), findsNothing);
        expect(
          (await db.doc('users/google-user').get()).data()!['email'],
          'traveler@example.com',
        );
        expect(tester.takeException(), isNull);
      },
      skip: !kIsWeb,
    );

    testWidgets('[303-3] $page cancellation enables retry without an error', (
      tester,
    ) async {
      auth.popupError = FirebaseAuthException(code: 'popup-closed-by-user');
      await openPage(tester, signup);
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(auth.currentUser, isNull);
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
      auth.popupError = null;
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.byType(MyGroupsPage), findsOneWidget);
    }, skip: !kIsWeb);

    final errors = {
      'popup-blocked': 'Allow popups for this site',
      'network-request-failed': 'Check your internet connection',
      'account-exists-with-different-credential':
          'Sign in with your existing sign-in method.',
      'operation-not-allowed': 'Please use email and password.',
      'unauthorized-domain': 'Please use email and password.',
    };
    for (final entry in errors.entries) {
      testWidgets('[303-3] $page explains ${entry.key} and stays on the form', (
        tester,
      ) async {
        auth.popupError = FirebaseAuthException(code: entry.key);
        await openPage(tester, signup);
        await tester.tap(find.text('Continue with Google'));
        await tester.pumpAndSettle();
        expect(find.textContaining(entry.value), findsOneWidget);
        expect(find.byType(signup ? SignUpPage : LoginPage), findsOneWidget);
        expect(auth.currentUser, isNull);
        expect((await db.collection('users').get()).docs, isEmpty);
      }, skip: !kIsWeb);
    }

    testWidgets(
      '[303-3] $page blocks repeated Google clicks and password submit while pending',
      (tester) async {
        final pending = Completer<void>();
        auth.beforePopup = () => pending.future;
        await openPage(tester, signup);
        await tester.tap(find.text('Continue with Google'));
        await tester.pump();
        await tester.tap(find.text('Continue with Google'));
        final passwordField = tester.widget<TextField>(
          find.byType(TextField).last,
        );
        passwordField.onSubmitted!('password123!');
        expect(auth.providers, hasLength(1));
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Continue with Google'),
              )
              .onPressed,
          isNull,
        );
        expect(find.text('Please enter your email'), findsNothing);
        pending.complete();
        await tester.pumpAndSettle();
        expect(find.byType(MyGroupsPage), findsOneWidget);
      },
      skip: !kIsWeb,
    );
  }
}
