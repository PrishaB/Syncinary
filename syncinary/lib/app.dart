import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/auth_gate.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.themeController, this.home});

  final ThemeController themeController;
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: themeController,
      child: ListenableBuilder(
        listenable: themeController,
        builder: (context, child) => MaterialApp(
          title: 'Syncinary',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(brightness: Brightness.light),
          darkTheme: buildAppTheme(),
          themeMode: themeController.mode,
          home: child,
        ),
        child: home ?? const AuthGate(),
      ),
    );
  }
}
