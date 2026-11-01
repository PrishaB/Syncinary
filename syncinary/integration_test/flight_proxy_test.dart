
import 'package:test/test.dart';
import 'package:syncinary/pages/amadeus_service.dart';

void main() {
  final service = AmadeusService();
  const date = '2026-12-10';

  test('Empty flight response returns an empty list', () async {
    final results = await service.searchFlights(
      origin: 'EMPTY',
      destination: 'SFO',
      departureDate: date,
    );

    expect(results, isEmpty);
  });

  test('SerpApi failure throws an exception', () async {
    await expectLater(
      service.searchFlights(
        origin: 'ERR',
        destination: 'SFO',
        departureDate: date,
      ),
      throwsException,
    );
  });
}
