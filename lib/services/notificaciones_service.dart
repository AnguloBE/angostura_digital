import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:angostura_digital/firebase_options.dart';

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

    await _crearCanalAndroid();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    if (Platform.isAndroid) {
      final androidPlugin =
          _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_mostrarNotificacionLocal);

    await _guardarToken();
    _messaging.onTokenRefresh.listen((_) => _guardarToken());

    _inicializado = true;
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
    if (user == null) return;

    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;

      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set(
        {
          'fcm_token': token,
          'fcm_actualizado': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  static Future<void> cerrarSesion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set(
          {'fcm_token': FieldValue.delete()},
          SetOptions(merge: true),
        );
      } catch (_) {}
    }
    try {
      await _messaging.deleteToken();
    } catch (_) {}
  }
}
