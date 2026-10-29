import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/models/group_preferences_summary.dart';
import 'package:syncinary/models/user_preferences.dart';

PreferenceSummary field(GroupPreferencesSummary summary, String id) =>
    summary.fields.singleWhere((entry) => entry.field.id == id);

void main() {
  test(
    '[502-1] aggregates each member once and excludes unanswered budgets',
    () {
      final summary = GroupPreferencesSummary.fromPreferences([
        UserPreferences.fromMap({
          'budgetPerPersonUsd': 0,
          'activities': ['Hiking', 'Hiking', 'Beaches'],
          'tripPace': 'Relaxed',
        }),
        UserPreferences.fromMap({
          'budgetPerPersonUsd': 1200,
          'activities': ['Hiking'],
          'tripPace': 'Balanced',
        }),
        UserPreferences.fromMap({
          'budgetPerPersonUsd': 1800,
          'activities': ['Beaches'],
          'tripPace': 'Balanced',
        }),
        UserPreferences.fromMap(null),
      ]);
      expect(summary.memberCount, 4);
      expect(summary.respondentCount, 3);
      expect(field(summary, 'budgetPerPersonUsd').average, 1000);
      expect(field(summary, 'budgetPerPersonUsd').responseCount, 3);
      expect(field(summary, 'activities').counts, {'Hiking': 2, 'Beaches': 2});
      expect(field(summary, 'activities').responseCount, 3);
      expect(field(summary, 'tripPace').counts, {'Relaxed': 1, 'Balanced': 2});
      expect(field(summary, 'dietaryNeeds').responseCount, 0);
    },
  );

  test('[502-1] hides categories with fewer than three valid responses', () {
    final summary = GroupPreferencesSummary.fromPreferences([
      UserPreferences.fromMap({'budgetPerPersonUsd': 10, 'tripPace': 'Busy'}),
      UserPreferences.fromMap({'budgetPerPersonUsd': 20, 'tripPace': 'Busy'}),
      UserPreferences.fromMap({'tripPace': 'Relaxed'}),
    ]);
    final budget = field(summary, 'budgetPerPersonUsd');
    expect(budget.responseCount, 2);
    expect(budget.isVisible, isFalse);
    expect(budget.average, isNull);
    expect(field(summary, 'tripPace').isVisible, isTrue);

    final one = GroupPreferencesSummary.fromPreferences([
      UserPreferences.fromMap({
        'activities': ['Hiking'],
      }),
    ]);
    expect(field(one, 'activities').counts, isEmpty);
  });

  test(
    '[502-1] ignores invalid amounts and unrecognized or identifying text',
    () {
      final summary = GroupPreferencesSummary.fromPreferences([
        for (final amount in [-1, double.nan, double.infinity, '500', null])
          UserPreferences.fromMap({
            'budgetPerPersonUsd': amount,
            'activities': ['private@example.com', 42, ''],
            'tripPace': 'Alice prefers quiet trips',
            'notes': 'Private notes',
          }),
      ]);
      expect(summary.respondentCount, 0);
      expect(summary.fields.every((entry) => entry.responseCount == 0), isTrue);
      expect(summary.fields.every((entry) => entry.counts.isEmpty), isTrue);
      expect(summary.fields.every((entry) => entry.average == null), isTrue);
    },
  );

  test(
    '[502-1] empty groups have an empty summary without invalid averages',
    () {
      final summary = GroupPreferencesSummary.fromPreferences([]);
      expect(summary.memberCount, 0);
      expect(summary.respondentCount, 0);
      expect(summary.fields.length, userPreferenceFields.length);
      expect(summary.fields.every((entry) => !entry.isVisible), isTrue);
    },
  );
}
