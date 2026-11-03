import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() => runApp(const ListenAIApp());

class ListenAIApp extends StatelessWidget {
  const ListenAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ListenAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}
