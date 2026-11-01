import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:flutter/foundation.dart';



/// Token de depuración registrado en Firebase Console → App Check → Debug tokens.

const _kAppCheckDebugToken = 'df653f06-61de-4819-af6f-5f43108eb199';



bool _appCheckTokenListo = false;

Future<void>? _obtencionTokenEnCurso;



bool get appCheckTokenListo => _appCheckTokenListo;



/// Activa App Check y empieza a precalentar el token en segundo plano.

Future<void> configureAppCheck() async {
  if (kIsWeb) return;

  try {

    await FirebaseAppCheck.instance

        .activate(

          providerAndroid: kDebugMode

              ? const AndroidDebugProvider(debugToken: _kAppCheckDebugToken)

              : const AndroidPlayIntegrityProvider(),

          providerApple: kDebugMode

              ? const AppleDebugProvider(debugToken: _kAppCheckDebugToken)

              : const AppleAppAttestWithDeviceCheckFallbackProvider(),

        )

        .timeout(const Duration(seconds: 10));

    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

    debugPrint('App Check: proveedor activado.');

  } catch (e) {

    debugPrint('App Check activate falló (la app sigue): $e');

    return;

  }



  precalentarAppCheckEnSegundoPlano();

}



/// Llama al abrir la pantalla de login para que el token esté listo antes del tap.

void precalentarAppCheckEnSegundoPlano() {

  if (_appCheckTokenListo) return;

  _iniciarObtencionToken();

}



/// App Check para login: **1 intento**, caché, máx. [limite] (sin bucle de reintentos).
Future<void> asegurarAppCheckParaLogin({
  void Function(String mensaje)? onProgreso,
  Duration limite = const Duration(seconds: 20),
}) async {
  if (_appCheckTokenListo) return;

  onProgreso?.call('Preparando conexión segura...');
  try {
    final token = await FirebaseAppCheck.instance
        .getToken(false)
        .timeout(
          limite,
          onTimeout: () => null,
        );
    if (token != null && token.isNotEmpty) {
      _appCheckTokenListo = true;
      debugPrint('Login App Check: token listo (${limite.inSeconds}s máx).');
    } else {
      debugPrint('Login App Check: sin token en ${limite.inSeconds}s; Auth continúa.');
    }
  } catch (e) {
    debugPrint('Login App Check: $e');
  }
}

/// Espera a que App Check tenga token (máx. [esperaMaxima]) antes de Auth.

Future<void> asegurarAppCheckParaAuth({

  void Function(String mensaje)? onProgreso,

  Duration esperaMaxima = const Duration(seconds: 20),

}) async {

  if (_appCheckTokenListo) return;



  onProgreso?.call('Preparando conexión segura...');

  try {

    await _iniciarObtencionToken().timeout(esperaMaxima);

  } on TimeoutException {

    debugPrint('App Check: espera máxima ($esperaMaxima); Auth continúa.');

  }

}



/// Fuerza un nuevo intento de token (p. ej. antes de reintentar Auth).

Future<void> refrescarAppCheckSiFalta() async {

  if (_appCheckTokenListo) return;

  _obtencionTokenEnCurso = null;

  try {

    await _iniciarObtencionToken().timeout(const Duration(seconds: 15));

  } on TimeoutException {

    debugPrint('App Check: refresh sin token a tiempo.');

  }

}



Future<void> _iniciarObtencionToken() {

  _obtencionTokenEnCurso ??= _obtenerTokenAppCheck();

  return _obtencionTokenEnCurso!;

}



Future<void> _obtenerTokenAppCheck() async {

  if (_appCheckTokenListo) return;



  try {

    for (var intento = 1; intento <= 3; intento++) {

      try {

        var token = await FirebaseAppCheck.instance

            .getToken(false)

            .timeout(
              const Duration(seconds: 2),
              onTimeout: () => null,
            );

        token ??= await FirebaseAppCheck.instance

            .getToken(true)

            .timeout(const Duration(seconds: 12));



        if (token != null && token.isNotEmpty) {

          _appCheckTokenListo = true;

          debugPrint('App Check: token listo (intento $intento).');

          return;

        }

      } catch (e) {

        debugPrint('App Check token intento $intento: $e');

        if (intento < 3) {

          await Future.delayed(Duration(seconds: intento * 2));

        }

      }

    }

    debugPrint('App Check: sigue sin token; Auth reintentará.');

  } finally {

    // Permite volver a pedir token si este ciclo falló.

    if (!_appCheckTokenListo) {

      _obtencionTokenEnCurso = null;

    }

  }

}


