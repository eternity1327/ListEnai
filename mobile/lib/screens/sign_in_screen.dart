import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth.dart';
import '../widgets/dialogs.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await Auth.signIn();
      widget.onSignedIn();
    } on GoogleSignInException catch (error) {
      if (mounted && error.code != GoogleSignInExceptionCode.canceled) {
        toast(context, 'Sign-in failed: ${error.description ?? error.code.name}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ListenAI', style: text.displaySmall, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'Turn lectures and meetings into lessons, quizzes and flashcards.',
                style: text.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: _busy ? null : _signIn,
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
