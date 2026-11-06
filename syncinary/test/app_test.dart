import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/app.dart';
import 'package:syncinary/services/theme_preference_service.dart';
import 'package:syncinary/theme/app_theme.dart';
import 'package:syncinary/theme/theme_controller.dart';
import 'package:syncinary/widgets/gradient_app_bar.dart';
import 'package:syncinary/widgets/settings_panel.dart';

import 'helpers/fake_theme_preferences.dart';

class _TripDraft extends StatelessWidget {
  const _TripDraft();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const GradientAppBar(title: 'Trip draft'),
    body: Container(
      key: const Key('trip-background'),
      decoration: BoxDecoration(
        gradient: AppColors.of(context).backgroundGradient,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text('Plan your trip', style: AppTextStyles.of(context).title),
          TextField(
            decoration: AppDecorations.inputDecoration(
              context,
              label: 'Trip name',
            ),
          ),
        ],
      ),
    ),
  );
}

ThemeController _controller(FakeThemePreferences preferences) =>
    ThemeController(service: ThemePreferenceService(preferences: preferences));

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    '[N302-2] settings updates existing routes and preserves a trip draft',
    (tester) async {
      final preferences = FakeThemePreferences();
      final controller = _controller(preferences);
      addTearDown(controller.dispose);
      await controller.load();
      await tester.pumpWidget(
        MyApp(
          themeController: controller,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const _TripDraft()),
                ),
                child: const Text('Open trip'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open trip'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Paris with friends');
      await _openSettings(tester);
      expect(controller.mode, ThemeMode.dark);
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(
        Theme.of(tester.element(find.byType(SettingsPanel))).brightness,
        Brightness.light,
      );
      expect(
        tester.widget<Drawer>(find.byType(Drawer)).backgroundColor,
        AppColors.light.surface,
      );
      expect(preferences.values['theme_mode'], 'light');

      await tester.tap(find.byTooltip('Close settings'));
      await tester.pumpAndSettle();
      expect(find.text('Paris with friends'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Plan your trip')).style!.color,
        AppColors.light.textPrimary,
      );
      final decoration =
          tester
                  .widget<Container>(find.byKey(const Key('trip-background')))
                  .decoration
              as BoxDecoration;
      expect(decoration.gradient!.colors.first, AppColors.light.background);

      await _openSettings(tester);
      expect(
        tester
            .widget<SegmentedButton<ThemeMode>>(
              find.byType(SegmentedButton<ThemeMode>),
            )
            .selected,
        {ThemeMode.light},
      );
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(SettingsPanel))).brightness,
        Brightness.dark,
      );
      expect(preferences.values['theme_mode'], 'dark');
      await tester.tap(find.byTooltip('Close settings'));
      await tester.pumpAndSettle();
      expect(find.text('Paris with friends'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Open trip'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('[N302-2] saved light appearance is used on the first frame', (
    tester,
  ) async {
    final preferences = FakeThemePreferences();
    await ThemePreferenceService(
      preferences: preferences,
    ).save(ThemeMode.light);
    final controller = _controller(preferences);
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      MyApp(themeController: controller, home: const _TripDraft()),
    );
    expect(
      Theme.of(tester.element(find.byType(TextField))).brightness,
      Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '[N302-2] failed appearance save restores the theme and allows retry',
    (tester) async {
      final preferences = FakeThemePreferences()
        ..pendingWrite = Completer<void>()
        ..failWrites = true;
      final controller = _controller(preferences);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MyApp(themeController: controller, home: const _TripDraft()),
      );
      await _openSettings(tester);
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(controller.mode, ThemeMode.light);
      expect(
        tester
            .widget<SegmentedButton<ThemeMode>>(
              find.byType(SegmentedButton<ThemeMode>),
            )
            .onSelectionChanged,
        isNull,
      );
      await controller.setMode(ThemeMode.dark);
      expect(preferences.writes, ['light']);
      preferences.pendingWrite!.complete();
      await tester.pumpAndSettle();
      expect(controller.mode, ThemeMode.dark);
      expect(
        find.text('Could not save appearance. Please try again.'),
        findsOneWidget,
      );

      preferences.failWrites = false;
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(controller.mode, ThemeMode.light);
      expect(preferences.values['theme_mode'], 'light');
      expect(
        find.text('Could not save appearance. Please try again.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '[N301-4] appearance supports a narrow screen and 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final controller = _controller(FakeThemePreferences());
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MyApp(
          themeController: controller,
          home: const Scaffold(body: SettingsPanel()),
        ),
      );
      for (final label in ['Light', 'Dark']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );

  test('[N302-2] unavailable storage does not block startup', () async {
    final controller = _controller(FakeThemePreferences()..failReads = true);
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.mode, ThemeMode.dark);
  });
}
