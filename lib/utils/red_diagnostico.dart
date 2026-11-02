import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'package:angostura_digital/services/firestore_grpc_service.dart';

/// Resultado de una prueba de latencia a un servicio.
class RedPrueba {
  final String nombre;
  final int? ms;
  final String calidad;
  final bool ok;

  const RedPrueba({
    required this.nombre,
    required this.ms,
    required this.calidad,
    required this.ok,
  });
}

/// Informe completo de red para mostrar o registrar en consola.
class RedInforme {
  final String tipoConexion;
  final String calidadGeneral;
  final List<RedPrueba> pruebas;
  final bool appCheckOk;
  final DateTime fecha;

  const RedInforme({
    required this.tipoConexion,
    required this.calidadGeneral,
    required this.pruebas,
    required this.appCheckOk,
    required this.fecha,
  });

  bool get hayConexion => tipoConexion != 'sin conexión';

  bool get grpcOperativo => pruebaFirestore?.ok ?? false;

  RedPrueba? get pruebaFirestore =>
      pruebas.where((p) => p.nombre == 'firestore').firstOrNull;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}

/// Diagnóstico de red: tipo de conexión, latencia y calidad en consola.
class RedDiagnostico {
  RedDiagnostico._();

  static final Connectivity _connectivity = Connectivity();
  static StreamSubscription<List<ConnectivityResult>>? _suscripcion;

  static String clasificarMs(int? ms) {
    if (ms == null) return 'falló';
    if (ms < 300) return 'rápido';
    if (ms < 1200) return 'medio';
    if (ms < 5000) return 'lento';
    return 'muy lento';
  }

