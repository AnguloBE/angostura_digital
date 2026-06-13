import 'package:flutter/material.dart';
import 'package:angostura_digital/services/firebase_service.dart';
import 'package:angostura_digital/utils/auth_plataforma.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _iniciarSesion() async {
    setState(() => _isLoading = true);
    try {
      final cred = await AuthService().signInSegunPlataforma();
      if (!mounted) return;
      if (cred == null) {
        // Usuario canceló
        return;
      }
    } catch (e) {
      if (mounted) {
        _mostrarError('No se pudo iniciar sesión. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esApple = AuthPlataforma.usaApple;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  esApple ? Icons.apple : Icons.android,
                  size: 72,
                  color: esApple ? Colors.black : Colors.green.shade700,
                ),
                const SizedBox(height: 16),
                const Icon(Icons.campaign_rounded, size: 56, color: Colors.blueAccent),
                const SizedBox(height: 12),
                const Text(
                  'Angostura Digital',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  esApple
                      ? 'Inicia sesión con tu cuenta de Apple.\nDespués podrás agregar tu teléfono en el menú.'
                      : 'Inicia sesión con tu cuenta de Google.\nDespués podrás agregar tu teléfono en el menú.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
                const SizedBox(height: 40),
                if (_isLoading)
                  const CircularProgressIndicator()
                else if (esApple)
                  SignInWithAppleStyleButton(onPressed: _iniciarSesion)
                else
                  GoogleSignInButton(onPressed: _iniciarSesion),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: Colors.grey.shade400),
        ),
        icon: const Icon(Icons.g_mobiledata, size: 28, color: Colors.blue),
        label: const Text(
          'Continuar con Google',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        onPressed: onPressed,
      ),
    );
  }
}

class SignInWithAppleStyleButton extends StatelessWidget {
  const SignInWithAppleStyleButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.apple, size: 26),
        label: const Text(
          'Continuar con Apple',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
