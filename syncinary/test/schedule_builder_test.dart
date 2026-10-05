import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syncinary/models/group.dart';
import 'package:syncinary/models/schedule.dart';
import 'package:syncinary/pages/itinerary_builder.dart';
import 'package:syncinary/pages/schedule_builder_page.dart';
import 'package:syncinary/services/schedule_service.dart';
import 'package:syncinary/theme/app_theme.dart';

Widget makeTestableWidget(Widget child) {
  return MaterialApp(theme: buildAppTheme(), home: child);
}

ScheduleService _service(FakeFirebaseFirestore firestore) => ScheduleService(
      firestore: firestore,
      auth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'me-uid', email: 'me@syncinary.app', displayName: 'You'),
        signedIn: true,
      ),
    );

Group _nycGroup() => Group(
      id: 'nyc',
      name: 'NYC Trip',
      members: [
        GroupMember(id: 'me-uid', username: 'You', email: 'me@syncinary.app', role: GroupRole.admin),
      ],
    );

/// Opens the add dialog for [button] ('Add Flight' etc.) and saves it.
Future<void> _addViaDialog(WidgetTester tester, String button,
    {required String titleLabel, required String title, String? detailsLabel, String? details}) async {
  await tester.ensureVisible(find.text(button));
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, titleLabel), title);
  if (detailsLabel != null) {
    await tester.enterText(find.widgetWithText(TextField, detailsLabel), details!);
  }
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

