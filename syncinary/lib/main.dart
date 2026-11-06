import 'package:flutter/material.dart';
import 'app.dart';
import 'services/theme_preference_service.dart';
import 'theme/theme_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final themeController = ThemeController(service: ThemePreferenceService());
  await themeController.load();
  runApp(MyApp(themeController: themeController));
}
