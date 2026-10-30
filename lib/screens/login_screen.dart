import 'dart:async';
import 'package:flutter/material.dart';
import 'package:angostura_digital/services/firebase_service.dart';
import 'package:angostura_digital/utils/auth_plataforma.dart';
import 'package:angostura_digital/utils/auth_red_precalentar.dart';
import 'package:angostura_digital/utils/red_diagnostico.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _preparandoConexion = true;
  String _mensajeEstado = '';

  @override
  void initState() {
    super.initState();
    _prepararConexion();
  }

  Future<void> _prepararConexion() async {
    unawaited(precalentarRedFirebase());
    unawaited(RedDiagnostico.ejecutar(contexto: 'login'));
    try {
      await precalentarLoginCompleto(
        onProgreso: (msg) {
          if (mounted) setState(() => _mensajeEstado = msg);
        },
      );
    } catch (_) {}
    if (mounted) {
      setState(() {
        _preparandoConexion = false;
        _mensajeEstado = '';
      });
    }
  }

  Future<void> _iniciarSesion() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _mensajeEstado = 'Iniciando...';
    });
    try {
      final cred = await AuthService().signInSegunPlataforma(
        onProgreso: (msg) {
          if (mounted) setState(() => _mensajeEstado = msg);
        },
      );
      if (!mounted) return;
      if (cred == null) {
        return;
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        _mostrarError(
          e.message ?? 'La conexión tardó demasiado. Intenta de nuevo.',
        );
      }
    } catch (e) {
      if (mounted) {
        _mostrarError('No se pudo iniciar sesión. Intenta de nuevo.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _mensajeEstado = '';
        });
      }
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
                if (_preparandoConexion) ...[
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _mensajeEstado.isNotEmpty
                        ? _mensajeEstado
                        : 'Preparando conexión...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ] else if (_isLoading) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _mensajeEstado.isNotEmpty
                        ? _mensajeEstado
                        : (esApple ? 'Conectando con Apple…' : 'Conectando con Google…'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'En zonas con señal débil puede tardar un poco más.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ] else if (esApple)
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
