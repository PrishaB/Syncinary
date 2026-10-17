import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/models/user_preferences.dart';
import 'package:syncinary/pages/user_preferences_page.dart';
import 'package:syncinary/services/user_preferences_service.dart';
import 'package:syncinary/theme/app_theme.dart';

// Keep real persistence and account checks, while controlling request timing
// and failures without network calls or timers.
class _ControlledService extends UserPreferencesService {
  _ControlledService({required super.firestore, required super.auth});

  Completer<UserPreferences>? pendingLoad;
  Completer<void>? pendingSave;
  Object? loadError;
  Object? saveError;
  int saveCalls = 0;

  @override
  Future<UserPreferences> load() async {
    if (loadError != null) throw loadError!;
    if (pendingLoad != null) return pendingLoad!.future;
    return super.load();
  }

  @override
  Future<void> save(
    UserPreferences preferences, {
    required String expectedUserId,
  }) async {
    saveCalls++;
    if (saveError != null) throw saveError!;
    if (pendingSave != null) await pendingSave!.future;
    await super.save(preferences, expectedUserId: expectedUserId);
  }
}

class _SessionAuth extends Fake implements FirebaseAuth {
  @override
  User? currentUser = MockUser(uid: 'traveler');
}

final _budget = find.byKey(const ValueKey('preference_budgetPerPersonUsd'));
final _save = find.byKey(const Key('save_preferences'));

Future<void> _open(WidgetTester tester, UserPreferencesService service) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: UserPreferencesPage(service: service),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enterBudget(WidgetTester tester, String text) async {
  await tester.ensureVisible(_budget);
  await tester.enterText(_budget, text);
}

void _expectFilter(WidgetTester tester, String label, bool selected) {
  expect(
    tester.widget<FilterChip>(find.widgetWithText(FilterChip, label)).selected,
    selected,
  );
}

void _expectChoice(WidgetTester tester, String label, bool selected) {
  expect(
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected,
    selected,
  );
}

