enum PreferenceInput { amount, multipleChoice, singleChoice }

/// One editable preference. IDs are persisted in Firestore, so keep them stable.
class PreferenceField {
  const PreferenceField({
    required this.id,
    required this.title,
    required this.description,
    required this.input,
    this.options = const [],
    this.amountLabel = 'Amount',
  });

  final String id;
  final String title;
  final String description;
  final PreferenceInput input;
  final List<String> options;
  final String amountLabel;

  Object? _readValue(Object? value) {
    switch (input) {
      case PreferenceInput.amount:
        return value is num && value.isFinite && value >= 0 ? value : null;
      case PreferenceInput.multipleChoice:
        return List<String>.unmodifiable(
          value is List
              ? value
                    .whereType<String>()
                    .where((item) => item.isNotEmpty)
                    .toSet()
              : <String>[],
        );
      case PreferenceInput.singleChoice:
        return value is String && value.isNotEmpty ? value : null;
    }
  }
}

/// Add a field here to include it in the form, loading, and saving automatically.
/// All fields are optional. Choice values are stored as strings; amount values
/// are non-negative numbers. Existing fields outside this list are left intact
/// by the service, allowing other features to keep their own preference data.
///
/// For example, append a `PreferenceField` with `id: 'accommodation'`,
/// `input: PreferenceInput.singleChoice`, a title and description, and
/// `options: ['Hotel', 'Hostel', 'Vacation rental']`. No page or service changes
/// are needed. Use `multipleChoice` for checkboxes and `amount` for numbers.
const userPreferenceFields = <PreferenceField>[
  PreferenceField(
    id: 'budgetPerPersonUsd',
    title: 'Travel budget',
    description:
        'Your maximum total trip budget per person in USD. '
        'Leave blank if you are still deciding.',
    input: PreferenceInput.amount,
    amountLabel: 'Budget per person (USD)',
  ),
  PreferenceField(
    id: 'activities',
    title: 'Interests',
    description: 'Choose the activities you enjoy. Select as many as you like.',
    input: PreferenceInput.multipleChoice,
    options: [
      'Hiking',
      'Beaches',
      'Museums & culture',
      'Food & dining',
      'Shopping',
      'Nightlife',
      'Wildlife',
      'Adventure',
    ],
  ),
  PreferenceField(
    id: 'dietaryNeeds',
    title: 'Dietary needs',
    description: 'Choose any that apply. Leave unselected if you have none.',
    input: PreferenceInput.multipleChoice,
    options: [
      'Vegetarian',
      'Vegan',
      'Gluten-free',
      'Dairy-free',
      'Halal',
      'Kosher',
      'Nut-free',
    ],
  ),
  PreferenceField(
    id: 'tripPace',
    title: 'Preferred trip pace',
    description: 'How full do you like your travel days to be?',
    input: PreferenceInput.singleChoice,
    options: ['Relaxed', 'Balanced', 'Busy'],
  ),
];

/// The editable fields within `users/{uid}.preferences`.
class UserPreferences {
  UserPreferences.fromMap(Map<String, dynamic>? data)
    : _values = Map.unmodifiable({
        for (final field in userPreferenceFields)
          field.id: field._readValue(data?[field.id]),
      });

  final Map<String, Object?> _values;

  Object? operator [](String id) => _values[id];

  Map<String, dynamic> toMap() => Map<String, dynamic>.from(_values);
}
