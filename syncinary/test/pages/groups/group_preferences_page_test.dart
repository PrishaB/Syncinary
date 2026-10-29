import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/models/group.dart';
import 'package:syncinary/models/group_preferences_summary.dart';
import 'package:syncinary/models/user_preferences.dart';
import 'package:syncinary/pages/groups/group_preferences_page.dart';
import 'package:syncinary/pages/schedule_builder_page.dart';
import 'package:syncinary/services/group_preferences_service.dart';
import 'package:syncinary/services/schedule_service.dart';
import 'package:syncinary/theme/app_theme.dart';

class _Fixture {
  _Fixture({String uid = 'alice', bool verified = true, bool signedIn = true})
    : auth = MockFirebaseAuth(
        mockUser: MockUser(uid: uid, isEmailVerified: verified),
        signedIn: signedIn,
      );

  final db = FakeFirebaseFirestore();
  final MockFirebaseAuth auth;
  GroupPreferencesService get service =>
      GroupPreferencesService(firestore: db, auth: auth);

  Future<Group> seed({bool preferences = true}) async {
    await db.collection('groups').doc('trip').set({
      'name': 'Summer trip',
      'memberIds': ['alice', 'bob', 'carol', 'dave'],
      'members': {
        for (final id in ['alice', 'bob', 'carol', 'dave'])
          id: {
            'username': '$id private name',
            'email': '$id@example.com',
            'role': id == 'bob' ? 'admin' : 'user',
          },
      },
    });
    if (preferences) {
      for (final id in ['alice', 'bob', 'carol']) {
        await db.collection('users').doc(id).set({
          'username': '$id private name',
          'email': '$id@example.com',
          'preferences': {
            'budgetPerPersonUsd': id == 'alice' ? 2000 : 500,
            'activities': [id == 'alice' ? 'Beaches' : 'Hiking'],
            'dietaryNeeds': ['Vegetarian'],
            'tripPace': id == 'alice' ? 'Relaxed' : 'Balanced',
            'notes': 'Private notes',
          },
        });
      }
    }
    // A non-member must never contribute, even if they have preferences.
    await db.collection('users').doc('outsider').set({
      'preferences': {'budgetPerPersonUsd': 999999, 'tripPace': 'Busy'},
    });
    return Group.fromDoc(await db.collection('groups').doc('trip').get());
  }

  Widget page() => MaterialApp(
    theme: buildAppTheme(),
    home: GroupPreferencesPage(
      groupId: 'trip',
      groupName: 'Summer trip',
      service: service,
    ),
  );
}

class _ControlledService extends GroupPreferencesService {
  _ControlledService()
    : super(firestore: FakeFirebaseFirestore(), auth: MockFirebaseAuth());

  final changes = StreamController<GroupPreferencesSummary?>();
  int subscriptions = 0;

  @override
  Stream<GroupPreferencesSummary?> watchSummary(String groupId) {
    subscriptions++;
    return subscriptions == 1
        ? changes.stream
        : Stream.value(GroupPreferencesSummary.fromPreferences([]));
  }
}

