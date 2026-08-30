import 'package:flutter/material.dart';
import 'pages/itinerary_builder.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Syncinary',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const itinerary_builder(),
    );
  }
}