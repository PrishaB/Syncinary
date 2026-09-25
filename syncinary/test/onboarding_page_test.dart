import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/pages/itinerary_builder.dart';
import 'package:syncinary/pages/onboarding_page.dart';
import 'package:syncinary/theme/app_theme.dart';

Future<void> pumpOnboarding(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(theme: buildAppTheme(), home: const OnboardingPage()),
  );
}

Future<void> tapArrow(WidgetTester tester, String tooltip) async {
  await tester.ensureVisible(find.byTooltip(tooltip));
  await tester.tap(find.byTooltip(tooltip));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Starts on the first slide with back disabled', (tester) async {
    await pumpOnboarding(tester);

    expect(find.text('Onboarding 1'), findsOneWidget);
    expect(find.textContaining('Placeholder text'), findsOneWidget);
    expect(find.byTooltip('Next slide'), findsOneWidget);
    expect(find.byTooltip('Go to main screen'), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.arrow_back_rounded),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('Advances through all three slides and updates progress', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    for (var slide = 1; slide <= 3; slide++) {
      expect(find.text('Onboarding $slide'), findsOneWidget);
      expect(find.bySemanticsLabel('Slide $slide of 3'), findsOneWidget);
      expect(find.byType(itinerary_builder), findsNothing);
      if (slide < 3) await tapArrow(tester, 'Next slide');
    }

    expect(find.text('Onboarding 1'), findsNothing);
    expect(find.text('Onboarding 2'), findsNothing);
    expect(find.byTooltip('Next slide'), findsNothing);
    expect(find.byTooltip('Go to main screen'), findsOneWidget);
  });

  testWidgets('Can return from the last slide to the first', (tester) async {
    await pumpOnboarding(tester);
    await tapArrow(tester, 'Next slide');
    await tapArrow(tester, 'Next slide');
    await tapArrow(tester, 'Previous slide');

    expect(find.text('Onboarding 2'), findsOneWidget);
    expect(find.byTooltip('Next slide'), findsOneWidget);
    expect(find.byTooltip('Go to main screen'), findsNothing);

    await tapArrow(tester, 'Previous slide');
    expect(find.text('Onboarding 1'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.arrow_back_rounded),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('Final arrow opens the main screen and clears previous routes', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: buildAppTheme(),
        home: const Scaffold(body: Text('Earlier screen')),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const OnboardingPage()),
    );
    await tester.pumpAndSettle();

    // System back must not bypass onboarding.
    await navigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);

    await tapArrow(tester, 'Next slide');
    await tapArrow(tester, 'Next slide');
    await tapArrow(tester, 'Go to main screen');

    expect(find.byType(itinerary_builder), findsOneWidget);
    expect(find.byType(OnboardingPage, skipOffstage: false), findsNothing);
    expect(find.text('Earlier screen', skipOffstage: false), findsNothing);
    expect(navigatorKey.currentState!.canPop(), isFalse);
  });

  testWidgets('Navigation remains reachable on a small screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpOnboarding(tester);

    await tapArrow(tester, 'Next slide');
    await tapArrow(tester, 'Next slide');
    expect(find.text('Onboarding 3'), findsOneWidget);
    expect(find.byTooltip('Go to main screen').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