void main() {
  late FakeFirebaseFirestore database;
  late _SessionAuth auth;
  late _ControlledService service;

  setUp(() {
    database = FakeFirebaseFirestore();
    auth = _SessionAuth();
    service = _ControlledService(firestore: database, auth: auth);
  });

  Future<Map<String, dynamic>?> storedUser([String uid = 'traveler']) async =>
      (await database.collection('users').doc(uid).get()).data();

  testWidgets('[402-4] new account starts with optional empty preferences', (
    tester,
  ) async {
    await _open(tester, service);

    expect(find.text('Set Preferences'), findsOneWidget);
    expect(find.text('Your travel preferences'), findsOneWidget);
    expect(tester.widget<TextFormField>(_budget).controller!.text, isEmpty);
    for (final chip in tester.widgetList<FilterChip>(find.byType(FilterChip))) {
      expect(chip.selected, isFalse);
    }
    _expectChoice(tester, 'No preference', true);
    for (final label in ['Relaxed', 'Balanced', 'Busy']) {
      _expectChoice(tester, label, false);
    }
    expect(await storedUser(), isNull);

    await _tap(tester, _save);
    expect(find.text('Preferences saved.'), findsOneWidget);
    expect((await storedUser())!['preferences'], {
      'budgetPerPersonUsd': null,
      'activities': <String>[],
      'dietaryNeeds': <String>[],
      'tripPace': null,
    });
  });

  testWidgets('[402-5] selections save to the account and reload on reopen', (
    tester,
  ) async {
    await database.collection('users').doc('traveler').set({
      'username': 'Traveler',
      'email': 'traveler@example.com',
      'preferences': {'customPreference': 'keep me'},
    });
    final otherUser = {
      'username': 'Other',
      'preferences': {
        'activities': ['Shopping'],
      },
    };
    await database.collection('users').doc('other').set(otherUser);
    await _open(tester, service);
    await _enterBudget(tester, ' 1250.50 ');
    for (final label in [
      'Hiking',
      'Beaches',
      'Vegan',
      'Nut-free',
      'Balanced',
    ]) {
      await _tap(tester, find.text(label));
    }
    await _tap(tester, _save);

    expect(find.text('Preferences saved.'), findsOneWidget);
    expect(await storedUser(), {
      'username': 'Traveler',
      'email': 'traveler@example.com',
      'preferences': {
        'customPreference': 'keep me',
        'budgetPerPersonUsd': 1250.5,
        'activities': ['Hiking', 'Beaches'],
        'dietaryNeeds': ['Vegan', 'Nut-free'],
        'tripPace': 'Balanced',
      },
    });
    expect(await storedUser('other'), otherUser);

    await tester.pumpWidget(const SizedBox.shrink());
    await _open(
      tester,
      UserPreferencesService(firestore: database, auth: auth),
    );
    expect(tester.widget<TextFormField>(_budget).controller!.text, '1250.5');
    for (final label in ['Hiking', 'Beaches', 'Vegan', 'Nut-free']) {
      _expectFilter(tester, label, true);
    }
    _expectChoice(tester, 'Balanced', true);
    _expectChoice(tester, 'No preference', false);
  });

  testWidgets(
    '[402-6] choices toggle independently and saved values can clear',
    (tester) async {
      await database.collection('users').doc('traveler').set({
        'preferences': {
          'budgetPerPersonUsd': 500,
          'activities': ['Hiking', 'Beaches'],
          'dietaryNeeds': ['Vegan'],
          'tripPace': 'Relaxed',
        },
      });
      await _open(tester, service);
      await _tap(tester, find.text('Hiking'));
      _expectFilter(tester, 'Hiking', false);
      _expectFilter(tester, 'Beaches', true);
      _expectFilter(tester, 'Vegan', true);
      await _tap(tester, find.text('Busy'));
      _expectChoice(tester, 'Busy', true);
      _expectChoice(tester, 'Relaxed', false);
      _expectChoice(tester, 'No preference', false);
      await _tap(tester, find.text('No preference'));
      _expectChoice(tester, 'Busy', false);
      _expectChoice(tester, 'No preference', true);

      await _enterBudget(tester, '');
      await _tap(tester, find.text('Beaches'));
      await _tap(tester, find.text('Vegan'));
      await _tap(tester, _save);
      expect((await storedUser())!['preferences'], {
        'budgetPerPersonUsd': null,
        'activities': <String>[],
        'dietaryNeeds': <String>[],
        'tripPace': null,
      });
    },
  );

  testWidgets('[402-7] saved choices outside the catalog remain editable', (
    tester,
  ) async {
    await database.collection('users').doc('traveler').set({
      'preferences': {
        'activities': ['Stargazing'],
        'dietaryNeeds': ['Low sodium'],
        'tripPace': 'Flexible',
      },
    });
    await _open(tester, service);
    _expectFilter(tester, 'Stargazing', true);
    _expectFilter(tester, 'Low sodium', true);
    _expectChoice(tester, 'Flexible', true);
    await _tap(tester, _save);
    expect((await storedUser())!['preferences'], {
      'budgetPerPersonUsd': null,
      'activities': ['Stargazing'],
      'dietaryNeeds': ['Low sodium'],
      'tripPace': 'Flexible',
    });
    await _tap(tester, find.text('Stargazing'));
    await _tap(tester, find.text('Low sodium'));
    await _tap(tester, find.text('Relaxed'));
    await _tap(tester, _save);
    expect((await storedUser())!['preferences'], {
      'budgetPerPersonUsd': null,
      'activities': <String>[],
      'dietaryNeeds': <String>[],
      'tripPace': 'Relaxed',
    });
  });

  for (final invalid in ['-1', 'abc', 'NaN', 'Infinity', '1e309']) {
    testWidgets('[402-8] invalid budget "$invalid" blocks saving', (
      tester,
    ) async {
      await _open(tester, service);
      await _enterBudget(tester, invalid);
      await _tap(tester, _save);

      expect(find.text('Enter a valid amount of 0 or more.'), findsOneWidget);
      expect(
        find.text('Check the highlighted fields before saving.'),
        findsOneWidget,
      );
      expect(service.saveCalls, 0);
      expect(await storedUser(), isNull);
      expect(find.text('Preferences saved.'), findsNothing);

      await _enterBudget(tester, '0');
      await _tap(tester, _save);
      expect(service.saveCalls, 1);
      expect((await storedUser())!['preferences']['budgetPerPersonUsd'], 0);
      expect(find.text('Enter a valid amount of 0 or more.'), findsNothing);
      expect(
        find.text('Check the highlighted fields before saving.'),
        findsNothing,
      );
      expect(find.text('Preferences saved.'), findsOneWidget);
    });
  }

  testWidgets('[402-9] loading hides the form until preferences arrive', (
    tester,
  ) async {
    service.pendingLoad = Completer<UserPreferences>();
    await tester.pumpWidget(
      MaterialApp(home: UserPreferencesPage(service: service)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Form), findsNothing);
    expect(_save, findsNothing);

    service.pendingLoad!.complete(
      UserPreferences.fromMap({
        'activities': ['Hiking'],
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    _expectFilter(tester, 'Hiking', true);
  });

  testWidgets('[402-9] load failure offers retry and restores saved values', (
    tester,
  ) async {
    await database.collection('users').doc('traveler').set({
      'preferences': {'budgetPerPersonUsd': 750},
    });
    service.loadError = StateError('offline');
    await _open(tester, service);
    expect(
      find.text('Could not load your preferences. Please retry.'),
      findsOneWidget,
    );
    expect(find.byType(Form), findsNothing);
    service.loadError = null;
    await _tap(tester, find.text('Retry'));
    expect(tester.widget<TextFormField>(_budget).controller!.text, '750');
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('[402-10] saving disables edits and duplicate submissions', (
    tester,
  ) async {
    await _open(tester, service);
    await _enterBudget(tester, '300');
    await _tap(tester, find.text('Hiking'));
    service.pendingSave = Completer<void>();
    await tester.ensureVisible(_save);
    await tester.tap(_save);
    await tester.pump();

    expect(service.saveCalls, 1);
    expect(tester.widget<GradientButton>(_save).onPressed, isNull);
    expect(tester.widget<GradientButton>(_save).isLoading, isTrue);
    expect(tester.widget<TextFormField>(_budget).enabled, isFalse);
    for (final chip in tester.widgetList<FilterChip>(find.byType(FilterChip))) {
      expect(chip.onSelected, isNull);
    }
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      expect(chip.onSelected, isNull);
    }
    await tester.tap(_save);
    await tester.pump();
    expect(service.saveCalls, 1);
    expect(await storedUser(), isNull);
    expect(find.text('Preferences saved.'), findsNothing);

    service.pendingSave!.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<GradientButton>(_save).onPressed, isNotNull);
    expect(tester.widget<TextFormField>(_budget).enabled, isTrue);
    expect((await storedUser())!['preferences']['activities'], ['Hiking']);
    expect(find.text('Preferences saved.'), findsOneWidget);
  });

  testWidgets('[402-10] save failure retains edits and allows retry', (
    tester,
  ) async {
    await _open(tester, service);
    await _enterBudget(tester, '450.25');
    await _tap(tester, find.text('Beaches'));
    await _tap(tester, find.text('Halal'));
    await _tap(tester, find.text('Busy'));
    service.saveError = StateError('offline');
    await _tap(tester, _save);
    expect(
      find.text(
        'Could not save your preferences. Your edits are still here. '
        'Please try again.',
      ),
      findsOneWidget,
    );
    expect(await storedUser(), isNull);
    expect(find.text('Preferences saved.'), findsNothing);
    expect(tester.widget<TextFormField>(_budget).controller!.text, '450.25');
    _expectFilter(tester, 'Beaches', true);
    _expectFilter(tester, 'Halal', true);
    _expectChoice(tester, 'Busy', true);
    service.saveError = null;
    await _tap(tester, _save);
    expect(service.saveCalls, 2);
    expect(
      find.textContaining('Could not save your preferences.'),
      findsNothing,
    );
    expect(find.text('Preferences saved.'), findsOneWidget);
    expect((await storedUser())!['preferences'], {
      'budgetPerPersonUsd': 450.25,
      'activities': ['Beaches'],
      'dietaryNeeds': ['Halal'],
      'tripPace': 'Busy',
    });
  });

  testWidgets('[502-6] signed-out user cannot load the preferences form', (
    tester,
  ) async {
    auth.currentUser = null;
    await _open(tester, service);
    expect(
      find.text('Please sign in again to load your preferences.'),
      findsOneWidget,
    );
    expect(find.byType(Form), findsNothing);
    expect(_save, findsNothing);
    expect(await storedUser(), isNull);
  });

  testWidgets('[502-6] account change during loading hides stale preferences', (
    tester,
  ) async {
    service.pendingLoad = Completer<UserPreferences>();
    await tester.pumpWidget(
      MaterialApp(home: UserPreferencesPage(service: service)),
    );
    auth.currentUser = MockUser(uid: 'other');
    service.pendingLoad!.complete(
      UserPreferences.fromMap({
        'activities': ['Hiking'],
      }),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Please sign in again to load your preferences.'),
      findsOneWidget,
    );
    expect(find.byType(Form), findsNothing);
    expect(find.text('Hiking'), findsNothing);

    service.pendingLoad = null;
    await _tap(tester, find.text('Retry'));
    _expectFilter(tester, 'Hiking', false);
  });

  for (final signOut in [true, false]) {
    testWidgets(
      '[502-6] ${signOut ? 'sign-out' : 'account switch'} blocks draft saving',
      (tester) async {
        final originalUser = {
          'preferences': {'budgetPerPersonUsd': 100},
        };
        final otherUser = {
          'preferences': {'budgetPerPersonUsd': 200},
        };
        await database.collection('users').doc('traveler').set(originalUser);
        await database.collection('users').doc('other').set(otherUser);
        await _open(tester, service);
        await _enterBudget(tester, '999');
        auth.currentUser = signOut ? null : MockUser(uid: 'other');
        await _tap(tester, _save);

        expect(
          find.text('Your sign-in changed. Reopen this screen before saving.'),
          findsOneWidget,
        );
        expect(find.text('Preferences saved.'), findsNothing);
        expect(await storedUser(), originalUser);
        expect(await storedUser('other'), otherUser);
        expect(tester.widget<TextFormField>(_budget).controller!.text, '999');
      },
    );
  }
}
