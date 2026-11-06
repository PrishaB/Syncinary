import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/services/theme_preference_service.dart';

import '../helpers/fake_theme_preferences.dart';

void main() {
  test('[N302-2] appearance persists across service instances', () async {
    final preferences = FakeThemePreferences();
    preferences.values['unrelated'] = 'keep';
    final service = ThemePreferenceService(preferences: preferences);
    expect(await service.load(), ThemeMode.dark);

    await service.save(ThemeMode.light);
    expect(
      await ThemePreferenceService(preferences: preferences).load(),
      ThemeMode.light,
    );
    await service.save(ThemeMode.dark);
    expect(
      await ThemePreferenceService(preferences: preferences).load(),
      ThemeMode.dark,
    );
    expect(preferences.values['unrelated'], 'keep');
  });

  test('[N302-2] unrecognized appearance falls back to dark', () async {
    final preferences = FakeThemePreferences();
    preferences.values['theme_mode'] = 'unknown';
    expect(
      await ThemePreferenceService(preferences: preferences).load(),
      ThemeMode.dark,
    );
  });
}
