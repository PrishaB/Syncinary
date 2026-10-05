import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/services/airport_service.dart';
import 'package:syncinary/widgets/airport_search_field.dart';

class FakeAirportService extends AirportService {
  final requests = <String, Completer<AirportSuggestions>>{};
  @override
  Future<AirportSuggestions> search(String query) {
    return (requests[query] = Completer<AirportSuggestions>()).future;
  }
}

void main() {
  const airport = Airport(
    code: 'IND',
    name: 'Indianapolis',
    address: 'Indiana',
  );

  testWidgets(
    'debounces, selects the code, and invalidates selection when edited',
    (tester) async {
      final service = FakeAirportService();
      final controller = TextEditingController();
      Airport? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AirportSearchField(
              controller: controller,
              label: 'Origin',
              service: service,
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Indian');
      await tester.pump(const Duration(milliseconds: 200));
      expect(service.requests, isEmpty);
      await tester.pump(const Duration(milliseconds: 250));
      service.requests['Indian']!.complete(
        const AirportSuggestions([airport], 'Google Maps'),
      );
      await tester.pump();
      await tester.tap(find.text('Indianapolis (IND)'));
      await tester.pump();
      expect(selected?.code, 'IND');
      expect(controller.text, 'Indianapolis (IND)');
      await tester.enterText(find.byType(TextField), 'L');
      expect(selected, isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      service.dispose();
    },
  );

  testWidgets('ignores stale results and shows failures', (tester) async {
    final service = FakeAirportService();
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AirportSearchField(
            controller: controller,
            label: 'Origin',
            service: service,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Indian');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.enterText(find.byType(TextField), 'London');
    await tester.pump(const Duration(milliseconds: 450));
    service.requests['Indian']!.complete(
      const AirportSuggestions([airport], 'Google Maps'),
    );
    await tester.pump();
    expect(find.text('Indianapolis (IND)'), findsNothing);
    service.requests['London']!.completeError(Exception('offline'));
    await tester.pump();
    expect(find.textContaining('Suggestions unavailable'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    service.dispose();
  });
}
