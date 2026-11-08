import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/models/recommendation.dart';
import 'package:syncinary/models/schedule.dart';
import 'package:syncinary/services/recommendation_to_schedule.dart';

const _activity = Activity(
  id: 'a1',
  destinationId: 'd1',
  name: 'Pier walk',
  category: 'outdoors',
  description: 'Stroll the pier.',
  estimatedCostPerPerson: Cost(amount: 25, currency: 'USD'),
  durationHours: 1.5,
);

ItineraryItem _item(
  String title, {
  String timeOfDay = 'morning',
  String? activityId,
  String? notes,
}) =>
    ItineraryItem(timeOfDay: timeOfDay, activityId: activityId, title: title, notes: notes);

ItineraryDay _day(
  int day,
  List<ItineraryItem> items, {
  String? date,
  String destinationId = 'd1',
}) =>
    ItineraryDay(day: day, date: date, destinationId: destinationId, items: items);

ScheduleMapping _map(
  List<ItineraryDay> itinerary, {
  DateTime? tripStart,
  List<ScheduleItem> existing = const [],
}) =>
    scheduleItemsFor(
      Recommendation(
        summary: '',
        destinations: const [],
        activities: const [_activity],
        itinerary: itinerary,
        assumptions: const [],
        warnings: const [],
      ),
      'd1',
      tripStart: tripStart,
      existing: existing,
    );

ScheduleMappingReady _ready(ScheduleMapping m) => m as ScheduleMappingReady;

List<String> _titles(ScheduleMapping m) => _ready(m).items.map((i) => i.title).toList();

void main() {
  group('dates', () {
    test('uses a valid date', () {
      final item = _ready(_map([_day(1, [_item('A')], date: '2026-03-05')])).items.single;
      expect(item.dayKey, '2026-03-05');
      expect(item.date, DateTime(2026, 3, 5));
    });

    test('falls back to tripStart + (day - 1) for a missing or invalid date', () {
      final m = _map([
        _day(2, [_item('A')], date: '2026-02-30'),
        _day(3, [_item('B')], date: 'soon'),
        _day(4, [_item('C')]),
      ], tripStart: DateTime(2026, 3, 30, 14, 30));
      final items = _ready(m).items;
      expect(items.map((i) => i.dayKey), ['2026-03-31', '2026-04-01', '2026-04-02']);
      expect(items.first.date, DateTime(2026, 3, 31));
    });

    test('needs a start date when a day cannot be dated', () {
      expect(_map([_day(1, [_item('A')])]), isA<ScheduleMappingNeedsStartDate>());
      expect(
        _map([_day(1, [_item('A')], date: '2026-03-05'), _day(2, [_item('B')])]),
        isA<ScheduleMappingNeedsStartDate>(),
      );
    });

    test('is ready without tripStart when every day has a date', () {
      expect(_titles(_map([_day(1, [_item('A')], date: '2026-03-05')])), ['A']);
    });

    test('skips an undated day numbered below 1', () {
      final m = _map([_day(0, [_item('A')]), _day(1, [_item('B')])],
          tripStart: DateTime(2026, 3, 1));
      expect(_titles(m), ['B']);
    });

    test('a day with no usable items needs no date', () {
      expect(_titles(_map([_day(1, [_item(' ')])])), isEmpty);
    });
  });

  group('selection and order', () {
    test('keeps only the destination and sorts days by day', () {
      final m = _map([
        _day(2, [_item('Second')], date: '2026-03-06'),
        _day(1, [_item('Other')], date: '2026-03-05', destinationId: 'd2'),
        _day(1, [_item('First')], date: '2026-03-05'),
      ]);
      expect(_titles(m), ['First', 'Second']);
    });

    test('sorts items morning, afternoon, evening, unknown', () {
      final m = _map([
        _day(1, [
          _item('Night', timeOfDay: 'evening'),
          _item('Odd', timeOfDay: 'noon'),
          _item('Early'),
          _item('Mid', timeOfDay: 'afternoon'),
        ], date: '2026-03-05'),
      ]);
      expect(_titles(m), ['Early', 'Mid', 'Night', 'Odd']);
    });

    test('no days for the destination is ready with nothing, even without tripStart', () {
      final m = _ready(_map([_day(1, [_item('A')], destinationId: 'd2')]));
      expect(m.items, isEmpty);
      expect(m.skippedDuplicates, 0);
    });
  });

  group('items', () {
    test('details combine time, notes, description, duration and cost', () {
      final m = _map([
        _day(1, [_item('Pier', timeOfDay: 'afternoon', activityId: 'a1', notes: ' Bring a hat ')],
            date: '2026-03-05'),
      ]);
      expect(_ready(m).items.single.details,
          'Afternoon · Bring a hat · Stroll the pier. · ~1.5 h · ~25 USD/person');
    });

    test('details hold only the time without notes or activity', () {
      final m = _map([_day(1, [_item('Walk')], date: '2026-03-05')]);
      expect(_ready(m).items.single.details, 'Morning');
    });

    test('details leave out an unknown time of day', () {
      final m = _map([_day(1, [_item('Walk', timeOfDay: 'noon')], date: '2026-03-05')]);
      expect(_ready(m).items.single.details, '');
    });

    test('titles are trimmed and capped', () {
      final long = 'x' * (scheduleItemTitleMaxLength - 1);
      final m = _map([
        _day(1, [_item('  Walk  '), _item('$long  tail')], date: '2026-03-05'),
      ]);
      expect(_titles(m), ['Walk', long]);
    });

    test('drops blank titles and unknown activity ids', () {
      final m = _map([
        _day(1, [_item('  '), _item('Ghost', activityId: 'nope'), _item('Ok')],
            date: '2026-03-05'),
      ]);
      expect(_titles(m), ['Ok']);
    });
  });

  group('duplicates', () {
    ScheduleItem existing(String day, String title) => ScheduleItem(
        id: 'e', day: day, type: ScheduleItemType.activity, title: title, details: '');

    test('skips an existing item on the same day, ignoring case and spaces', () {
      final m = _ready(_map(
        [_day(1, [_item('Pier Walk')], date: '2026-03-05')],
        existing: [existing('2026-03-05', '  pier walk ')],
      ));
      expect(m.items, isEmpty);
      expect(m.skippedDuplicates, 1);
    });

    test('keeps the same title on a different day', () {
      final m = _ready(_map(
        [_day(1, [_item('Pier Walk')], date: '2026-03-05')],
        existing: [existing('2026-03-06', 'Pier Walk')],
      ));
      expect(m.items, hasLength(1));
      expect(m.skippedDuplicates, 0);
    });

    test('skips a repeat within the recommendation', () {
      final m = _ready(_map([
        _day(1, [_item('Walk'), _item('walk', timeOfDay: 'evening')], date: '2026-03-05'),
      ]));
      expect(m.items, hasLength(1));
      expect(m.skippedDuplicates, 1);
    });
  });
}
