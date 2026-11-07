import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syncinary/services/place_service.dart';

void main() {
  test(
    '[202-2] searches encoded places and ignores malformed coordinates',
    () async {
      final service = PlaceService(
        client: MockClient((request) async {
          expect(request.url.path, '/places');
          expect(request.url.queryParameters['q'], 'Hotel & Spa, Paris');
          return http.Response(
            jsonEncode({
              'places': [
                {'name': 'Hotel', 'latitude': 48, 'longitude': 2.3},
                {'name': 'Missing'},
                {'latitude': 100, 'longitude': 0},
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      final places = await service.search(' Hotel & Spa, Paris ');
      expect(places.single.name, 'Hotel');
      expect(places.single.latitude, 48);
    },
  );

  test(
    '[202-3] distinguishes empty results from failed or malformed searches',
    () async {
      for (final response in [
        http.Response('{}', 200),
        http.Response('bad json', 200),
        http.Response('{}', 502),
      ]) {
        final service = PlaceService(client: MockClient((_) async => response));
        await expectLater(service.search('Paris'), throwsA(isA<Exception>()));
        service.dispose();
      }
      final service = PlaceService(
        client: MockClient((_) async => http.Response('{"places":[]}', 200)),
      );
      expect(await service.search('Paris'), isEmpty);
      service.dispose();
    },
  );
}