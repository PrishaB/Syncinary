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

void main() {
  test('formatScheduleDay uses weekday, month, and ordinal suffix', () {
    expect(formatScheduleDay(DateTime(2026, 5, 3)), 'Sunday, May 3rd');
    expect(formatScheduleDay(DateTime(2026, 5, 1)), 'Friday, May 1st');
    expect(formatScheduleDay(DateTime(2026, 5, 12)), 'Tuesday, May 12th');
    expect(formatScheduleDay(DateTime(2026, 5, 22)), 'Friday, May 22nd');
  });

  testWidgets('Schedule Builder shows days, and adds/edits/removes items', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = _service(firestore);
    await service.addDay('nyc', DateTime(2026, 5, 3));

    await tester.pumpWidget(
      makeTestableWidget(ScheduleBuilderPage(group: _nycGroup(), service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Schedule Builder'), findsOneWidget);
    expect(find.text('AI Advisor'), findsOneWidget);
    expect(find.text('Group Preferences'), findsOneWidget);
    expect(find.text('Sunday, May 3rd'), findsOneWidget);

    // ── Add a hotel ──
    await tester.ensureVisible(find.text('Add Hotel'));
    await tester.tap(find.text('Add Hotel'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Hotel name'), 'Hilton, Times Square');
    await tester.enterText(find.widgetWithText(TextField, 'Details (e.g. 1 bed)'), '1 Bed');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Hilton, Times Square'), findsOneWidget);
    expect(find.text('1 Bed'), findsOneWidget);
    final stored = await firestore.collection('groups').doc('nyc').collection('scheduleItems').get();
    expect(stored.docs.single.data()['day'], '2026-05-03');
    expect(stored.docs.single.data()['type'], 'hotel');

    // ── Edit it ──
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Details (e.g. 1 bed)'), '2 Beds');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('2 Beds'), findsOneWidget);

    // ── Remove it ──
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(find.text('Hilton, Times Square'), findsNothing);
  });

  testWidgets('Add Flight opens the flight search flow', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = _service(firestore);
    await service.addDay('nyc', DateTime(2026, 5, 3));

    await tester.pumpWidget(
      makeTestableWidget(ScheduleBuilderPage(group: _nycGroup(), service: service)),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add Flight'));
    await tester.tap(find.text('Add Flight'));
    await tester.pumpAndSettle();

    expect(find.byType(itinerary_builder), findsOneWidget);
  });

  testWidgets('Plan Itinerary shows setup first; backing out lands on the Schedule Builder',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = _service(firestore);

    // A launcher route underneath, standing in for the trip page.
    await tester.pumpWidget(makeTestableWidget(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => PlanItineraryPage(group: _nycGroup(), service: service)),
          ),
          child: const Text('Plan Itinerary'),
        ),
      ),
    )));

    // ── First time: the original origin → destination → dates flow ──
    await tester.tap(find.text('Plan Itinerary'));
    await tester.pumpAndSettle();
    expect(find.byType(itinerary_builder), findsOneWidget);
    expect(find.byType(ScheduleBuilderPage), findsNothing);

    // ── Backing out of setup turns the screen into the Schedule Builder ──
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleBuilderPage), findsOneWidget);
    expect(find.byType(itinerary_builder), findsNothing);
    expect(await service.hasStartedItinerary('nyc'), isTrue);

    // ── Back again returns to the trip page; next time it's straight to the builder ──
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan Itinerary'));
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleBuilderPage), findsOneWidget);
    expect(find.byType(itinerary_builder), findsNothing);
  });

  testWidgets('Removing a day also removes its items', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = _service(firestore);
    await service.addDay('nyc', DateTime(2026, 5, 3));
    await service.addItem('nyc',
        dayKey: '2026-05-03', type: ScheduleItemType.activity, title: 'Empire State Building');

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
    expect(find.text('No days planned yet. Add a day to start the schedule.'), findsOneWidget);
    final items = await firestore.collection('groups').doc('nyc').collection('scheduleItems').get();
    expect(items.docs, isEmpty);
  });
}
