import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:angostura_digital/screens/login_screen.dart';
import 'package:angostura_digital/screens/app_shell.dart';

/// Cambia entre login y app según la sesión de Firebase Auth.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          return AppShell(key: ValueKey(user.uid));
        }

        return const LoginScreen(key: ValueKey('login'));
      },
    );
  }
}