void main() {
  testWidgets('[502-1] members see aggregates without individual identities', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = _Fixture();
    await fixture.seed();
    await tester.pumpWidget(fixture.page());
    await tester.pumpAndSettle();

    expect(find.text('3 of 4 members have shared preferences'), findsOneWidget);
    expect(find.text('\$1000'), findsOneWidget);
    expect(find.text('2 of 3 (67%)'), findsNWidgets(2));
    expect(find.text('3 of 3 (100%)'), findsOneWidget);
    expect(find.text('Busy'), findsNothing);
    for (final id in ['alice', 'bob', 'carol', 'dave', 'outsider']) {
      expect(find.textContaining('$id private name'), findsNothing);
      expect(find.textContaining('$id@example.com'), findsNothing);
    }
    expect(find.text('Private notes'), findsNothing);
    expect(tester.takeException(), isNull);

    // Saved changes update the open summary without leaving the page.
    await fixture.db.collection('users').doc('alice').update({
      'preferences.budgetPerPersonUsd': 500,
    });
    await tester.pumpAndSettle();
    expect(find.text('\$500'), findsOneWidget);
    expect(find.text('\$1000'), findsNothing);
  });

  testWidgets(
    '[501-4] removed members stop contributing and losing access clears results',
    (tester) async {
      final fixture = _Fixture();
      await fixture.seed();
      await tester.pumpWidget(fixture.page());
      await tester.pumpAndSettle();
      final group = fixture.db.collection('groups').doc('trip');
      final data = (await group.get()).data()!;
      (data['members'] as Map).remove('carol');
      (data['memberIds'] as List).remove('carol');
      await group.set(data);
      await tester.pumpAndSettle();
      expect(
        find.text('2 of 3 members have shared preferences'),
        findsOneWidget,
      );
      expect(find.text('\$1000'), findsNothing);
      expect(find.text('Hiking'), findsNothing);

      (data['members'] as Map).remove('alice');
      (data['memberIds'] as List).remove('alice');
      await group.set(data);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Sign in with a verified account'),
        findsOneWidget,
      );
      expect(
        find.textContaining('members have shared preferences'),
        findsNothing,
      );
    },
  );

  testWidgets('[301-10] signing out clears a loaded summary', (tester) async {
    final fixture = _Fixture();
    await fixture.seed();
    await tester.pumpWidget(fixture.page());
    await tester.pumpAndSettle();
    await fixture.auth.signOut();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Sign in with a verified account'),
      findsOneWidget,
    );
    expect(find.text('\$1000'), findsNothing);
  });

  for (final mode in [
    'outsider',
    'unverified',
    'signed out',
    'deleted group',
  ]) {
    testWidgets('[502-3] $mode cannot view group preferences', (tester) async {
      final fixture = _Fixture(
        uid: mode == 'outsider' ? 'outsider' : 'alice',
        verified: mode != 'unverified',
        signedIn: mode != 'signed out',
      );
      await fixture.seed();
      if (mode == 'deleted group') {
        await fixture.db.collection('groups').doc('trip').delete();
      }
      await tester.pumpWidget(fixture.page());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Sign in with a verified account'),
        findsOneWidget,
      );
      expect(find.text('\$1000'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    '[502-2] planner opens the summary using the same session and backend',
    (tester) async {
      final fixture = _Fixture(uid: 'bob');
      final group = await fixture.seed();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ScheduleBuilderPage(
            group: group,
            service: ScheduleService(firestore: fixture.db, auth: fixture.auth),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Group Preferences'));
      await tester.pumpAndSettle();
      expect(find.byType(GroupPreferencesPage), findsOneWidget);
      expect(find.text('\$1000'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Schedule Builder'), findsOneWidget);
    },
  );

  testWidgets(
    '[N301-3] narrow screen and large text show all summary categories',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = _Fixture();
      await fixture.seed();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: GroupPreferencesPage(
            groupId: 'trip',
            groupName: 'Summer trip',
            service: fixture.service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Preferred trip pace'));
      await tester.pumpAndSettle();
      expect(find.text('Balanced'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('[502-1] empty preferences explain how members can contribute', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.seed(preferences: false);
    await tester.pumpWidget(fixture.page());
    await tester.pumpAndSettle();
    expect(find.text('0 of 4 members have shared preferences'), findsOneWidget);
    expect(find.textContaining('No preferences shared yet.'), findsOneWidget);
    expect(find.text('No responses yet.'), findsNWidgets(4));
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets(
    '[N-102-3] loading and read failures hide stale data and allow retry',
    (tester) async {
      final service = _ControlledService();
      addTearDown(service.changes.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: GroupPreferencesPage(
            groupId: 'trip',
            groupName: 'Summer trip',
            service: service,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      service.changes.add(
        GroupPreferencesSummary.fromPreferences([
          for (var i = 0; i < 3; i++)
            UserPreferences.fromMap({'budgetPerPersonUsd': 1000}),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('\$1000'), findsOneWidget);
      service.changes.addError(Exception('Private backend diagnostics'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not load group preferences. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('\$1000'), findsNothing);
      expect(find.textContaining('Private backend diagnostics'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(service.subscriptions, 2);
      expect(
        find.text('0 of 0 members have shared preferences'),
        findsOneWidget,
      );
    },
  );
}
