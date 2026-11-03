import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/sign_in_screen.dart';
import 'services/auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Auth.init();
  runApp(const ListenAIApp());
}

class ListenAIApp extends StatefulWidget {
  const ListenAIApp({super.key});

  @override
  State<ListenAIApp> createState() => _ListenAIAppState();
}

class _ListenAIAppState extends State<ListenAIApp> {
  Future<void> _signOut() async {
    await Auth.signOut();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ListenAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: Auth.signedIn
          ? HomeScreen(onSignOut: _signOut)
          : SignInScreen(onSignedIn: () => setState(() {})),
    );
  }
}
