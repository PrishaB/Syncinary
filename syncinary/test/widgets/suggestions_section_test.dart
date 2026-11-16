import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:syncinary/services/recommendation_service.dart';
import 'package:syncinary/theme/app_theme.dart';
import 'package:syncinary/widgets/suggestions_section.dart';

Map<String, dynamic> _destination(String id, String name) => {
  'id': id,
  'name': name,
  'region': null,
  'rationale': 'Sunny.',
  'matchedPreferences': [],
  'estimatedCostPerPerson': {'amount': 450, 'currency': 'USD'},
};

/// Miami (d1) has a one-day itinerary; Denver (d2) has none.
RecommendationService _service() => RecommendationService(
  client: MockClient(
    (_) async => http.Response(
      jsonEncode({
        'ok': true,
        'data': {
          'summary': 'Two ideas.',
          'destinations': [
            _destination('d1', 'Miami'),
            _destination('d2', 'Denver'),
          ],
          'activities': [],
          'itinerary': [
            {
              'day': 1,
              'date': null,
              'destinationId': 'd1',
              'items': [
                {
                  'timeOfDay': 'morning',
                  'activityId': null,
                  'title': 'Beach',
                  'notes': null,
                },
              ],
            },
          ],
          'assumptions': [],
          'warnings': [],
        },
      }),
      200,
    ),
  ),
  idTokenProvider: () async => null,
);

Future<void> _pump(WidgetTester tester, {ItineraryAction? action}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: SuggestionsSection(
            service: _service(),
            searchContext: const SearchContext(groupId: 'g1'),
            itineraryAction: action,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _miami = find.byKey(const ValueKey('add-to-itinerary-d1'));

void main() {
  testWidgets('[104-5] no itineraryAction shows no add button', (tester) async {
    await _pump(tester);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets(
    '[104-5] the add button appears only for destinations with an itinerary',
    (tester) async {
      await _pump(
        tester,
        action: ItineraryAction(
          label: 'Add to itinerary',
          isAlreadyAdded: (_, _) => false,
          onAdd: (_, _) async {},
        ),
      );
      expect(find.text('Add to itinerary'), findsOneWidget);
      expect(_miami, findsOneWidget);
      expect(find.byKey(const ValueKey('add-to-itinerary-d2')), findsNothing);
    },
  );

  testWidgets(
    '[104-5] the button is busy while onAdd runs and enabled again after',
    (tester) async {
      final completer = Completer<void>();
      String? added;
      await _pump(
        tester,
        action: ItineraryAction(
          label: 'Add to itinerary',
          isAlreadyAdded: (_, _) => false,
          onAdd: (d, _) {
            added = d.name;
            return completer.future;
          },
        ),
      );

      await tester.tap(_miami);
      await tester.pump();
      expect(added, 'Miami');
      expect(tester.widget<OutlinedButton>(_miami).onPressed, isNull);
      expect(
        find.descendant(
          of: _miami,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      completer.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(_miami).onPressed, isNotNull);
      expect(
        find.descendant(
          of: _miami,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    '[104-5] an already-added destination shows a disabled "Already in itinerary"',
    (tester) async {
      await _pump(
        tester,
        action: ItineraryAction(
          label: 'Add to itinerary',
          isAlreadyAdded: (_, _) => true,
          onAdd: (_, _) async {},
        ),
      );
      expect(find.text('Already in itinerary'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(_miami).onPressed, isNull);
    },
  );
}
