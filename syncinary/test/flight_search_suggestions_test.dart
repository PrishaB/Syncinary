import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:syncinary/pages/flight_search.dart';
import 'package:syncinary/services/recommendation_service.dart';
import 'package:syncinary/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(theme: buildAppTheme(), home: child);

final _sampleFlights = [
  {
    'price': '250',
    'flights': [
      {
        'departure_airport': {'id': 'JFK', 'time': '2026-10-01 08:00'},
        'arrival_airport': {'id': 'LAX'},
      },
    ],
  },
];

const _context = SearchContext(origin: 'JFK', destination: 'LAX', departureDate: '2026-10-01');

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

Map<String, dynamic> _emptyDestinationsBody() => {
      'ok': true,
      'data': {
        'summary': 'Not enough to go on yet.',
        'destinations': [],
        'activities': [],
        'itinerary': [],
        'assumptions': [],
        'warnings': [],
      },
    };

void main() {
  testWidgets('shows a loading state while flight cards render underneath', (tester) async {
    final completer = Completer<http.Response>();
    final client = MockClient((request) => completer.future);
    final service = RecommendationService(client: client, idTokenProvider: () async => null);

    await tester.pumpWidget(_wrap(flight_search(
      title: 'Flight Results',
      origin: 'JFK',
      destination: 'LAX',
      departureDate: '2026-10-01',
      initialResults: _sampleFlights,
      recommendationService: service,
      searchContext: _context,
    )));
    await tester.pump();

    expect(find.byKey(const Key('suggestions-loading')), findsOneWidget);
    expect(find.text('JFK  →  LAX'), findsOneWidget);

    // Resolve and let the pending .timeout() timer get cancelled so the test
    // doesn't end with a Timer still pending under FakeAsync.
    completer.complete(http.Response(jsonEncode(_successBody()), 200));
    await tester.pump();
  });

  testWidgets('shows the summary and destination on success', (tester) async {
    final client = MockClient((request) async => http.Response(jsonEncode(_successBody()), 200));
    final service = RecommendationService(client: client, idTokenProvider: () async => null);

    await tester.pumpWidget(_wrap(flight_search(
      title: 'Flight Results',
      origin: 'JFK',
      destination: 'LAX',
      departureDate: '2026-10-01',
      initialResults: _sampleFlights,
      recommendationService: service,
      searchContext: _context,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('suggestions-success')), findsOneWidget);
    expect(find.text('A quick west-coast trip.'), findsOneWidget);
    expect(find.textContaining('Los Angeles'), findsOneWidget);
    expect(find.textContaining('~\$450/person'), findsOneWidget);
  });

  testWidgets('shows the empty state for zero destinations', (tester) async {
    final client =
        MockClient((request) async => http.Response(jsonEncode(_emptyDestinationsBody()), 200));
    final service = RecommendationService(client: client, idTokenProvider: () async => null);

    await tester.pumpWidget(_wrap(flight_search(
      title: 'Flight Results',
      origin: 'JFK',
      destination: 'LAX',
      departureDate: '2026-10-01',
      initialResults: _sampleFlights,
      recommendationService: service,
      searchContext: _context,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('suggestions-empty')), findsOneWidget);
  });

  testWidgets('shows the empty state for an empty_payload failure, not the error state', (tester) async {
    final client = MockClient((request) async => http.Response(
          jsonEncode({'ok': false, 'error': 'empty_payload', 'message': 'nothing to recommend from'}),
          200,
        ));
    final service = RecommendationService(client: client, idTokenProvider: () async => null);

    await tester.pumpWidget(_wrap(flight_search(
      title: 'Flight Results',
      origin: 'JFK',
      destination: 'LAX',
      departureDate: '2026-10-01',
      initialResults: _sampleFlights,
      recommendationService: service,
      searchContext: _context,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('suggestions-empty')), findsOneWidget);
    expect(find.byKey(const Key('suggestions-error')), findsNothing);
  });

  testWidgets('shows an error state with Retry, which re-fetches and can succeed', (tester) async {
    var callCount = 0;
    final client = MockClient((request) async {
      callCount++;
      if (callCount == 1) {
        return http.Response(
          jsonEncode({'ok': false, 'error': 'upstream_error', 'message': 'Gemini returned status 500'}),
          200,
        );
      }
      return http.Response(jsonEncode(_successBody()), 200);
    });
    final service = RecommendationService(client: client, idTokenProvider: () async => null);

    await tester.pumpWidget(_wrap(flight_search(
      title: 'Flight Results',
      origin: 'JFK',
      destination: 'LAX',
      departureDate: '2026-10-01',
      initialResults: _sampleFlights,
      recommendationService: service,
      searchContext: _context,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('suggestions-error')), findsOneWidget);
    expect(find.text("Couldn't load suggestions."), findsOneWidget);

    await tester.tap(find.byKey(const Key('suggestions-retry')));
    await tester.pumpAndSettle();

    expect(callCount, 2);
    expect(find.byKey(const Key('suggestions-success')), findsOneWidget);
  });

  testWidgets('shows no suggestions section when no service is passed (regression)', (tester) async {
    await tester.pumpWidget(_wrap(const flight_search(
      title: 'Flight Results',
      origin: 'JFK',
      destination: 'LAX',
      departureDate: '2026-10-01',
      initialResults: [],
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('suggestions-loading')), findsNothing);
    expect(find.byKey(const Key('suggestions-empty')), findsNothing);
    expect(find.byKey(const Key('suggestions-success')), findsNothing);
    expect(find.text('No flights found.'), findsOneWidget);
  });

  testWidgets('renders flight cards unaffected when a service is passed', (tester) async {
    final client = MockClient((request) async => http.Response(jsonEncode(_successBody()), 200));
    final service = RecommendationService(client: client, idTokenProvider: () async => null);

    await tester.pumpWidget(_wrap(flight_search(
      title: 'Flight Results',
      origin: 'JFK',
      destination: 'LAX',
      departureDate: '2026-10-01',
      initialResults: _sampleFlights,
      recommendationService: service,
      searchContext: _context,
    )));
    await tester.pumpAndSettle();

    expect(find.text('JFK  →  LAX'), findsOneWidget);
    expect(find.text('\$250'), findsOneWidget);
  });

  testWidgets('renders suggestions above the "No flights found" message', (tester) async {
    final client = MockClient((request) async => http.Response(jsonEncode(_successBody()), 200));
    final service = RecommendationService(client: client, idTokenProvider: () async => null);

    await tester.pumpWidget(_wrap(flight_search(
      title: 'Flight Results',
      origin: 'JFK',
      destination: 'LAX',
      departureDate: '2026-10-01',
      initialResults: const [],
      recommendationService: service,
      searchContext: _context,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('suggestions-success')), findsOneWidget);
    expect(find.text('No flights found.'), findsOneWidget);

    final suggestionsY = tester.getTopLeft(find.byKey(const Key('suggestions-success'))).dy;
    final noFlightsY = tester.getTopLeft(find.text('No flights found.')).dy;
    expect(suggestionsY, lessThan(noFlightsY));
  });
}
