import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/models/schedule.dart';
import 'package:syncinary/models/trip_location.dart';
import 'package:syncinary/services/schedule_service.dart';

void main() {
  const location = TripLocation(
    name: 'Hotel',
    address: 'NYC',
    latitude: 40.7,
    longitude: -74,
  );

  test(
    '[202-3] missing, malformed, out-of-range and nonfinite locations are unmapped',
    () {
      for (final value in [
        null,
        'NYC',
        {},
        {'latitude': '40', 'longitude': 2},
        {'latitude': 91, 'longitude': 2},
        {'latitude': 40, 'longitude': -181},
        {'latitude': double.nan, 'longitude': 2},
        {'latitude': 40, 'longitude': double.infinity},
      ]) {
        expect(TripLocation.fromMap(value), isNull);
      }
      expect(
        TripLocation.fromMap({'latitude': 0, 'longitude': 0})!.latitude,
        0,
      );
      expect(TripLocation.fromMap(location.toMap())!.address, 'NYC');
    },
  );

  test(
    '[202-4] locations persist, survive other edits, update and can be removed',
    () async {
      final db = FakeFirebaseFirestore();
      await db.collection('groups').doc('trip').set({
        'members': {
          'me': {'role': 'admin'},
        },
      });
      final service = ScheduleService(
        firestore: db,
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me')),
      );
      await service.addItem(
        'trip',
        date: DateTime(2026, 10, 25),
        type: ScheduleItemType.hotel,
        title: 'Stay',
        location: location,
      );
      var item = (await service.itemsStream('trip').first).single;
      expect(item.location!.latitude, 40.7);
      await service.updateItem(
        'trip',
        item.id,
        date: DateTime(2026, 10, 26),
        title: 'Renamed',
        details: '2 beds',
      );
      item = (await service.itemsStream('trip').first).single;
      expect(item.location!.name, 'Hotel');
      expect(item.day, '2026-10-26');
      await service.setItemLocation(
        'trip',
        item.id,
        const TripLocation(name: 'Museum', latitude: 41, longitude: -73),
      );
      item = (await service.itemsStream('trip').first).single;
      expect(item.title, 'Renamed');
      expect(item.location!.name, 'Museum');
      await service.updateItem(
        'trip',
        item.id,
        date: DateTime(2026, 10, 26),
        title: item.title,
        details: item.details,
        clearLocation: true,
      );
      expect((await service.itemsStream('trip').first).single.location, isNull);
      await service.deleteItem('trip', item.id);
      expect(await service.itemsStream('trip').first, isEmpty);
    },
  );

  test(
    '[202-3] location writes require a current signed-in trip admin',
    () async {
      final db = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'me'),
      );
      final service = ScheduleService(firestore: db, auth: auth);
      final trip = db.collection('groups').doc('trip');
      final item = trip.collection('scheduleItems').doc('stay');
      await trip.set({
        'members': {
          'me': {'role': 'admin'},
        },
      });
      await item.set({'title': 'Stay', 'details': 'Keep these details'});
      await service.setItemLocation('trip', 'stay', location);
      final before = (await item.get()).data();
      const replacement = TripLocation(
        name: 'Museum',
        latitude: 41,
        longitude: -73,
      );

      // Read the current role each time, including after an admin is demoted.
      for (final members in [
        {
          'me': {'role': 'user'},
        },
        <String, dynamic>{},
      ]) {
        await trip.set({'members': members});
        await expectLater(
          service.setItemLocation('trip', 'stay', replacement),
          throwsStateError,
        );
        expect((await item.get()).data(), before);
      }
      await trip.delete();
      await expectLater(
        service.setItemLocation('trip', 'stay', replacement),
        throwsStateError,
      );
      await trip.set({
        'members': {
          'me': {'role': 'admin'},
        },
      });
      await auth.signOut();
      await expectLater(
        service.setItemLocation('trip', 'stay', replacement),
        throwsStateError,
      );
      expect((await item.get()).data(), before);
    },
  );
}
