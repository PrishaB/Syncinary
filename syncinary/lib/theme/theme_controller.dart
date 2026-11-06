import 'package:flutter/material.dart';

import '../services/theme_preference_service.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({required ThemePreferenceService service})
    : _service = service;

  final ThemePreferenceService _service;
  ThemeMode _mode = ThemeMode.dark;
  bool _saving = false;
  String? _error;

  ThemeMode get mode => _mode;
  bool get saving => _saving;
  String? get error => _error;

  /// Called before runApp so a saved light theme never flashes dark at startup.
  Future<void> load() async {
    try {
      _mode = await _service.load();
    } catch (_) {
      // Unavailable local storage must not prevent the app from starting.
      _mode = ThemeMode.dark;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_saving || mode == _mode || mode == ThemeMode.system) return;
    final previous = _mode;
    _mode = mode;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await _service.save(mode);
    } catch (_) {
      _mode = previous;
      _error = 'Could not save appearance. Please try again.';
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}

/// Sits above the navigator so settings dialogs can update the whole app.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;
}
