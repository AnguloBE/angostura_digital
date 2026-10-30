import 'dart:async';

import 'package:flutter/foundation.dart';

/// Ejecuta [future] con límite de tiempo; si vence, retorna null (no lanza).
Future<T?> conTimeoutRed<T>(
  Future<T> future, {
  Duration limite = const Duration(seconds: 5),
}) async {
  try {
    return await future.timeout(limite);
  } on TimeoutException {
    return null;
  } catch (_) {
    return null;
  }
}

/// Reintenta una operación de red con timeout por intento (útil en 4G lento).
Future<T> reintentarConTimeout<T>(
  Future<T> Function() operacion, {
  int intentos = 4,
  Duration limitePorIntento = const Duration(seconds: 60),
  Duration pausaBase = const Duration(seconds: 2),
  void Function(int intento, int total)? onProgreso,
  Future<void> Function(int intento)? antesDeReintento,
}) async {
  Object? ultimoError;
  for (var i = 1; i <= intentos; i++) {
    onProgreso?.call(i, intentos);
    try {
      return await operacion().timeout(
        limitePorIntento,
        onTimeout: () => throw TimeoutException('intento $i de $intentos'),
      );
    } catch (e) {
      ultimoError = e;
      if (i < intentos) {
        await antesDeReintento?.call(i + 1);
        await Future.delayed(pausaBase * i);
      }
    }
  }

  if (ultimoError is TimeoutException) {
    throw TimeoutException(
      'No se pudo conectar con Firebase. La señal es débil; espera un momento e intenta de nuevo.',
    );
  }
  Error.throwWithStackTrace(ultimoError!, StackTrace.current);
}

/// Espera [future] en tramos sin lanzar otra petición si el timeout de Dart vence.
/// En 4G, signInWithCredential puede tardar pero la petición nativa sigue viva.
Future<T> esperarMismaPeticion<T>(
  Future<T> future, {
  int tramos = 6,
  Duration duracionTramo = const Duration(seconds: 30),
  void Function(int tramo, int total)? onProgreso,
}) async {
  for (var i = 1; i <= tramos; i++) {
    onProgreso?.call(i, tramos);
    try {
      return await future.timeout(duracionTramo);
    } on TimeoutException {
      if (i == tramos) {
        throw TimeoutException(
          'No se pudo conectar con Firebase. La señal es débil; espera un momento e intenta de nuevo.',
        );
      }
      debugPrint('Red lenta: esperando misma petición ($i/$tramos)...');
    }
  }
  throw StateError('esperarMismaPeticion: tramos agotados');
}

/// Igual que [conTimeoutRed] pero ignora el resultado (fire-and-forget seguro).
void enSegundoPlano(
  Future<void> future, {
  Duration limite = const Duration(seconds: 8),
}) {
  unawaited(
    future.timeout(limite, onTimeout: () {}).catchError((_) {}),
  );
}
