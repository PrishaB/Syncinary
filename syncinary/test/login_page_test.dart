import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syncinary/pages/login_page.dart';

/// Helper to wrap any widget in a MaterialApp for testing.
Widget makeTestableWidget(Widget child) {
  return MaterialApp(
    home: child,
  );
}

void main() {
  testWidgets('Renders email and password fields', (tester) async {
    await tester.pumpWidget(makeTestableWidget(const LoginPage()));
    await tester.pumpAndSettle(); // let animations complete

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Syncinary'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('Shows error for empty email', (tester) async {
    await tester.pumpWidget(makeTestableWidget(const LoginPage()));
    await tester.pumpAndSettle();

    // Tap Sign In with empty fields
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email'), findsOneWidget);
  });

  testWidgets('Shows error for invalid email format', (tester) async {
    await tester.pumpWidget(makeTestableWidget(const LoginPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'notanemail');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');

    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email'), findsOneWidget);
  });

  testWidgets('Shows error for short password', (tester) async {
    await tester.pumpWidget(makeTestableWidget(const LoginPage()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'test@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'abcefgh');

    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
  });
}
