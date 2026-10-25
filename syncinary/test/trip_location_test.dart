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
}
