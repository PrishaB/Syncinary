import 'package:cloud_firestore/cloud_firestore.dart';

enum ScheduleItemType { flight, hotel, activity }

/// Unknown or missing values read as an activity.
ScheduleItemType scheduleItemTypeFromString(String? value) => switch (value) {
      'flight' => ScheduleItemType.flight,
      'hotel' => ScheduleItemType.hotel,
      _ => ScheduleItemType.activity,
    };

String scheduleItemTypeToString(ScheduleItemType type) => type.name;

/// Formats a calendar date as the `yyyy-MM-dd` key used for schedule days.
String scheduleDayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Backed by a document in the `groups/{groupId}/scheduleDays` subcollection,
/// keyed by its own date so a day can't be added twice:
/// ```
/// groups/{groupId}/scheduleDays/{yyyy-MM-dd}: {
///   date: Timestamp,   // midnight local time of that day
/// }
/// ```
class ScheduleDay {
  ScheduleDay({required this.key, required this.date});

  final String key;
  final DateTime date;

  factory ScheduleDay.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return ScheduleDay(
      key: doc.id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.parse(doc.id),
    );
  }
}

/// Backed by a document in the `groups/{groupId}/scheduleItems` subcollection:
/// ```
/// groups/{groupId}/scheduleItems/{itemId}: {
///   day: 'yyyy-MM-dd',   // the ScheduleDay this item belongs to
///   type: 'flight' | 'hotel' | 'activity',
///   title: string,
///   details: string,
///   addedBy: uid,
///   createdAt: Timestamp,
/// }
/// ```
class ScheduleItem {
  ScheduleItem({
    required this.id,
    required this.day,
    required this.type,
    required this.title,
    required this.details,
    this.addedBy = '',
  });

  final String id;
  final String day;
  final ScheduleItemType type;
  final String title;
  final String details;

  /// Uid of the group member who added this item; empty on legacy docs.
  final String addedBy;

  factory ScheduleItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return ScheduleItem(
      id: doc.id,
      day: data['day'] as String? ?? '',
      type: scheduleItemTypeFromString(data['type'] as String?),
      title: data['title'] as String? ?? '',
      details: data['details'] as String? ?? '',
      addedBy: data['addedBy'] as String? ?? '',
    );
  }
}