  static String _tipoConexionLegible(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return 'sin conexión';
    }
    final partes = <String>[];
    for (final r in results) {
      partes.add(switch (r) {
        ConnectivityResult.wifi => 'WiFi',
        ConnectivityResult.mobile => 'datos móviles',
        ConnectivityResult.ethernet => 'ethernet',
        ConnectivityResult.vpn => 'VPN',
        ConnectivityResult.bluetooth => 'bluetooth',
        ConnectivityResult.satellite => 'satélite',
        ConnectivityResult.other => 'otra',
        ConnectivityResult.none => 'sin conexión',
      });
    }
    return partes.toSet().join(' + ');
  }

  static Future<String> tipoConexionActual() async {
    final results = await _connectivity.checkConnectivity();
    return _tipoConexionLegible(results);
  }

  static Future<int?> _medirHttpHead(
    String url, {
    Duration limite = const Duration(seconds: 12),
  }) async {
    final sw = Stopwatch()..start();
    try {
      await http.head(Uri.parse(url)).timeout(limite);
      sw.stop();
      return sw.elapsedMilliseconds;
    } catch (e) {
      sw.stop();
      if (sw.elapsedMilliseconds < limite.inMilliseconds) {
        debugPrint('RedDiag ping parcial $url (${sw.elapsedMilliseconds}ms): $e');
      } else {
        debugPrint('RedDiag ping timeout $url: $e');
      }
      return null;
    }
  }

  static Future<RedPrueba> _medirFirestore() async {
    final sw = Stopwatch()..start();
    try {
      final prueba = await FirestoreGrpcService.pingDiagnosticoRed(
        limite: const Duration(seconds: 2),
      ).timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('RedDiag firestore 2s'),
      );
      sw.stop();
      final ms = prueba.ms;
      String calidad;
      if (!prueba.ok) {
        if (prueba.desdeCache) {
          calidad = 'caché (gRPC caído)';
        } else if (prueba.detalle.contains('timeout')) {
          calidad = 'gRPC timeout (red lenta)';
        } else if (ms < 80) {
          calidad = 'fallo gRPC inmediato';
        } else {
          calidad = 'gRPC falló';
        }
        debugPrint('RedDiag firestore gRPC: ${prueba.detalle} (${ms}ms)');
      } else {
        calidad = clasificarMs(ms);
      }
      return RedPrueba(
        nombre: 'firestore',
        ms: ms,
        calidad: calidad,
        ok: prueba.ok,
      );
    } on TimeoutException {
      sw.stop();
      FirestoreGrpcService.registrarEstadoGrpc(
        operativo: false,
        motivo: 'RedDiag timeout 2s',
      );
      debugPrint(
        'RedDiag firestore gRPC: timeout 2s → fail-fast (${sw.elapsedMilliseconds}ms)',
      );
      return RedPrueba(
        nombre: 'firestore',
        ms: sw.elapsedMilliseconds,
        calidad: 'gRPC timeout (red lenta)',
        ok: false,
      );
    }
  }

  static Future<({int? ms, bool ok})> _medirAppCheck() async {
    final sw = Stopwatch()..start();
    try {
      var token = await FirebaseAppCheck.instance
          .getToken(false)
          .timeout(const Duration(seconds: 8));
      token ??= await FirebaseAppCheck.instance
          .getToken(true)
          .timeout(const Duration(seconds: 20));
      sw.stop();
      final ok = token != null && token.isNotEmpty;
      return (ms: sw.elapsedMilliseconds, ok: ok);
    } catch (e) {
      sw.stop();
      debugPrint('RedDiag app_check (${sw.elapsedMilliseconds}ms): $e');
      return (ms: sw.elapsedMilliseconds, ok: false);
    }
  }

  static String _calidadGeneral(List<RedPrueba> pruebas, bool appCheckOk) {
    if (pruebas.every((p) => !p.ok)) return 'sin respuesta';
    if (!appCheckOk) return 'app_check pendiente';

    final firestore = pruebas.where((p) => p.nombre == 'firestore').firstOrNull;
    final google = pruebas.where((p) => p.nombre == 'google').firstOrNull;

    final msList = [
      if (firestore?.ms != null) firestore!.ms!,
      if (google?.ms != null) google!.ms!,
    ];
    if (msList.isEmpty) return 'desconocida';

    final peor = msList.reduce((a, b) => a > b ? a : b);
    return clasificarMs(peor);
  }

  /// Ejecuta pruebas y escribe el resultado en consola (logcat / flutter run).
  static Future<RedInforme> ejecutar({String contexto = 'app'}) async {
    final tipo = await tipoConexionActual();
    debugPrint('🌐 RED [$contexto] ─── diagnóstico ───');

    final googleMs = await _medirHttpHead('https://www.google.com/generate_204');
    final firebaseHttpMs =
        await _medirHttpHead('https://firestore.googleapis.com/');
    final appCheck = await _medirAppCheck();
    final firestore = await _medirFirestore();

    final pruebas = <RedPrueba>[
      RedPrueba(
        nombre: 'google',
        ms: googleMs,
        calidad: clasificarMs(googleMs),
        ok: googleMs != null,
      ),
      RedPrueba(
        nombre: 'firebase_http',
        ms: firebaseHttpMs,
        calidad: clasificarMs(firebaseHttpMs),
        ok: firebaseHttpMs != null,
      ),
      firestore,
    ];

    final calidad = _calidadGeneral(pruebas, appCheck.ok);

    debugPrint('🌐 RED [$contexto] conexión: $tipo');
    debugPrint(
      '🌐 RED [$contexto] google: ${googleMs ?? "?"} ms → ${clasificarMs(googleMs)}',
    );
    debugPrint(
      '🌐 RED [$contexto] firebase (HTTP): ${firebaseHttpMs ?? "?"} ms → ${clasificarMs(firebaseHttpMs)}',
    );
    debugPrint(
      '🌐 RED [$contexto] firestore gRPC: ${firestore.ms ?? "?"} ms → ${firestore.calidad}',
    );
    debugPrint(
      '🌐 RED [$contexto] app_check: ${appCheck.ms ?? "?"} ms → ${appCheck.ok ? "OK" : "FALTA"}',
    );
    debugPrint('🌐 RED [$contexto] ★ CALIDAD GENERAL: $calidad');
    if (tipo.contains('datos móviles') && !firestore.ok) {
      debugPrint(
        '🌐 RED [$contexto] ⚠️ Fail-fast activo: pedidos irán directo por HTTP REST.',
      );
    }
    debugPrint('🌐 RED [$contexto] ─── fin ───');

    return RedInforme(
      tipoConexion: tipo,
      calidadGeneral: calidad,
      pruebas: pruebas,
      appCheckOk: appCheck.ok,
      fecha: DateTime.now(),
    );
  }

  /// Registra en consola cada vez que cambia WiFi ↔ datos móviles.
  static void iniciarMonitoreo() {
    _suscripcion ??= _connectivity.onConnectivityChanged.listen((results) {
      final tipo = _tipoConexionLegible(results);
      debugPrint('🌐 RED cambio → $tipo');
      unawaited(ejecutar(contexto: 'cambio_red'));
    });
  }
}
