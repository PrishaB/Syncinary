import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syncinary/services/recommendation_service.dart';

SearchContext _context({String groupId = 'g1', List<dynamic> travelResults = const []}) =>
    SearchContext(
      origin: 'JFK',
      destination: 'LAX',
      departureDate: '2026-10-01',
      groupId: groupId,
      travelResults: travelResults,
    );

Map<String, dynamic> _successBody() => {
      'ok': true,
      'data': {
        'summary': 'A quick west-coast trip.',
        'destinations': [
          {
            'id': 'd1',
            'name': 'Los Angeles',
            'region': null,
            'rationale': 'Matches your preference for beaches.',
            'matchedPreferences': ['beaches'],
            'estimatedCostPerPerson': {'amount': 450, 'currency': 'USD'},
          },
        ],
        'activities': [],
        'itinerary': [],
        'assumptions': [],
        'warnings': [],
      },
    };

void main() {
  group('RecommendationService', () {
    test('posts to /recommendations with the expected body and auth header', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(_successBody()), 200);
      });
      final service = RecommendationService(
        client: client,
        baseUrl: 'http://test.local',
        idTokenProvider: () async => 'test-token',
      );

      await service.fetchRecommendations(_context(groupId: 'g1'));

      expect(captured!.method, 'POST');
      expect(captured!.url.toString(), 'http://test.local/recommendations');
      expect(captured!.headers['Authorization'], 'Bearer test-token');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['groupId'], 'g1');
      expect(body['search']['destination'], 'LAX');
      expect(body['search']['startDate'], '2026-10-01');
    });

    test('omits the Authorization header when there is no token', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(_successBody()), 200);
      });
      final service = RecommendationService(client: client, idTokenProvider: () async => null);

      await service.fetchRecommendations(_context());

      expect(captured!.headers.containsKey('Authorization'), isFalse);
    });

    test('reduces travel results to allow-listed fields and caps at 15', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(_successBody()), 200);
      });
      final service = RecommendationService(client: client, idTokenProvider: () async => null);

      final raw = List.generate(
        20,
        (i) => {'price': i, 'carrier': 'AA', 'secret_internal_field': 'should not leak'},
      );
      await service.fetchRecommendations(_context(travelResults: raw));

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      final sent = (body['travelResults'] as List).cast<Map<String, dynamic>>();
      expect(sent.length, 15);
      expect(sent.every((item) => !item.containsKey('secret_internal_field')), isTrue);
      expect(sent.first['carrier'], 'AA');
    });

    test('parses a successful response into a Recommendation', () async {
      final client = MockClient((request) async => http.Response(jsonEncode(_successBody()), 200));
      final service = RecommendationService(client: client, idTokenProvider: () async => null);

      final result = await service.fetchRecommendations(_context());

      expect(result, isA<RecommendationSuccess>());
      final data = (result as RecommendationSuccess).data;
      expect(data.summary, 'A quick west-coast trip.');
      expect(data.destinations.single.region, isNull);
      expect(data.destinations.single.estimatedCostPerPerson.amount, 450);
    });

    test('maps an {ok:false} response to a failure with its error code', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode({'ok': false, 'error': 'not_a_member', 'message': 'not a member'}),
            200,
          ));
      final service = RecommendationService(client: client, idTokenProvider: () async => null);

      final result = await service.fetchRecommendations(_context());

      expect(result, isA<RecommendationFailure>());
      expect((result as RecommendationFailure).error, RecommendationError.notAMember);
    });

    test('treats empty_payload as its own code, distinct from other failures', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode({'ok': false, 'error': 'empty_payload', 'message': 'nothing to recommend from'}),
            200,
          ));
      final service = RecommendationService(client: client, idTokenProvider: () async => null);

      final result = await service.fetchRecommendations(_context());

      expect((result as RecommendationFailure).error, RecommendationError.emptyPayload);
    });

    test('maps a 500 response to a failure without throwing', () async {
      final client = MockClient((request) async => http.Response('{"ok":false,"error":"upstream_error","message":"boom"}', 500));
      final service = RecommendationService(client: client, idTokenProvider: () async => null);

      final result = await service.fetchRecommendations(_context());

      expect(result, isA<RecommendationFailure>());
    });

    test('maps a 404 (route not built yet) to a failure without throwing', () async {
      final client = MockClient((request) async => http.Response('Not Found', 404));
      final service = RecommendationService(client: client, idTokenProvider: () async => null);

      final result = await service.fetchRecommendations(_context());

      expect(result, isA<RecommendationFailure>());
      expect((result as RecommendationFailure).error, RecommendationError.malformedResponse);
    });

    test('maps a non-JSON body to a failure without throwing', () async {
      final client = MockClient((request) async => http.Response('<html>not json</html>', 200));
      final service = RecommendationService(client: client, idTokenProvider: () async => null);

      final result = await service.fetchRecommendations(_context());

      expect(result, isA<RecommendationFailure>());
      expect((result as RecommendationFailure).error, RecommendationError.malformedResponse);
    });

    test('maps a schema-invalid success body to a failure without throwing', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode({
              'ok': true,
              'data': {'summary': 'oops'}, // missing destinations/activities/itinerary/...
            }),
            200,
          ));
      final service = RecommendationService(client: client, idTokenProvider: () async => null);

      final result = await service.fetchRecommendations(_context());

      expect(result, isA<RecommendationFailure>());
      expect((result as RecommendationFailure).error, RecommendationError.malformedResponse);
    });

    test('maps a timeout to a failure without throwing', () async {
      final client = MockClient((request) async {
        await Future<void>.delayed(const Duration(seconds: 2));
        return http.Response(jsonEncode(_successBody()), 200);
      });
      final service = RecommendationService(
        client: client,
        idTokenProvider: () async => null,
        timeout: const Duration(milliseconds: 50),
      );

      final result = await service.fetchRecommendations(_context());

      expect(result, isA<RecommendationFailure>());
      expect((result as RecommendationFailure).error, RecommendationError.unreachable);
    });
  });
}
