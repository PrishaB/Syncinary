import 'user_preferences.dart';

/// Presentation aggregates only: no member identifiers or individual answers.
/// This is not a server-side privacy boundary; raw preferences remain in users.
class GroupPreferencesSummary {
  GroupPreferencesSummary._({
    required this.memberCount,
    required this.respondentCount,
    required this.fields,
  });

  static const minimumResponses = 3;

  final int memberCount;
  final int respondentCount;
  final List<PreferenceSummary> fields;

  factory GroupPreferencesSummary.fromPreferences(
    Iterable<UserPreferences> preferences,
  ) {
    final members = preferences.toList();
    final respondents = <int>{};
    final summaries = <PreferenceSummary>[];
    for (final field in userPreferenceFields) {
      var responses = 0;
      var average = 0.0;
      final counts = <String, int>{};
      for (var i = 0; i < members.length; i++) {
        final value = members[i][field.id];
        if (field.input == PreferenceInput.amount) {
          if (value is! num || !value.isFinite || value < 0) continue;
          responses++;
          // Running mean avoids overflowing a sum of otherwise valid amounts.
          average += (value.toDouble() - average) / responses;
        } else {
          final selected =
              (value is List<String>
                      ? value
                      : value is String
                      ? [value]
                      : <String>[])
                  .where(field.options.contains)
                  .toSet();
          if (selected.isEmpty) continue;
          responses++;
          for (final option in selected) {
            counts.update(option, (count) => count + 1, ifAbsent: () => 1);
          }
        }
        respondents.add(i);
      }
      final visible = responses >= minimumResponses;
      summaries.add(
        PreferenceSummary(
          field: field,
          responseCount: responses,
          average: visible && field.input == PreferenceInput.amount
              ? average
              : null,
          counts: Map.unmodifiable(visible ? counts : <String, int>{}),
        ),
      );
    }
    return GroupPreferencesSummary._(
      memberCount: members.length,
      respondentCount: respondents.length,
      fields: List.unmodifiable(summaries),
    );
  }
}

class PreferenceSummary {
  const PreferenceSummary({
    required this.field,
    required this.responseCount,
    required this.counts,
    this.average,
  });

  final PreferenceField field;
  final int responseCount;
  final Map<String, int> counts;
  final double? average;

  bool get isVisible =>
      responseCount >= GroupPreferencesSummary.minimumResponses;
}
