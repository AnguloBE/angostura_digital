import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

import 'package:angostura_digital/providers/cart_provider.dart';
import 'package:angostura_digital/services/notificaciones_service.dart';
import 'package:angostura_digital/services/firebase_service.dart';
import 'package:angostura_digital/utils/auth_plataforma.dart';
import 'package:angostura_digital/widgets/auth_gate.dart';
import 'package:angostura_digital/navigation/app_navigator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (AuthPlataforma.usaGoogle) {
    await AuthService.ensureGoogleSignInInitialized();
  }
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        title: 'Angostura Digital',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          primarySwatch: Colors.blue,
        ),
        home: const AuthGate(),
      ),
    );
  }
}
