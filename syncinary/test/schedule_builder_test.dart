import 'package:cloud_firestore/cloud_firestore.dart';
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

ScheduleService _service(FakeFirebaseFirestore firestore, {String uid = 'me-uid'}) =>
    ScheduleService(
      firestore: firestore,
      auth: MockFirebaseAuth(
        mockUser: MockUser(uid: uid, email: '$uid@syncinary.app', displayName: uid),
        signedIn: true,
      ),
    );

/// 'me-uid' is the admin; Alex and Sam are regular members.
Group _rolesGroup() => Group(
      id: 'nyc',
      name: 'NYC Trip',
      members: [
        GroupMember(id: 'me-uid', username: 'Jordan', email: 'me@syncinary.app', role: GroupRole.admin),
        GroupMember(id: 'alex-uid', username: 'Alex', email: 'alex@syncinary.app', role: GroupRole.user),
        GroupMember(id: 'sam-uid', username: 'Sam', email: 'sam@syncinary.app', role: GroupRole.user),
      ],
    );

CollectionReference<Map<String, dynamic>> _itemsRef(FakeFirebaseFirestore firestore) =>
    firestore.collection('groups').doc('nyc').collection('scheduleItems');

/// The card showing [title] in the Day Plan (itinerary) or the Suggestions panel.
Finder _dayPlanCard(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ScheduleItemCard'));
Finder _suggestionCard(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_SuggestionCard'));

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

  test('[101-4] Schedule item status round-trips, and a missing status reads as approved', () {
    for (final status in ScheduleItemStatus.values) {
      expect(scheduleItemStatusFromString(scheduleItemStatusToString(status)), status);
    }
    expect(scheduleItemStatusFromString(null), ScheduleItemStatus.approved);
  });

  test('[101-4] addItem stores the status and approveItem moves a suggestion onto the itinerary',
      () async {
    final firestore = FakeFirebaseFirestore();
    final member = _service(firestore, uid: 'alex-uid');
    await member.addItem('nyc',
        date: DateTime(2026, 5, 3),
        type: ScheduleItemType.activity,
        title: 'MoMA',
        status: ScheduleItemStatus.suggested);

    var docs = (await _itemsRef(firestore).get()).docs;
    expect(docs.single.data()['status'], 'suggested');
    expect(docs.single.data()['addedBy'], 'alex-uid');
    expect(ScheduleItem.fromDoc(docs.single).isSuggestion, isTrue);

    await _service(firestore).approveItem('nyc', docs.single.id);
    docs = (await _itemsRef(firestore).get()).docs;
    expect(docs.single.data()['status'], 'approved');
    expect(docs.single.data()['addedBy'], 'alex-uid'); // still credited to the suggester
  });

  testWidgets('[501-10] A member suggests: the item goes to Suggestions, not the Day Plan',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = _service(firestore, uid: 'alex-uid');
    await _service(firestore).addItem('nyc',
        date: DateTime(2026, 5, 3), type: ScheduleItemType.hotel, title: 'Hilton, Times Square');

    await tester.pumpWidget(
        makeTestableWidget(ScheduleBuilderPage(group: _rolesGroup(), service: service)));
    await tester.pumpAndSettle();

    // ── The add buttons and form say "Suggest" ──
    expect(find.text('Suggest Activity'), findsOneWidget);
    expect(find.text('Suggest Flight'), findsOneWidget);
    expect(find.text('Suggest Hotel'), findsOneWidget);
    expect(find.text('Add Activity'), findsNothing);
    expect(find.text('No suggestions pending.'), findsOneWidget);

    await tester.tap(find.text('Suggest Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Suggest Activity'), findsNWidgets(2)); // button + dialog title
    await tester.enterText(find.widgetWithText(TextField, 'Activity'), 'MoMA');
    await tester.tap(find.text('Suggest'));
    await tester.pumpAndSettle();

    // ── Listed as a suggestion, credited to the member, not on the itinerary ──
    expect(_suggestionCard('MoMA'), findsOneWidget);
    expect(_dayPlanCard('MoMA'), findsNothing);
    expect(find.text('No activities planned yet.'), findsOneWidget);
    expect(find.text('Suggested by you'), findsOneWidget);
    expect(find.text('No suggestions pending.'), findsNothing);
    expect(find.descendant(of: _suggestionCard('MoMA'), matching: find.text('Sunday, May 3rd')),
        findsOneWidget);

    final stored =
        (await _itemsRef(firestore).where('title', isEqualTo: 'MoMA').get()).docs.single.data();
    expect(stored['status'], 'suggested');
    expect(stored['addedBy'], 'alex-uid');
  });

  testWidgets('[501-10] A member cannot edit or remove the itinerary, approve, or touch others\' suggestions',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final admin = _service(firestore);
    await admin.addItem('nyc',
        date: DateTime(2026, 5, 3), type: ScheduleItemType.hotel, title: 'Hilton, Times Square');
    await _service(firestore, uid: 'sam-uid').addItem('nyc',
        date: DateTime(2026, 5, 3),
        type: ScheduleItemType.activity,
        title: 'Central Park',
        status: ScheduleItemStatus.suggested);
    final alex = _service(firestore, uid: 'alex-uid');
    await alex.addItem('nyc',
        date: DateTime(2026, 5, 3),
        type: ScheduleItemType.activity,
        title: 'MoMA',
        status: ScheduleItemStatus.suggested);

    await tester.pumpWidget(
        makeTestableWidget(ScheduleBuilderPage(group: _rolesGroup(), service: alex)));
    await tester.pumpAndSettle();

    // ── Approved item: visible, credited, but no controls ──
    expect(_dayPlanCard('Hilton, Times Square'), findsOneWidget);
    expect(find.text('Added by Jordan'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsNothing);
    expect(find.byTooltip('Remove'), findsNothing);
    expect(find.byTooltip('Remove day'), findsNothing);

    // ── Suggestions: everyone's are visible; only your own can be withdrawn ──
    expect(find.text('Suggested by Sam'), findsOneWidget);
    expect(find.text('Suggested by you'), findsOneWidget);
    expect(find.byTooltip('Approve'), findsNothing);
    expect(find.byTooltip('Reject'), findsNothing);
    expect(find.descendant(of: _suggestionCard('Central Park'), matching: find.byTooltip('Withdraw')),
        findsNothing);

    final withdraw = find.descendant(of: _suggestionCard('MoMA'), matching: find.byTooltip('Withdraw'));
    await tester.ensureVisible(withdraw);
    await tester.tap(withdraw);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Withdraw').last);
    await tester.pumpAndSettle();

    expect(find.text('MoMA'), findsNothing);
    final titles = (await _itemsRef(firestore).get()).docs.map((d) => d.data()['title']);
    expect(titles, unorderedEquals(['Hilton, Times Square', 'Central Park']));
  });

  testWidgets('[501-10] The admin approves a suggestion into the Day Plan or rejects it',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final alex = _service(firestore, uid: 'alex-uid');
    await alex.addItem('nyc',
        date: DateTime(2026, 5, 3),
        type: ScheduleItemType.activity,
        title: 'MoMA',
        status: ScheduleItemStatus.suggested);
    await alex.addItem('nyc',
        date: DateTime(2026, 5, 3),
        type: ScheduleItemType.flight,
        title: 'NK 99, ORD → LGA',
        status: ScheduleItemStatus.suggested);

    await tester.pumpWidget(makeTestableWidget(
        ScheduleBuilderPage(group: _rolesGroup(), service: _service(firestore))));
    await tester.pumpAndSettle();

    // Admin's add buttons still say "Add"; suggestions are labelled with the suggester.
    expect(find.text('Add Activity'), findsOneWidget);
    expect(find.text('Suggest Activity'), findsNothing);
    expect(find.text('Suggested by Alex'), findsNWidgets(2));
    expect(find.byTooltip('Withdraw'), findsNothing);
    expect(find.text('No activities planned yet.'), findsOneWidget);

    // ── Approve: moves into the Day Plan, still credited to Alex ──
    final approve = find.descendant(of: _suggestionCard('MoMA'), matching: find.byTooltip('Approve'));
    await tester.ensureVisible(approve);
    await tester.tap(approve);
    await tester.pumpAndSettle();
    expect(_dayPlanCard('MoMA'), findsOneWidget);
    expect(_suggestionCard('MoMA'), findsNothing);
    expect(find.text('Added by Alex'), findsOneWidget);
    expect(find.descendant(of: _dayPlanCard('MoMA'), matching: find.byTooltip('Edit')),
        findsOneWidget);

    // ── Reject: deleted ──
    final reject =
        find.descendant(of: _suggestionCard('NK 99, ORD → LGA'), matching: find.byTooltip('Reject'));
    await tester.ensureVisible(reject);
    await tester.tap(reject);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject').last);
    await tester.pumpAndSettle();
    expect(find.text('NK 99, ORD → LGA'), findsNothing);
    expect(find.text('No suggestions pending.'), findsOneWidget);

    final docs = (await _itemsRef(firestore).get()).docs;
    expect(docs.single.data()['title'], 'MoMA');
    expect(docs.single.data()['status'], 'approved');
  });

  testWidgets('[101-4] Items saved before suggestions existed (no status) stay in the Day Plan',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = _service(firestore, uid: 'alex-uid');
    await service.addDay('nyc', DateTime(2026, 5, 3));
    await _itemsRef(firestore).add({
      'day': '2026-05-03', 'type': 'activity', 'title': 'Empire State Building',
      'details': '', 'addedBy': 'sam-uid', 'createdAt': DateTime(2026, 1, 1),
    });

    await tester.pumpWidget(
        makeTestableWidget(ScheduleBuilderPage(group: _rolesGroup(), service: service)));
    await tester.pumpAndSettle();

    expect(_dayPlanCard('Empire State Building'), findsOneWidget);
    expect(find.text('Added by Sam'), findsOneWidget);
    expect(find.text('No suggestions pending.'), findsOneWidget);
  });

  testWidgets('[101-4] Add Activity / Flight / Hotel save on the chosen date and show only in the Day Plan',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = _service(firestore);
    await service.addItem('nyc',
        date: DateTime(2026, 5, 3), type: ScheduleItemType.activity, title: 'Arrive in NYC');

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
    expect(find.text('Added by you'), findsNWidgets(4)); // + the seeded activity

    final stored = await firestore.collection('groups').doc('nyc').collection('scheduleItems').get();
    expect(stored.docs.map((d) => d.data()['type']), containsAll(['hotel', 'flight', 'activity']));
    expect(stored.docs.every((d) => d.data()['day'] == '2026-05-03'), isTrue);
    // The admin's items skip the suggestion step.
    expect(stored.docs.every((d) => d.data()['status'] == 'approved'), isTrue);
    expect(find.text('No suggestions pending.'), findsOneWidget);

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
    await service.addItem('nyc',
        date: DateTime(2026, 5, 3), type: ScheduleItemType.activity, title: 'Arrive in NYC');

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

  testWidgets('[101-4] Removing the last item on a day removes the day', (tester) async {
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

    final hotelCard = _dayPlanCard('Hilton, Times Square');
    await tester.ensureVisible(hotelCard);
    await tester.tap(find.descendant(of: hotelCard, matching: find.byTooltip('Remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();

    // May 3rd is gone; the Day Plan moves to the next day.
    final dropdown = find.byKey(const ValueKey('day-plan-dropdown'));
    expect(find.descendant(of: dropdown, matching: find.text('Monday, May 4th')), findsOneWidget);
    expect(find.text('Sunday, May 3rd'), findsNothing);
    final days = await firestore.collection('groups').doc('nyc').collection('scheduleDays').get();
    expect(days.docs.map((d) => d.id), ['2026-05-04']);
  });

  testWidgets('[101-4] A day with only a suggestion shows; a day with nothing on it does not',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final admin = _service(firestore);
    await admin.addDay('nyc', DateTime(2026, 5, 2)); // empty leftover day doc
    await _service(firestore, uid: 'alex-uid').addItem('nyc',
        date: DateTime(2026, 5, 3),
        type: ScheduleItemType.activity,
        title: 'MoMA',
        status: ScheduleItemStatus.suggested);

    await tester.pumpWidget(
        makeTestableWidget(ScheduleBuilderPage(group: _rolesGroup(), service: admin)));
    await tester.pumpAndSettle();

    final dropdown = find.byKey(const ValueKey('day-plan-dropdown'));
    expect(find.descendant(of: dropdown, matching: find.text('Sunday, May 3rd')), findsOneWidget);
    expect(find.text('Saturday, May 2nd'), findsNothing);

    // ── Rejecting the only suggestion empties May 3rd, so it goes too ──
    final reject = find.descendant(of: _suggestionCard('MoMA'), matching: find.byTooltip('Reject'));
    await tester.ensureVisible(reject);
    await tester.tap(reject);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject').last);
    await tester.pumpAndSettle();

    expect(find.text('Sunday, May 3rd'), findsNothing);
    expect(find.text('Nothing planned yet. Add a flight, hotel, or activity to start the schedule.'),
        findsOneWidget);
    final days = await firestore.collection('groups').doc('nyc').collection('scheduleDays').get();
    expect(days.docs.map((d) => d.id), isNot(contains('2026-05-03')));
  });

  testWidgets('[501-10] Opening the page as admin deletes leftover empty days; as a member it does not',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final admin = _service(firestore);
    await admin.addDay('nyc', DateTime(2027, 1, 4)); // empty leftover
    await admin.addItem('nyc',
        date: DateTime(2026, 5, 3), type: ScheduleItemType.hotel, title: 'Hilton, Times Square');
    final daysRef = firestore.collection('groups').doc('nyc').collection('scheduleDays');

    // ── Member: leaves it (the rules wouldn't let them delete it anyway) ──
    await tester.pumpWidget(makeTestableWidget(
        ScheduleBuilderPage(group: _rolesGroup(), service: _service(firestore, uid: 'alex-uid'))));
    await tester.pumpAndSettle();
    expect((await daysRef.get()).docs.map((d) => d.id), containsAll(['2026-05-03', '2027-01-04']));

    // ── Admin: cleans it up, keeps the day with an item ──
    await tester.pumpWidget(const SizedBox()); // dispose the member's page
    await tester.pumpWidget(
        makeTestableWidget(ScheduleBuilderPage(group: _rolesGroup(), service: admin)));
    await tester.pumpAndSettle();
    expect((await daysRef.get()).docs.map((d) => d.id), ['2026-05-03']);
  });

  test('[101-4] Moving an item to another date removes the day it left if now empty', () async {
    final firestore = FakeFirebaseFirestore();
    final service = _service(firestore);
    await service.addItem('nyc',
        date: DateTime(2026, 5, 3), type: ScheduleItemType.activity, title: 'MoMA');
    await service.addItem('nyc',
        date: DateTime(2026, 5, 4), type: ScheduleItemType.activity, title: 'Statue of Liberty');
    final moma = (await _itemsRef(firestore).where('title', isEqualTo: 'MoMA').get()).docs.single;

    await service.updateItem('nyc', moma.id,
        date: DateTime(2026, 5, 4), title: 'MoMA', details: '');

    final days = await firestore.collection('groups').doc('nyc').collection('scheduleDays').get();
    expect(days.docs.map((d) => d.id), ['2026-05-04']);
  });
}
