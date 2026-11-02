import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/models/expense.dart';
import 'package:syncinary/models/group.dart';
import 'package:syncinary/pages/trip_expenses_page.dart';
import 'package:syncinary/services/expense_service.dart';
import 'package:syncinary/theme/app_theme.dart';

import 'expenses_flow_test.dart' show makeTestableWidget, seedService;

Group _group({int count = 2}) => Group(
  id: 'bali',
  name: 'Bali',
  members: [
    GroupMember(
      id: 'me-uid',
      username: 'You',
      email: 'me@example.com',
      role: GroupRole.admin,
    ),
    if (count > 1)
      GroupMember(
        id: 'alex-uid',
        username: 'Alex',
        email: 'alex@example.com',
        role: GroupRole.user,
      ),
    for (var i = 2; i < count; i++)
      GroupMember(
        id: 'member-$i',
        username: 'Member $i',
        email: '$i@example.com',
        role: GroupRole.user,
      ),
  ],
);

Future<({FakeFirebaseFirestore firestore, ExpenseService service})> _openPage(
  WidgetTester tester, {
  int count = 2,
  Size size = const Size(1200, 1000),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final firestore = FakeFirebaseFirestore();
  final service = await seedService(
    firestore,
    uid: 'me-uid',
    email: 'me@example.com',
    username: 'You',
  );
  await tester.pumpWidget(
    makeTestableWidget(
      TripExpensesPage(
        group: _group(count: count),
        service: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (firestore: firestore, service: service);
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> _percent(WidgetTester tester, String id, String value) async {
  final field = find.byKey(ValueKey('split_percentage_$id'));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

String _percentageText(WidgetTester tester, String id) => tester
    .widget<TextField>(find.byKey(ValueKey('split_percentage_$id')))
    .controller!
    .text;

Future<void> _item(WidgetTester tester, String name, String cost) async {
  await tester.enterText(find.widgetWithText(TextField, 'Expense Name'), name);
  await tester.enterText(find.widgetWithText(TextField, 'Cost'), cost);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    '[103-1] decimal percentage shares preview, persist, and combine with presets',
    (tester) async {
      final fixture = await _openPage(tester);
      await _item(tester, 'Dinner', '80');
      await _tap(tester, 'Custom %');
      await _percent(tester, 'me-uid', '62.5');
      expect(_percentageText(tester, 'alex-uid'), '37.5');
      expect(find.text('Assigned: 100.00% / 100%'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('split_amount_me-uid')))
            .data,
        '\$50.00',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('split_amount_alex-uid')))
            .data,
        '\$30.00',
      );
      await _tap(tester, 'Add');
      final saved = (await fixture.service.expensesStream('bali').first).single;
      expect(saved.splitPercentages, {'me-uid': 62.5, 'alex-uid': 37.5});
      expect(find.text('You · 62.50% · \$50.00'), findsOneWidget);
      expect(find.text('You: \$50.00'), findsOneWidget);
      expect(find.text('Alex: \$30.00'), findsOneWidget);

      await _tap(tester, 'All me');
      await _item(tester, 'Taxi', '10');
      await _tap(tester, 'Add');
      await _tap(tester, 'Divide evenly');
      await _item(tester, 'Snacks', '10');
      await _tap(tester, 'Add');
      expect(find.text('You: \$65.00'), findsOneWidget);
      expect(find.text('Alex: \$35.00'), findsOneWidget);

      // Recreate the page to verify Firestore loading, independently of the draft.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        makeTestableWidget(
          TripExpensesPage(group: _group(), service: fixture.service),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('You: \$65.00'), findsOneWidget);
      expect(find.text('Alex: \$35.00'), findsOneWidget);
      expect(find.text('You · 62.50% · \$50.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '[103-3] invalid percentages cannot save and correcting them enables Add',
    (tester) async {
      final fixture = await _openPage(tester);
      await _item(tester, 'Dinner', '100');
      await _tap(tester, 'Custom %');
      for (final invalid in ['', 'abc', 'NaN', 'Infinity', '-1', '101']) {
        await _percent(tester, 'me-uid', invalid);
        expect(
          tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
          isNull,
        );
        expect(await fixture.service.expensesStream('bali').first, isEmpty);
        expect(tester.takeException(), isNull);
      }
      await _percent(tester, 'me-uid', '100');
      expect(
        tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
        isNotNull,
      );
      await _tap(tester, 'Add');
      expect(find.text('You: \$100.00'), findsOneWidget);
      expect(find.text('Alex: \$0.00'), findsOneWidget);
    },
  );

  testWidgets(
    '[103-1] last unedited share follows changes and can be overridden',
    (tester) async {
      final fixture = await _openPage(tester, count: 3);
      await _item(tester, 'Dinner', '100');
      await _tap(tester, 'Custom %');
      // Enter out of order; the automatic share need not be the last row.
      await _percent(tester, 'member-2', '33.33');
      expect(_percentageText(tester, 'me-uid'), '100.0');
      await _percent(tester, 'alex-uid', '33.33');
      expect(_percentageText(tester, 'me-uid'), '33.34');
      await _percent(tester, 'alex-uid', '40');
      expect(_percentageText(tester, 'me-uid'), '26.67');
      expect(_percentageText(tester, 'member-2'), '33.33');
      expect(find.text('Assigned: 100.00% / 100%'), findsOneWidget);

      // Explicitly editing the automatic share keeps all manual values.
      await _percent(tester, 'me-uid', '25');
      expect(_percentageText(tester, 'alex-uid'), '40');
      expect(_percentageText(tester, 'member-2'), '33.33');
      expect(
        tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
        isNull,
      );
      await _percent(tester, 'member-2', '35');
      await _tap(tester, 'Add');
      final saved = (await fixture.service.expensesStream('bali').first).single;
      expect(saved.splitPercentages, {
        'me-uid': 25,
        'alex-uid': 40,
        'member-2': 35,
      });
    },
  );

  testWidgets(
    '[103-3] autofill waits for valid shares and never creates a negative share',
    (tester) async {
      await _openPage(tester, count: 3);
      await _tap(tester, 'Custom %');
      await _percent(tester, 'me-uid', '80');
      for (final invalid in ['30', '-1', 'NaN', 'Infinity', 'abc']) {
        await _percent(tester, 'alex-uid', invalid);
        expect(_percentageText(tester, 'member-2'), '0.0');
        expect(
          tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
          isNull,
        );
      }
      await _percent(tester, 'alex-uid', '20');
      expect(_percentageText(tester, 'member-2'), '0');
      expect(find.text('Assigned: 100.00% / 100%'), findsOneWidget);
      await _percent(tester, 'me-uid', '0');
      await _percent(tester, 'alex-uid', '0');
      expect(_percentageText(tester, 'member-2'), '100');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '[103-1] clearing a share or selecting a preset allows autofill again',
    (tester) async {
      await _openPage(tester);
      await _tap(tester, 'Custom %');
      await _percent(tester, 'me-uid', '60');
      await _percent(tester, 'alex-uid', '40');
      await _percent(tester, 'alex-uid', '');
      expect(_percentageText(tester, 'alex-uid'), isEmpty);
      await _percent(tester, 'me-uid', '65');
      expect(_percentageText(tester, 'alex-uid'), '35');

      await _tap(tester, 'Divide evenly');
      await _tap(tester, 'Custom %');
      await _percent(tester, 'alex-uid', '25');
      expect(_percentageText(tester, 'me-uid'), '75');
      await _tap(tester, 'All me');
      await _tap(tester, 'Custom %');
      await _percent(tester, 'me-uid', '30');
      expect(_percentageText(tester, 'alex-uid'), '70');
    },
  );

  testWidgets(
    '[103-1] equal subset selection and custom thirds work without rounding gaps',
    (tester) async {
      final fixture = await _openPage(tester, count: 3);
      await _tap(tester, 'Divide evenly');
      await _tap(tester, 'Custom %');
      expect(find.text('Assigned: 100.00% / 100%'), findsOneWidget);
      await _item(tester, 'Lunch', '10');
      await _tap(tester, 'Add');
      var saved = (await fixture.service.expensesStream('bali').first).single;
      expect(saved.splitPercentages, {
        'me-uid': 33.34,
        'alex-uid': 33.33,
        'member-2': 33.33,
      });
      expect(find.text('You: \$3.34'), findsOneWidget);

      await _tap(tester, 'Divide evenly');
      await _tap(tester, 'You');
      await _tap(tester, 'Member 2');
      await _tap(tester, 'Alex');
      expect(
        tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
        isNull,
      );
      await _tap(tester, 'Alex');
      await _item(tester, 'Alex ticket', '20');
      await _tap(tester, 'Add');
      saved = (await fixture.service.expensesStream('bali').first).firstWhere(
        (expense) => expense.name == 'Alex ticket',
      );
      expect(saved.splitWith, ['alex-uid']);
      expect(saved.splitPercentages, isNull);
      expect(find.text('Alex: \$23.33'), findsOneWidget);
    },
  );

  testWidgets('[103-1] eight member custom split stays usable at phone width', (
    tester,
  ) async {
    await _openPage(tester, count: 8, size: const Size(360, 640));
    await _item(tester, 'Tickets', '80');
    await _tap(tester, 'Divide evenly');
    await _tap(tester, 'Custom %');
    await _percent(tester, 'me-uid', '0');
    await _percent(tester, 'member-7', '25');
    await _tap(tester, 'Add');
    expect(find.text('Member 7: \$20.00'), findsOneWidget);
    expect(find.text('You: \$0.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('[103-4] a single member can use all split modes', (
    tester,
  ) async {
    await _openPage(tester, count: 1);
    await _tap(tester, 'Divide evenly');
    await _tap(tester, 'Custom %');
    expect(find.text('Assigned: 100.00% / 100%'), findsOneWidget);
    await _item(tester, 'Ticket', '10');
    await _tap(tester, 'Add');
    expect(find.text('You: \$10.00'), findsOneWidget);
    await _tap(tester, 'All me');
    expect(find.byKey(const ValueKey('split_percentage_me-uid')), findsNothing);
  });

  test(
    '[103-3] service rejects invalid costs and percentage allocations before writing',
    () async {
      final firestore = FakeFirebaseFirestore();
      final service = await seedService(
        firestore,
        uid: 'me-uid',
        email: 'me@example.com',
        username: 'You',
      );
      for (final percentages in <Map<String, double>>[
        {},
        {'me-uid': 50, 'alex-uid': 40},
        {'me-uid': 100},
        {'me-uid': -1, 'alex-uid': 101},
        {'me-uid': double.nan, 'alex-uid': 0},
        {'me-uid': 50, 'outsider': 50},
      ]) {
        await expectLater(
          service.addExpense(
            'bali',
            name: 'Invalid',
            amount: 100,
            splitWith: ['me-uid', 'alex-uid'],
            splitPercentages: percentages,
          ),
          throwsArgumentError,
        );
      }
      for (final amount in [0.0, -1.0, 0.001, double.nan, double.infinity]) {
        await expectLater(
          service.addExpense(
            'bali',
            name: 'Invalid',
            amount: amount,
            splitWith: ['me-uid'],
          ),
          throwsArgumentError,
        );
      }
      expect(await service.expensesStream('bali').first, isEmpty);
    },
  );

  test(
    '[103-1] legacy personal and equal expenses retain their allocation',
    () async {
      final firestore = FakeFirebaseFirestore();
      final collection = firestore
          .collection('groups')
          .doc('bali')
          .collection('expenses');
      await collection.doc('personal').set({
        'name': 'Legacy',
        'amount': 42,
        'addedBy': 'me-uid',
      });
      await collection.doc('shared').set({
        'name': 'Shared',
        'amount': 80,
        'addedBy': 'me-uid',
        'splitWith': ['me-uid', 'alex-uid'],
      });
      final personal = Expense.fromDoc(await collection.doc('personal').get());
      final shared = Expense.fromDoc(await collection.doc('shared').get());
      expect(personal.split.amountsFor(personal.amount), {'me-uid': 42});
      expect(shared.split.amountsFor(shared.amount), {
        'me-uid': 40,
        'alex-uid': 40,
      });
    },
  );
}
