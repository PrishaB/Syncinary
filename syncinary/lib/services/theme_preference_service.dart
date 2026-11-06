import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores appearance on this device, independently of the signed-in account.
class ThemePreferenceService {
  ThemePreferenceService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;
  static const _key = 'theme_mode';

  Future<ThemeMode> load() async {
    return await _preferences.getString(_key) == 'light'
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  Future<void> save(ThemeMode mode) => _preferences.setString(_key, mode.name);
}
