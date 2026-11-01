import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

import 'package:angostura_digital/providers/cart_provider.dart';
import 'package:angostura_digital/services/notificaciones_service.dart';
import 'package:angostura_digital/widgets/auth_gate.dart';
import 'package:angostura_digital/navigation/app_navigator.dart';
import 'package:angostura_digital/utils/firestore_config.dart';
import 'package:angostura_digital/utils/app_check_config.dart';
import 'package:angostura_digital/utils/auth_red_precalentar.dart';
import 'package:angostura_digital/utils/red_diagnostico.dart';
import 'package:angostura_digital/services/firestore_grpc_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // No bloquear el arranque en 4G: App Check + red precalientan en segundo plano.
  unawaited(configureAppCheck().then((_) async {
    await precalentarRedFirebase();
    await RedDiagnostico.ejecutar(contexto: 'arranque');
  }));
  RedDiagnostico.iniciarMonitoreo();
  FirestoreGrpcService.iniciarReconexionAutomatica();
  await configureFirestore();
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
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          },
        ),
        theme: ThemeData(
          useMaterial3: true,
          primarySwatch: Colors.blue,
        ),
        home: const AuthGate(),
      ),
    );
  }
}
