import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // Importante para el Carrito
import 'firebase_options.dart';

import 'package:angostura_digital/screens/login_screen.dart';
import 'package:angostura_digital/screens/main_navigation.dart'; // Cambiamos AnunciosScreen por MainNavigation
import 'package:angostura_digital/providers/cart_provider.dart'; // Tu nuevo Provider
import 'package:flutter_stripe/flutter_stripe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicializa Stripe con tu clave PUBLICA (empieza con pk_test_)
  Stripe.publishableKey = 'pk_test_51TDADeFKKt6Soe1vnM1CPrMdOPnbA2CzvwIu7Do53KMyuwTaaX3lf98JM4F3ys6CVAikw2l5WlTZglanJnjeRZQK001FRM0xwC';

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Envolvemos MaterialApp con MultiProvider para manejar el estado del carrito
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        title: 'Angostura Digital',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          primarySwatch: Colors.blue,
        ),
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            
            if (snapshot.hasData) {
              // AQUÍ ESTÁ LA MAGIA: Ahora abrimos la nueva navegación en lugar de AnunciosScreen
              return const MainNavigation();
            }
            
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}