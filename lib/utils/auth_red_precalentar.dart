import 'dart:async';
import 'dart:io';

import 'package:angostura_digital/firebase_options.dart';
import 'package:angostura_digital/utils/app_check_config.dart';
import 'package:flutter/foundation.dart';

/// Precalienta TLS y DNS hacia los servicios de Firebase (útil en 4G frío).
Future<void> precalentarRedFirebase() async {
  final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
  final urls = [
    'https://identitytoolkit.googleapis.com/v1/projects?key=$apiKey',
    'https://firestore.googleapis.com/',
    'https://firebaseappcheck.googleapis.com/',
  ];

  await Future.wait(urls.map(_headRequest));
}

Future<void> _headRequest(String url) async {
  final client = HttpClient();
  try {
    final request = await client
        .headUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 12));
    request.followRedirects = false;
    await request.close().timeout(const Duration(seconds: 12));
  } catch (e) {
    debugPrint('Precalentar red ($url): $e');
  } finally {
    client.close(force: true);
  }
}

/// App Check + red antes del primer tap en login.
Future<void> precalentarLoginCompleto({
  void Function(String mensaje)? onProgreso,
}) async {
  onProgreso?.call('Preparando conexión...');
  precalentarAppCheckEnSegundoPlano();
  try {
    await Future.wait([
      asegurarAppCheckParaAuth(
        onProgreso: onProgreso,
        esperaMaxima: const Duration(seconds: 10),
      ),
      precalentarRedFirebase(),
    ]).timeout(const Duration(seconds: 12));
  } on TimeoutException {
    debugPrint('Precalentar login: tiempo máximo, se permite entrar.');
  }
}
