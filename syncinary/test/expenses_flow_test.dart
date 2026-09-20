import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syncinary/models/expense.dart';
import 'package:syncinary/models/group.dart';
import 'package:syncinary/pages/trip_expenses_page.dart';
import 'package:syncinary/services/expense_service.dart';
import 'package:syncinary/theme/app_theme.dart';

Widget makeTestableWidget(Widget child) {
  return MaterialApp(theme: buildAppTheme(), home: child);
}

/// Seeds the fake Firestore `users` collection and returns an [ExpenseService]
/// wired to fakes, with "me" already signed in as the given user.
Future<ExpenseService> seedService(
  FakeFirebaseFirestore firestore, {
  required String uid,
  required String email,
  required String username,
}) async {
  await firestore.collection('users').doc(uid).set({
    'username': username,
    'email': email,
  });
  final auth = MockFirebaseAuth(
    mockUser: MockUser(uid: uid, email: email, displayName: username),
    signedIn: true,
  );
  return ExpenseService(firestore: firestore, auth: auth);
}

Group _baliGroup() => Group(
      id: 'bali',
      name: 'Bali Trip 2026',
      members: [
        GroupMember(id: 'me-uid', username: 'You', email: 'me@syncinary.app', role: GroupRole.admin),
        GroupMember(
            id: 'alex-uid', username: 'Alex Chen', email: 'alex@syncinary.app', role: GroupRole.user),
      ],
    );

void main() {
  testWidgets('Add and delete expenses from the Trip Expenses page', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = await seedService(
      firestore,
      uid: 'me-uid',
      email: 'me@syncinary.app',
      username: 'You',
    );

    await tester.pumpWidget(
      makeTestableWidget(TripExpensesPage(group: _baliGroup(), service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cost Splitter'), findsOneWidget);
    expect(find.text('No expenses yet.'), findsOneWidget);
    expect(find.text('\$0.00'), findsOneWidget);

    // ── By-person panel lists both members with nothing added yet ──
    expect(find.text('You: \$0.00'), findsOneWidget);
    expect(find.text('Alex Chen: \$0.00'), findsOneWidget);
    expect(find.text('0%'), findsNWidgets(2));

    // ── Empty submission shows a validation error ──
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name and a valid cost.'), findsOneWidget);

    // ── Add a valid expense ──
    await tester.enterText(find.widgetWithText(TextField, 'Expense Name'), 'Flight 87');
    await tester.enterText(find.widgetWithText(TextField, 'Cost'), '600');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Flight 87: \$600.00'), findsOneWidget);
    expect(find.text('No expenses yet.'), findsNothing);

    // ── Total is owed entirely by whoever added it, not split evenly ──
    expect(find.text('\$600.00'), findsOneWidget);
    expect(find.text('You: \$600.00'), findsOneWidget);
    expect(find.text('Alex Chen: \$0.00'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);

    // ── Delete it (admin can delete anyone's expense) ──
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Flight 87"?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmation_dialog_confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Flight 87: \$600.00'), findsNothing);
    expect(find.text('No expenses yet.'), findsOneWidget);
  });

  testWidgets('Split an expense evenly among selected members via the dropdown',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = await seedService(
      firestore,
      uid: 'me-uid',
      email: 'me@syncinary.app',
      username: 'You',
    );

    await tester.pumpWidget(
      makeTestableWidget(TripExpensesPage(group: _baliGroup(), service: service)),
    );
    await tester.pumpAndSettle();

    // ── Switch the "Split cost" dropdown to "Split Evenly With..." ──
    await tester.tap(find.text('Just Me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Split Evenly With...'));
    await tester.pumpAndSettle();

    // Both members are preselected by default in the picker dialog.
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Alex Chen'), findsOneWidget);
    await tester.tap(find.text('Confirm Selection'));
    await tester.pumpAndSettle();

    expect(find.text('Splitting with: You, Alex Chen'), findsOneWidget);

    // ── Add an expense while split-evenly mode is active ──
    await tester.enterText(find.widgetWithText(TextField, 'Expense Name'), 'Boba');
    await tester.enterText(find.widgetWithText(TextField, 'Cost'), '10');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Boba: \$10.00'), findsOneWidget);
    expect(find.text('You: \$5.00'), findsOneWidget);
    expect(find.text('Alex Chen: \$5.00'), findsOneWidget);
    expect(find.text('50%'), findsNWidgets(2));
  });

  test('addExpense writes a document with the current user as author', () async {
    final firestore = FakeFirebaseFirestore();
    final service = await seedService(
      firestore,
      uid: 'me-uid',
      email: 'me@syncinary.app',
      username: 'You',
    );

    await service.addExpense('bali', name: 'Hotel x4 Nights', amount: 2000, splitWith: [
      'me-uid',
    ]);

    final docs = await firestore.collection('groups').doc('bali').collection('expenses').get();
    expect(docs.docs, hasLength(1));
    final expense = Expense.fromDoc(docs.docs.first);
    expect(expense.name, 'Hotel x4 Nights');
    expect(expense.amount, 2000);
    expect(expense.addedBy, 'me-uid');
    expect(expense.addedByUsername, 'You');
    expect(expense.splitWith, ['me-uid']);
  });

  test('addExpense records a custom splitWith list', () async {
    final firestore = FakeFirebaseFirestore();
    final service = await seedService(
      firestore,
      uid: 'me-uid',
      email: 'me@syncinary.app',
      username: 'You',
    );

    await service.addExpense(
      'bali',
      name: 'Group Dinner',
      amount: 100,
      splitWith: ['me-uid', 'alex-uid'],
    );

    final docs = await firestore.collection('groups').doc('bali').collection('expenses').get();
    final expense = Expense.fromDoc(docs.docs.single);
    expect(expense.splitWith, ['me-uid', 'alex-uid']);
  });

  test('Expense.fromDoc falls back to [addedBy] when splitWith is missing', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('groups').doc('bali').collection('expenses').doc('old').set({
      'name': 'Legacy Expense',
      'amount': 42,
      'addedBy': 'me-uid',
      'addedByUsername': 'You',
    });

    final doc =
        await firestore.collection('groups').doc('bali').collection('expenses').doc('old').get();
    final expense = Expense.fromDoc(doc);
    expect(expense.splitWith, ['me-uid']);
  });

  test('deleteExpense removes the document from Firestore', () async {
    final firestore = FakeFirebaseFirestore();
    final service = await seedService(
      firestore,
      uid: 'me-uid',
      email: 'me@syncinary.app',
      username: 'You',
    );

    await service.addExpense('bali', name: 'Empire State Tour', amount: 50, splitWith: [
      'me-uid',
    ]);
    final before =
        await firestore.collection('groups').doc('bali').collection('expenses').get();
    final expenseId = before.docs.single.id;

    await service.deleteExpense('bali', expenseId);

    final after = await firestore.collection('groups').doc('bali').collection('expenses').get();
    expect(after.docs, isEmpty);
  });
}
