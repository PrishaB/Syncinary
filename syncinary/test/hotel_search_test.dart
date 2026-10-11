import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syncinary/pages/hotel_search.dart';
import 'package:syncinary/theme/app_theme.dart';

Widget makeTestableWidget(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: child,
  );
}

Map<String, dynamic> makeHotel({
  required int number,
}) {
  return {
    'name': 'Test Hotel $number',
    'overall_rating': 4.5,
    'reviews': 100 + number,
    'hotel_class': 4,
    'rate_per_night': {
      'lowest': '\$${150 + number}',
    },
  };
}

void main() {
  testWidgets('Hotel search displays hotel information', (tester) async {
    final hotels = [
      {
        'name': 'Grand Test Hotel',
        'overall_rating': 4.7,
        'reviews': 250,
        'hotel_class': 4,
        'rate_per_night': {
          'lowest': '\$199',
        },
      }
    ];

    await tester.pumpWidget(
      makeTestableWidget(
        HotelSearch(initialResults: hotels),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Hotel Results'), findsOneWidget);
    expect(find.text('Grand Test Hotel'), findsOneWidget);
    expect(find.textContaining('4.7'), findsOneWidget);
    expect(find.textContaining('250 reviews'), findsOneWidget);
    expect(find.text('4-star hotel'), findsOneWidget);
    expect(find.text('\$199'), findsOneWidget);
  });

  testWidgets('Hotel search displays empty state', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const HotelSearch(initialResults: []),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No hotels found.'), findsOneWidget);
    expect(find.byIcon(Icons.hotel_outlined), findsOneWidget);
  });

  testWidgets('Hotel search handles more than 50 results', (tester) async {
    final hotels = List.generate(
      60,
      (index) => makeHotel(number: index),
    );

    await tester.pumpWidget(
      makeTestableWidget(
        HotelSearch(initialResults: hotels),
      ),
    );

    await tester.pumpAndSettle();

    // First hotel renders correctly.
    expect(find.text('Test Hotel 0'), findsOneWidget);
    expect(find.text('\$150'), findsOneWidget);

    // Scroll all the way to hotel 59.
    await tester.scrollUntilVisible(
      find.text('Test Hotel 59'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Test Hotel 59'), findsOneWidget);
    expect(find.text('\$209'), findsOneWidget);

    // Make sure rendering the large list did not cause an overflow/error.
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hotel search handles missing optional information', (
    tester,
  ) async {
    final hotels = [
      {
        'name': 'Simple Hotel',
      }
    ];

    await tester.pumpWidget(
      makeTestableWidget(
        HotelSearch(initialResults: hotels),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Simple Hotel'), findsOneWidget);

    // Missing rating/reviews/price should not crash the page.
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hotel search handles missing hotel name', (tester) async {
    final hotels = [
      {
        'overall_rating': 4.0,
        'rate_per_night': {
          'lowest': '\$175',
        },
      }
    ];

    await tester.pumpWidget(
      makeTestableWidget(
        HotelSearch(initialResults: hotels),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Unknown Hotel'), findsOneWidget);
    expect(find.text('\$175'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}