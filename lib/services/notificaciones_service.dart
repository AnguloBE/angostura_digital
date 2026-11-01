import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:angostura_digital/firebase_options.dart';
import 'package:angostura_digital/utils/red_timeout.dart';

const String canalPedidosId = 'pedidos';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class NotificacionesService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static bool _inicializado = false;

  static Future<void> inicializar() async {
    if (_inicializado) return;
    _inicializado = true;

    try {
      await _crearCanalAndroid();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _local.initialize(
        settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      );

      if (Platform.isAndroid) {
        final androidPlugin =
            _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final permiso = androidPlugin?.requestNotificationsPermission();
        if (permiso != null) {
          await conTimeoutRed(permiso, limite: const Duration(seconds: 5));
        }
      }

      await conTimeoutRed(
        _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        ),
        limite: const Duration(seconds: 5),
      );

      await conTimeoutRed(
        _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        ),
        limite: const Duration(seconds: 3),
      );

      FirebaseMessaging.onMessage.listen(_mostrarNotificacionLocal);

      enSegundoPlano(_guardarToken());
      _messaging.onTokenRefresh.listen((_) => enSegundoPlano(_guardarToken()));
    } catch (_) {
      _inicializado = false;
    }
  }

  static Future<void> _crearCanalAndroid() async {
    if (!Platform.isAndroid) return;
    const channel = AndroidNotificationChannel(
      canalPedidosId,
      'Pedidos',
      description: 'Avisos de pedidos nuevos y cambios de estado',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> _mostrarNotificacionLocal(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;

    await _local.show(
      id: notif.hashCode,
      title: notif.title,
      body: notif.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          canalPedidosId,
          'Pedidos',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Vuelve a registrar el token FCM del usuario actual (útil al abrir panel del negocio).
  static Future<void> refrescarToken() => _guardarToken();

  static Future<void> _guardarToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      final token = await conTimeoutRed(
        _messaging.getToken(),
        limite: const Duration(seconds: 10),
      );
      if (token == null || token.isEmpty) return;

      await conTimeoutRed(
        FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set(
          {
            'fcm_token': token,
            'fcm_actualizado': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        ),
        limite: const Duration(seconds: 6),
      );
    } catch (_) {}
  }

  static Future<void> cerrarSesion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await conTimeoutRed(
        FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set(
          {'fcm_token': FieldValue.delete()},
          SetOptions(merge: true),
        ),
        limite: const Duration(seconds: 4),
      );
    }
    await conTimeoutRed(
      _messaging.deleteToken(),
      limite: const Duration(seconds: 4),
    );
    _inicializado = false;
  }
}
