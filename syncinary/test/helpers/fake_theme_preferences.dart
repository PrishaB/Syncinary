import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

// This test double deliberately exposes mutable storage failures and delays.
// ignore: must_be_immutable
class FakeThemePreferences implements SharedPreferencesAsync {
  final values = <String, String>{};
  final writes = <String>[];
  Completer<void>? pendingWrite;
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<String?> getString(String key) async {
    if (failReads) throw StateError('Storage unavailable');
    return values[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    writes.add(value);
    await pendingWrite?.future;
    if (failWrites) throw StateError('Storage unavailable');
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
