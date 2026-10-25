import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/models/group.dart';
import 'package:syncinary/pages/schedule_builder_page.dart';
import 'package:syncinary/services/schedule_service.dart';
import 'package:syncinary/theme/app_theme.dart';

void main() {
  testWidgets(
    '[202-1] planner dialog paints during focus changes at fractional browser scale',
    (tester) async {
      tester.view.devicePixelRatio = 1.3;
      tester.view.physicalSize = const Size(2496, 1404);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final service = ScheduleService(
        firestore: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me')),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ScheduleBuilderPage(
            group: Group(id: 'trip', name: 'Trip', members: []),
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final type in ['Hotel', 'Activity', 'Flight']) {
        await tester.tap(find.text('Add $type'));
        await tester.pumpAndSettle();
        final fields = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        );
        expect(tester.getSize(fields.first).width, lessThanOrEqualTo(472));
        for (var index = 0; index < 4; index++) {
          await tester.tap(fields.at(index % 2));
          await tester.enterText(
            fields.at(index % 2),
            index.isEven ? 'Example $type' : 'Details for the itinerary',
          );
          // Check intermediate animation frames, not just the settled result.
          for (var frame = 0; frame < 12; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(tester.takeException(), isNull);
          }
        }
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }
      expect(await service.itemsStream('trip').first, isEmpty);
    },
  );
}