/// Data models for an FR-104 travel recommendation, mirroring
/// `proxy/recommendationPrompt.js`'s `RECOMMENDATION_OUTPUT_SCHEMA`. That
/// schema currently lives on the unmerged #43->#44->#45->#87->#91 branch
/// stack, not on `main` — keep these in sync if it changes before merge.
library;

class Cost {
  const Cost({required this.amount, required this.currency});

  final num amount;
  final String currency;

  factory Cost.fromJson(Map<String, dynamic> json) => Cost(
        amount: json['amount'] as num,
        currency: json['currency'] as String,
      );
}

class Destination {
  const Destination({
    required this.id,
    required this.name,
    required this.region,
    required this.rationale,
    required this.matchedPreferences,
    required this.estimatedCostPerPerson,
  });

  final String id;
  final String name;
  final String? region;
  final String rationale;
  final List<String> matchedPreferences;
  final Cost estimatedCostPerPerson;

  factory Destination.fromJson(Map<String, dynamic> json) => Destination(
        id: json['id'] as String,
        name: json['name'] as String,
        region: json['region'] as String?,
        rationale: json['rationale'] as String,
        matchedPreferences: (json['matchedPreferences'] as List).cast<String>(),
        estimatedCostPerPerson:
            Cost.fromJson(json['estimatedCostPerPerson'] as Map<String, dynamic>),
      );
}

class Activity {
  const Activity({
    required this.id,
    required this.destinationId,
    required this.name,
    required this.category,
    required this.description,
    required this.estimatedCostPerPerson,
    required this.durationHours,
  });

  final String id;
  final String destinationId;
  final String name;
  final String category;
  final String description;
  final Cost estimatedCostPerPerson;
  final num durationHours;

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: json['id'] as String,
        destinationId: json['destinationId'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        description: json['description'] as String,
        estimatedCostPerPerson:
            Cost.fromJson(json['estimatedCostPerPerson'] as Map<String, dynamic>),
        durationHours: json['durationHours'] as num,
      );
}

class ItineraryItem {
  const ItineraryItem({
    required this.timeOfDay,
    required this.activityId,
    required this.title,
    required this.notes,
  });

  /// `'morning' | 'afternoon' | 'evening'`, per the proxy schema.
  final String timeOfDay;
  final String? activityId;
  final String title;
  final String? notes;

  factory ItineraryItem.fromJson(Map<String, dynamic> json) => ItineraryItem(
        timeOfDay: json['timeOfDay'] as String,
        activityId: json['activityId'] as String?,
        title: json['title'] as String,
        notes: json['notes'] as String?,
      );
}

class ItineraryDay {
  const ItineraryDay({
    required this.day,
    required this.date,
    required this.destinationId,
    required this.items,
  });

  final int day;
  final String? date;
  final String destinationId;
  final List<ItineraryItem> items;

  factory ItineraryDay.fromJson(Map<String, dynamic> json) => ItineraryDay(
        day: (json['day'] as num).toInt(),
        date: json['date'] as String?,
        destinationId: json['destinationId'] as String,
        items: (json['items'] as List)
            .map((item) => ItineraryItem.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class Recommendation {
  const Recommendation({
    required this.summary,
    required this.destinations,
    required this.activities,
    required this.itinerary,
    required this.assumptions,
    required this.warnings,
  });

  final String summary;
  final List<Destination> destinations;
  final List<Activity> activities;
  final List<ItineraryDay> itinerary;
  final List<String> assumptions;
  final List<String> warnings;

  factory Recommendation.fromJson(Map<String, dynamic> json) => Recommendation(
        summary: json['summary'] as String,
        destinations: (json['destinations'] as List)
            .map((item) => Destination.fromJson(item as Map<String, dynamic>))
            .toList(),
        activities: (json['activities'] as List)
            .map((item) => Activity.fromJson(item as Map<String, dynamic>))
            .toList(),
        itinerary: (json['itinerary'] as List)
            .map((item) => ItineraryDay.fromJson(item as Map<String, dynamic>))
            .toList(),
        assumptions: (json['assumptions'] as List).cast<String>(),
        warnings: (json['warnings'] as List).cast<String>(),
      );

  /// Activities belonging to [destinationId], in schema order.
  List<Activity> activitiesFor(String destinationId) =>
      activities.where((activity) => activity.destinationId == destinationId).toList();

  /// Itinerary days assigned to [destinationId].
  int dayCountFor(String destinationId) =>
      itinerary.where((day) => day.destinationId == destinationId).length;
}
