import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/models/schedule.dart';
import 'package:syncinary/services/recommendation_to_schedule.dart';
import 'package:syncinary/services/schedule_service.dart';

void main() {
  late FakeFirebaseFirestore db;

  ScheduleService serviceFor(String uid) => ScheduleService(
        firestore: db,
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid)),
      );

  PendingScheduleItem item(int day, String title) => PendingScheduleItem(
        date: DateTime(2026, 10, day),
        dayKey: scheduleDayKey(DateTime(2026, 10, day)),
        title: title,
        details: 'Morning',
      );

  Future<List<Map<String, dynamic>>> docs(String collection) async =>
      (await db.collection('groups/trip/$collection').get())
          .docs
          .map((d) => d.data())
          .toList();

  Future<void> add(
    List<PendingScheduleItem> items, {
    String uid = 'me',
    ScheduleItemStatus status = ScheduleItemStatus.approved,
  }) =>
      serviceFor(uid).addItems('trip', items,
          status: status, sourceDestination: 'Lisbon');

  setUp(() => db = FakeFirebaseFirestore());

  test('addItems writes every item and the days they need', () async {
    await add([item(25, 'A'), item(25, 'B'), item(26, 'C')]);

    final items = await docs('scheduleItems');
    expect(items, hasLength(3));
    expect(items.map((i) => i['day']).toSet(), {'2026-10-25', '2026-10-26'});
    final days = await db.collection('groups/trip/scheduleDays').get();
    expect(days.docs.map((d) => d.id), unorderedEquals(['2026-10-25', '2026-10-26']));
    expect(days.docs.first['date'].toDate(), DateTime(2026, 10, 25));
  });

  test('addItems keeps an existing day as it is', () async {
    await serviceFor('me').addDay('trip', DateTime(2026, 10, 25));
    await add([item(25, 'A'), item(27, 'B')]);

    final days = await db.collection('groups/trip/scheduleDays').get();
    expect(days.docs.map((d) => d.id), unorderedEquals(['2026-10-25', '2026-10-27']));
    expect(
      days.docs.firstWhere((d) => d.id == '2026-10-25')['date'].toDate(),
      DateTime(2026, 10, 25),
    );
  });

  test('addItems records who added items and with which status', () async {
    await add([item(25, 'A')], uid: 'admin');
    await add([item(25, 'B')],
        uid: 'member', status: ScheduleItemStatus.suggested);

    final items = await docs('scheduleItems');
    final byTitle = {for (final i in items) i['title']: i};
    expect(byTitle['A']!['addedBy'], 'admin');
    expect(byTitle['A']!['status'], 'approved');
    expect(byTitle['B']!['addedBy'], 'member');
    expect(byTitle['B']!['status'], 'suggested');
  });

  test('addItems tags items as AI-sourced and the model reads it back', () async {
    await add([item(25, 'A')]);

    final snap = (await db.collection('groups/trip/scheduleItems').get()).docs.single;
    expect(snap['source'], 'ai');
    expect(snap['sourceDestination'], 'Lisbon');
    expect(snap['type'], 'activity');
    expect(snap['createdAt'], isNotNull);
    final parsed = ScheduleItem.fromDoc(snap);
    expect(parsed.source, 'ai');
    expect(parsed.isFromAi, isTrue);
  });

  test('items without a source are not from AI', () async {
    await serviceFor('me').addItem('trip',
        date: DateTime(2026, 10, 25), type: ScheduleItemType.hotel, title: 'Stay');
    await db.collection('groups/trip/scheduleItems').add({'title': 'Old'});

    final snaps = (await db.collection('groups/trip/scheduleItems').get()).docs;
    for (final snap in snaps) {
      final parsed = ScheduleItem.fromDoc(snap);
      expect(parsed.source, isNull);
      expect(parsed.isFromAi, isFalse);
    }
  });

  test('addItems with no items writes nothing', () async {
    await add([]);

    expect(await docs('scheduleItems'), isEmpty);
    expect(await docs('scheduleDays'), isEmpty);
  });

  test('addItems rejects a batch over the write limit and writes nothing', () async {
    final over = [for (var i = 0; i < 499; i++) item(25 + i % 2, 'T$i')];
    expect(() => add(over), throwsArgumentError);

    expect(await docs('scheduleItems'), isEmpty);
    expect(await docs('scheduleDays'), isEmpty);
  });

  test('addItems accepts a batch of exactly the write limit', () async {
    await add([for (var i = 0; i < 498; i++) item(25 + i % 2, 'T$i')]);

    expect(await docs('scheduleItems'), hasLength(498));
    expect(await docs('scheduleDays'), hasLength(2));
  });
}
