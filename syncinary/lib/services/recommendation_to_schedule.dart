import '../models/recommendation.dart';
import '../models/schedule.dart';

/// A schedule item ready for `ScheduleService.addItem`. The caller picks the
/// status.
class PendingScheduleItem {
  const PendingScheduleItem({
    required this.date,
    required this.dayKey,
    required this.title,
    required this.details,
  });

  /// Midnight local.
  final DateTime date;
  final String dayKey;
  final String title;
  final String details;

  ScheduleItemType get type => ScheduleItemType.activity;
}

sealed class ScheduleMapping {
  const ScheduleMapping();
}

class ScheduleMappingReady extends ScheduleMapping {
  const ScheduleMappingReady(this.items, this.skippedDuplicates);

  final List<PendingScheduleItem> items;
  final int skippedDuplicates;
}

/// Some day with items has no usable date and there is no trip start.
class ScheduleMappingNeedsStartDate extends ScheduleMapping {
  const ScheduleMappingNeedsStartDate();
}

/// Maps [destinationId]'s itinerary onto schedule items, skipping any whose
/// day and title already exist in [existing] or earlier in the result. Bad
/// data is dropped, never thrown on.
ScheduleMapping scheduleItemsFor(
  Recommendation rec,
  String destinationId, {
  required DateTime? tripStart,
  List<ScheduleItem> existing = const [],
}) {
  final activities = {for (final a in rec.activitiesFor(destinationId)) a.id: a};
  final days = rec.itinerary.where((d) => d.destinationId == destinationId).toList()
    ..sort((a, b) => a.day.compareTo(b.day)); // stable

  final seen = {for (final e in existing) _dupKey(e.day, e.title)};
  final items = <PendingScheduleItem>[];
  var skipped = 0;

  for (final day in days) {
    final usable = <(ItineraryItem, Activity?)>[];
    for (final item in day.items) {
      final id = item.activityId;
      final activity = id == null ? null : activities[id];
      if (item.title.trim().isEmpty || (id != null && activity == null)) continue;
      usable.add((item, activity));
    }
    if (usable.isEmpty) continue;

    final date = _parseDate(day.date) ??
        (tripStart != null && day.day >= 1
            ? DateTime(tripStart.year, tripStart.month, tripStart.day + day.day - 1)
            : null);
    if (date == null) {
      if (tripStart == null) return const ScheduleMappingNeedsStartDate();
      continue; // day < 1 with no valid date
    }
    final dayKey = scheduleDayKey(date);

    usable.sort((a, b) => _timeRank(a.$1.timeOfDay).compareTo(_timeRank(b.$1.timeOfDay)));
    for (final (item, activity) in usable) {
      var title = item.title.trim();
      if (title.length > scheduleItemTitleMaxLength) {
        title = title.substring(0, scheduleItemTitleMaxLength).trim();
      }
      if (!seen.add(_dupKey(dayKey, title))) {
        skipped++;
        continue;
      }
      items.add(PendingScheduleItem(
        date: date,
        dayKey: dayKey,
        title: title,
        details: _details(item, activity),
      ));
    }
  }
  return ScheduleMappingReady(items, skipped);
}

String _dupKey(String dayKey, String title) => '$dayKey|${title.trim().toLowerCase()}';

const _timesOfDay = ['morning', 'afternoon', 'evening'];

int _timeRank(String timeOfDay) {
  final i = _timesOfDay.indexOf(timeOfDay);
  return i == -1 ? _timesOfDay.length : i;
}

/// Accepts only real calendar dates, so `2026-02-30` is rejected.
DateTime? _parseDate(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final date = DateTime(
    int.parse(value.substring(0, 4)),
    int.parse(value.substring(5, 7)),
    int.parse(value.substring(8)),
  );
  return scheduleDayKey(date) == value ? date : null;
}

String _details(ItineraryItem item, Activity? activity) {
  String fmt(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();
  final time = _timesOfDay.contains(item.timeOfDay)
      ? item.timeOfDay[0].toUpperCase() + item.timeOfDay.substring(1)
      : '';
  final cost = activity?.estimatedCostPerPerson;
  return [
    time,
    item.notes?.trim() ?? '',
    if (activity != null) ...[
      activity.description.trim(),
      if (activity.durationHours > 0) '~${fmt(activity.durationHours)} h',
      if (cost != null && cost.amount > 0) '~${fmt(cost.amount)} ${cost.currency}/person',
    ],
  ].where((part) => part.isNotEmpty).join(' · ');
}
