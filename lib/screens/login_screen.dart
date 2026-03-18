import 'package:angostura_digital/screens/anuncios_screen.dart';
import 'package:flutter/material.dart';
import 'package:angostura_digital/services/firebase_service.dart'; // Ajusta la ruta a donde guardaste el servicio
import 'package:angostura_digital/globals.dart' as globals;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Aquí podrías poner el logo de tu app en el futuro
                const Icon(
                  Icons.campaign_rounded,
                  size: 100,
                  color: Colors.blueAccent, // Puedes cambiarlo por globals.colorFondo
                ),
                const SizedBox(height: 20),
                const Text(
                  'Bienvenido a',
                  style: TextStyle(fontSize: 24, color: Colors.grey),
                ),
                const Text(
                  'Angostura Digital',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 50),
                
                // Botón de Google
                _isLoading 
                  ? const CircularProgressIndicator() 
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black87, 
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade300)
                        ),
                      ),
                      // Usamos el logo de Google nativo de Flutter (necesita estar como asset o usar un icono genérico)
                      // Para simplificar, usamos un icono de usuario por ahora
                      icon: const Icon(Icons.account_circle, color: Colors.redAccent, size: 28),
                      label: const Text(
                        'Continuar con Google',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () async {
                        setState(() {
                          _isLoading = true;
                        });

                        // Llamamos al servicio que creamos antes
                        final user = await AuthService().signInWithGoogle();

                        setState(() {
                          _isLoading = false;
                        });

                        // Si el usuario se logueó correctamente, lo mandamos a Anuncios
                        if (user != null && context.mounted) {
                          
                        } else {
                          // Opcional: Mostrar un SnackBar si falló o canceló
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Inicio de sesión cancelado o fallido')),
                            );
                          }
                        }
                      },
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}