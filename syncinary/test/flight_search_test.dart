import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syncinary/pages/flight_search.dart';
import 'package:syncinary/theme/app_theme.dart';

Widget makeTestableWidget(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: child,
  );
}

Map<String, dynamic> makeFlight({
  required int number,
}) {
  return {
    'flights': [
      {
        'departure_airport': {
          'id': 'ORD',
          'time': '2026-10-${(number % 20) + 1} 08:00',
        },
        'arrival_airport': {
          'id': 'SFO',
          'time': '2026-10-${(number % 20) + 1} 11:00',
        },
        'airline': 'Test Airline $number',
      }
    ],
    'price': 200 + number,
    'total_duration': 240,
    'booking_token': 'booking_token_$number',
  };
}

void main() {
  testWidgets('Flight search displays flight information', (tester) async {
    final flights = [
      {
        'flights': [
          {
            'departure_airport': {
              'id': 'ORD',
              'time': '2026-10-10 08:00',
            },
            'arrival_airport': {
              'id': 'SFO',
              'time': '2026-10-10 11:00',
            },
            'airline': 'United',
          }
        ],
        'price': 350,
        'total_duration': 270,
        'booking_token': 'test_token',
      }
    ];

    await tester.pumpWidget(
      makeTestableWidget(
        flight_search(
          title: 'Flight Results',
          initialResults: flights,
          origin: 'ORD',
          destination: 'SFO',
          departureDate: '2026-10-10',
          adults: 1,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Flight Results'), findsOneWidget);
    expect(find.text('ORD  →  SFO'), findsOneWidget);
    expect(find.textContaining('United'), findsOneWidget);
    expect(
      find.textContaining('Departs 2026-10-10 08:00'),
      findsOneWidget,
    );
    expect(find.text('4h 30m · Nonstop'), findsOneWidget);
    expect(find.text('\$350'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Flight search displays empty state', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const flight_search(
          title: 'Flight Results',
          initialResults: [],
          origin: 'ORD',
          destination: 'SFO',
          departureDate: '2026-10-10',
          adults: 1,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No flights found.'), findsOneWidget);
    expect(find.byIcon(Icons.flight_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Flight search handles more than 50 results', (tester) async {
    final flights = List.generate(
      60,
      (index) => makeFlight(number: index),
    );

    await tester.pumpWidget(
      makeTestableWidget(
        flight_search(
          title: 'Flight Results',
          initialResults: flights,
          origin: 'ORD',
          destination: 'SFO',
          departureDate: '2026-10-10',
          adults: 1,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify the results page successfully loads.
    expect(find.text('Flight Results'), findsOneWidget);

    // Verify the long result set is displayed using a scrollable ListView.
    expect(find.byType(ListView), findsOneWidget);

    // Verify the first result rendered correctly.
    expect(find.textContaining('Test Airline 0'), findsOneWidget);
    expect(find.text('\$200'), findsOneWidget);

    // Scroll through the long list.
    await tester.fling(
      find.byType(ListView),
      const Offset(0, -5000),
      1000,
    );

    await tester.pumpAndSettle();

    // A large result set should not cause a Flutter rendering exception.
    expect(tester.takeException(), isNull);
  });

  testWidgets('Flight search correctly displays connecting flight', (
    tester,
  ) async {
    final flights = [
      {
        'flights': [
          {
            'departure_airport': {
              'id': 'ORD',
              'time': '2026-10-10 08:00',
            },
            'arrival_airport': {
              'id': 'DEN',
              'time': '2026-10-10 10:00',
            },
            'airline': 'United',
          },
          {
            'departure_airport': {
              'id': 'DEN',
              'time': '2026-10-10 11:00',
            },
            'arrival_airport': {
              'id': 'SFO',
              'time': '2026-10-10 13:00',
            },
            'airline': 'United',
          },
        ],
        'price': 300,
        'total_duration': 300,
        'booking_token': 'test_token',
      }
    ];

    await tester.pumpWidget(
      makeTestableWidget(
        flight_search(
          title: 'Flight Results',
          initialResults: flights,
          origin: 'ORD',
          destination: 'SFO',
          departureDate: '2026-10-10',
          adults: 1,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ORD  →  SFO'), findsOneWidget);
    expect(find.text('5h · 1 stop'), findsOneWidget);
    expect(find.text('\$300'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}