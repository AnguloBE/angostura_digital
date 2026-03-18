import 'package:angostura_digital/screens/anuncios_screen.dart';
import 'package:angostura_digital/screens/login_screen.dart'; // Asegúrate de crear este archivo
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Angostura Digital',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
      ),
      // Aquí está el truco: el StreamBuilder escucha los cambios de sesión
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Mientras Firebase está verificando si hay una sesión activa...
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          // Si el snapshot tiene datos, significa que el usuario está logueado
          if (snapshot.hasData) {
            return const AnunciosScreen();
          }
          
          // Si no hay datos, el usuario no ha iniciado sesión
          return const LoginScreen();
        },
      ),
    );
  }
}