void main() {
  test('formatScheduleDay uses weekday, month, and ordinal suffix', () {
    expect(formatScheduleDay(DateTime(2026, 5, 3)), 'Sunday, May 3rd');
    expect(formatScheduleDay(DateTime(2026, 5, 1)), 'Friday, May 1st');
    expect(formatScheduleDay(DateTime(2026, 5, 12)), 'Tuesday, May 12th');
    expect(formatScheduleDay(DateTime(2026, 5, 22)), 'Friday, May 22nd');
  });

  test('[101-4] Schedule item types round-trip through their stored strings', () {
    for (final type in ScheduleItemType.values) {
      expect(scheduleItemTypeFromString(scheduleItemTypeToString(type)), type);
    }
    expect(scheduleItemTypeFromString('flight'), ScheduleItemType.flight);
    expect(scheduleItemTypeFromString(null), ScheduleItemType.activity);
  });

  testWidgets('[101-4] Add Activity / Flight / Hotel save on the chosen date and show only in the Day Plan',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = _service(firestore);
    await service.addDay('nyc', DateTime(2026, 5, 3));

    await tester.pumpWidget(
      makeTestableWidget(ScheduleBuilderPage(group: _nycGroup(), service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Schedule Builder'), findsOneWidget);
    expect(find.text('AI Advisor'), findsOneWidget);
    expect(find.text('Day Plan'), findsOneWidget);
    expect(find.text('Add to Trip'), findsOneWidget);
    expect(find.text('Add Activity'), findsOneWidget);
    expect(find.text('Add Flight'), findsOneWidget);
    expect(find.text('Add Hotel'), findsOneWidget);
    expect(find.text('No flights added yet.'), findsOneWidget);

    // ── Each dialog defaults to the day open in the Day Plan ──
    await tester.tap(find.text('Add Hotel'));
    await tester.pumpAndSettle();
    expect(find.text('Add Hotel'), findsNWidgets(2)); // button + dialog title
    expect(find.text('Sunday, May 3rd'), findsNWidgets(2)); // dropdown + dialog date
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await _addViaDialog(tester, 'Add Hotel',
        titleLabel: 'Hotel name', title: 'Hilton, Times Square',
        detailsLabel: 'Details (e.g. 1 bed)', details: '1 Bed');
    await _addViaDialog(tester, 'Add Flight',
        titleLabel: 'Flight (e.g. UA 123, ORD → JFK)', title: 'UA 123, ORD → JFK',
        detailsLabel: 'Details (e.g. departs 8:05 AM)', details: 'Departs 8:05 AM');
    await _addViaDialog(tester, 'Add Activity',
        titleLabel: 'Activity', title: 'Empire State Building');

    // Listed once — in the Day Plan only.
    expect(find.text('Hilton, Times Square'), findsOneWidget);
    expect(find.text('1 Bed'), findsOneWidget);
    expect(find.text('UA 123, ORD → JFK'), findsOneWidget);
    expect(find.text('Empire State Building'), findsOneWidget);
    expect(find.text('No flights added yet.'), findsNothing);
    expect(find.text('Added by you'), findsNWidgets(3));

    final stored = await firestore.collection('groups').doc('nyc').collection('scheduleItems').get();
    expect(stored.docs.map((d) => d.data()['type']), containsAll(['hotel', 'flight', 'activity']));
    expect(stored.docs.every((d) => d.data()['day'] == '2026-05-03'), isTrue);

    // ── Edit the hotel ──
    final hotelCard = find.ancestor(
        of: find.text('Hilton, Times Square'),
        matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ScheduleItemCard'));
    await tester.ensureVisible(hotelCard);
    await tester.tap(find.descendant(of: hotelCard, matching: find.byTooltip('Edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Details (e.g. 1 bed)'), '2 Beds');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('2 Beds'), findsOneWidget);

    // ── Remove it ──
    await tester.tap(find.descendant(of: hotelCard, matching: find.byTooltip('Remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(find.text('Hilton, Times Square'), findsNothing);
    expect(find.text('No hotel added yet.'), findsOneWidget);
  });

  testWidgets('Add Flight / Add Hotel can open the search flow, set to that type', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = _service(firestore);

    await tester.pumpWidget(
      makeTestableWidget(ScheduleBuilderPage(group: _nycGroup(), service: service)),
    );
    await tester.pumpAndSettle();

    // ── Flights ──
    await tester.tap(find.text('Add Flight'));
    await tester.pumpAndSettle();
    expect(find.text('Search hotels'), findsNothing);
    await tester.tap(find.text('Search flights'));
    await tester.pumpAndSettle();
    expect(tester.widget<itinerary_builder>(find.byType(itinerary_builder)).initialSearchType,
        SearchType.flights);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // ── Hotels ──
    await tester.tap(find.text('Add Hotel'));
    await tester.pumpAndSettle();
    expect(find.text('Search flights'), findsNothing);
    await tester.tap(find.text('Search hotels'));
    await tester.pumpAndSettle();
    expect(tester.widget<itinerary_builder>(find.byType(itinerary_builder)).initialSearchType,
        SearchType.hotels);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // ── Activities have nothing to search ──
    await tester.tap(find.text('Add Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Search flights'), findsNothing);
    expect(find.text('Search hotels'), findsNothing);
  });

  testWidgets('[101-4] Picking a new date creates that day and opens it', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = _service(firestore);
    await service.addDay('nyc', DateTime(2026, 5, 3));

    await tester.pumpWidget(
      makeTestableWidget(ScheduleBuilderPage(group: _nycGroup(), service: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('item-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Sunday, May 10th'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Activity'), 'Broadway show');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final dropdown = find.byKey(const ValueKey('day-plan-dropdown'));
    expect(find.descendant(of: dropdown, matching: find.text('Sunday, May 10th')), findsOneWidget);
    expect(find.text('Broadway show'), findsOneWidget);
    final days = await firestore.collection('groups').doc('nyc').collection('scheduleDays').get();
    expect(days.docs.map((d) => d.id), containsAll(['2026-05-03', '2026-05-10']));
  });

  testWidgets('[101-4] Items added by every member appear with who added them', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = _service(firestore);
    await service.addItem('nyc',
        date: DateTime(2026, 5, 3), type: ScheduleItemType.hotel, title: 'Hilton, Times Square');
    // Written by other members' devices, straight to the shared collection.
    final items = firestore.collection('groups').doc('nyc').collection('scheduleItems');
    await items.add({
      'day': '2026-05-03', 'type': 'activity', 'title': 'Empire State Building',
      'details': '', 'addedBy': 'alex-uid', 'createdAt': DateTime(2026, 1, 1),
    });
    await items.add({
      'day': '2026-05-03', 'type': 'flight', 'title': 'DL 45, ATL → JFK',
      'details': '', 'addedBy': 'gone-uid', 'createdAt': DateTime(2026, 1, 2),
    });

    final group = _nycGroup()
      ..members.add(GroupMember(
          id: 'alex-uid', username: 'Alex', email: 'alex@syncinary.app', role: GroupRole.user));
    await tester.pumpWidget(makeTestableWidget(ScheduleBuilderPage(group: group, service: service)));
    await tester.pumpAndSettle();

    expect(find.text('Added by you'), findsOneWidget);
    expect(find.text('Added by Alex'), findsOneWidget);
    expect(find.text('Added by a former member'), findsOneWidget);
  });

  testWidgets('Day Plan shows everything planned for the selected day', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = _service(firestore);
    await service.addItem('nyc',
        date: DateTime(2026, 5, 3), type: ScheduleItemType.hotel, title: 'Hilton, Times Square');
    await service.addItem('nyc',
        date: DateTime(2026, 5, 4), type: ScheduleItemType.activity, title: 'Statue of Liberty');

    await tester.pumpWidget(
      makeTestableWidget(ScheduleBuilderPage(group: _nycGroup(), service: service)),
    );
    await tester.pumpAndSettle();

    // ── Defaults to the first day ──
    expect(find.text('Hilton, Times Square'), findsOneWidget);
    expect(find.text('Statue of Liberty'), findsNothing);
    expect(find.text('No activities planned yet.'), findsOneWidget);

    // ── The dropdown shows only the selected day until it's opened ──
    final dropdown = find.byKey(const ValueKey('day-plan-dropdown'));
    expect(find.descendant(of: dropdown, matching: find.text('Sunday, May 3rd')), findsOneWidget);
    expect(find.descendant(of: dropdown, matching: find.text('Monday, May 4th')), findsNothing);

    // ── Pick the second day from it ──
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monday, May 4th').last); // the open menu's entry
    await tester.pumpAndSettle();
    expect(find.descendant(of: dropdown, matching: find.text('Monday, May 4th')), findsOneWidget);
    expect(find.text('Statue of Liberty'), findsOneWidget);
    expect(find.text('Hilton, Times Square'), findsNothing);
    expect(find.text('No hotel added yet.'), findsOneWidget);

    // ── Removing the selected day falls back to the first remaining one ──
    await tester.tap(find.byTooltip('Remove day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(find.descendant(of: dropdown, matching: find.text('Sunday, May 3rd')), findsOneWidget);
    expect(find.text('Hilton, Times Square'), findsOneWidget);
  });

  testWidgets('Removing a day also removes its items', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = _service(firestore);
    await service.addItem('nyc',
        date: DateTime(2026, 5, 3), type: ScheduleItemType.activity, title: 'Empire State Building');

    await tester.pumpWidget(
      makeTestableWidget(ScheduleBuilderPage(group: _nycGroup(), service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Empire State Building'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();

    expect(find.text('Sunday, May 3rd'), findsNothing);
    expect(find.text('Nothing planned yet. Add a flight, hotel, or activity to start the schedule.'),
        findsOneWidget);
    final items = await firestore.collection('groups').doc('nyc').collection('scheduleItems').get();
    expect(items.docs, isEmpty);
  });
}
