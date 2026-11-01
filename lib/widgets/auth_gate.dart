import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:angostura_digital/screens/app_shell.dart';
import 'package:angostura_digital/services/firebase_service.dart';

/// Abre la app directo. Si no hay cuenta, entra como invitado.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _intentado = false;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        AuthService().asegurarInvitado();
      }
    });
    _arrancar();
  }

  Future<void> _arrancar() async {
    try {
      await FirebaseAuth.instance.setLanguageCode('es');
    } catch (_) {}
    await AuthService().asegurarInvitado();
    if (mounted) setState(() => _intentado = true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
        if (user == null && !_intentado) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return AppShell(key: ValueKey(user?.uid ?? 'invitado'));
      },
    );
  }
}
