import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/services/account_service.dart';
import 'package:syncinary/widgets/settings_panel.dart';

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
}
