import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:angostura_digital/firebase_options.dart';
import 'package:angostura_digital/utils/app_check_config.dart';
import 'package:angostura_digital/utils/firestore_rest_codec.dart';

/// Maneja reconexión gRPC y respaldo HTTP (REST) cuando Firestore gRPC falla en 4G.
class FirestoreGrpcService {
  FirestoreGrpcService._();

  static const _projectId = 'angostura-digital';
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static StreamSubscription<List<ConnectivityResult>>? _suscripcionRed;
  static DateTime? _ultimoReinicioGrpc;

  /// `true` = el último diagnóstico detectó gRPC caído → pedidos van directo por REST.
  static bool _grpcCaido = false;

  static bool get grpcCaido => _grpcCaido;
  static bool get usarRestDirecto => _grpcCaido;

  /// Actualiza el estado tras RedDiag o un pedido fallido en gRPC.
  static void registrarEstadoGrpc({required bool operativo, String? motivo}) {
    _grpcCaido = !operativo;
    debugPrint(
      '🔌 gRPC ${operativo ? "operativo" : "CAÍDO"}'
      '${motivo != null ? " ($motivo)" : ""}',
    );
  }

  /// Tras cambio de red: volver a probar gRPC en el próximo diagnóstico/pedido.
  static void reiniciarEstadoGrpc() {
    _grpcCaido = false;
  }

  /// Reinicia el canal gRPC (disable → enable). Útil tras cambio de red.
  static Future<void> reconectarGrpc({String motivo = 'manual'}) async {
    final ahora = DateTime.now();
    if (_ultimoReinicioGrpc != null &&
        ahora.difference(_ultimoReinicioGrpc!) < const Duration(seconds: 2)) {
      return;
    }
    _ultimoReinicioGrpc = ahora;

    try {
      await _db.disableNetwork().timeout(const Duration(seconds: 8));
      await Future.delayed(const Duration(milliseconds: 500));
      await _db.enableNetwork().timeout(const Duration(seconds: 12));
      await Future.delayed(const Duration(milliseconds: 400));
      debugPrint('🔌 Firestore gRPC: canal reiniciado ($motivo)');
    } catch (e) {
      debugPrint('🔌 Firestore gRPC reinicio ($motivo): $e');
      try {
        await _db.enableNetwork().timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
  }

  /// Al cambiar WiFi ↔ datos móviles, reinicia gRPC automáticamente.
  static void iniciarReconexionAutomatica() {
    _suscripcionRed ??= Connectivity().onConnectivityChanged.listen((results) {
      if (results.isEmpty || results.contains(ConnectivityResult.none)) return;
      reiniciarEstadoGrpc();
      unawaited(reconectarGrpc(motivo: 'cambio_red'));
    });
  }

  /// Ping gRPC ligero para RedDiag: sin App Check ni reconectar, máx. [limite].
  static Future<({bool ok, int ms, bool desdeCache, String detalle})>
      pingDiagnosticoRed({
    Duration limite = const Duration(seconds: 2),
  }) async {
    final sw = Stopwatch()..start();
    try {
      final snap = await _db
          .collection('_red_diag')
          .doc('ping')
          .get(const GetOptions(source: Source.server))
          .timeout(limite);
      sw.stop();

      final ms = sw.elapsedMilliseconds;
      final cache = snap.metadata.isFromCache;

      if (cache) {
        registrarEstadoGrpc(
          operativo: false,
          motivo: 'lectura desde caché',
        );
        return (
          ok: false,
          ms: ms,
          desdeCache: true,
          detalle: 'leyó caché local (gRPC no conectó al servidor)',
        );
      }
      if (ms < 80) {
        registrarEstadoGrpc(
          operativo: false,
          motivo: 'respuesta ${ms}ms',
        );
        return (
          ok: false,
          ms: ms,
          desdeCache: false,
          detalle: 'respuesta sospechosamente rápida (${ms}ms) — gRPC posiblemente caído',
        );
      }
      registrarEstadoGrpc(operativo: true, motivo: 'servidor ${ms}ms');
      return (
        ok: true,
        ms: ms,
        desdeCache: false,
        detalle: 'servidor OK',
      );
    } on TimeoutException {
      sw.stop();
      registrarEstadoGrpc(
        operativo: false,
        motivo: 'RedDiag timeout ${limite.inSeconds}s',
      );
      return (
        ok: false,
        ms: sw.elapsedMilliseconds,
        desdeCache: false,
        detalle: 'timeout gRPC ${limite.inSeconds}s (red lenta)',
      );
    } catch (e) {
      sw.stop();
      registrarEstadoGrpc(operativo: false, motivo: 'error');
      return (
        ok: false,
        ms: sw.elapsedMilliseconds,
        desdeCache: false,
        detalle: 'error gRPC: $e',
      );
    }
  }

  /// Prueba si Firestore realmente llega al servidor (no caché ni fallo instantáneo).
  static Future<({bool ok, int ms, bool desdeCache, String detalle})>
      verificarServidorFirestore() async {
    await asegurarAppCheckParaAuth(esperaMaxima: const Duration(seconds: 15));
    await reconectarGrpc(motivo: 'verificacion');

    final sw = Stopwatch()..start();
    try {
      final snap = await _db
          .collection('_red_diag')
          .doc('ping')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 22));
      sw.stop();

      final ms = sw.elapsedMilliseconds;
      final cache = snap.metadata.isFromCache;

      if (cache) {
        registrarEstadoGrpc(
          operativo: false,
          motivo: 'lectura desde caché',
        );
        return (
          ok: false,
          ms: ms,
          desdeCache: true,
          detalle: 'leyó caché local (gRPC no conectó al servidor)',
        );
      }
      if (ms < 80) {
        registrarEstadoGrpc(
          operativo: false,
          motivo: 'respuesta ${ms}ms',
        );
        return (
          ok: false,
          ms: ms,
          desdeCache: false,
          detalle: 'respuesta sospechosamente rápida (${ms}ms) — gRPC posiblemente caído',
        );
      }
      registrarEstadoGrpc(operativo: true, motivo: 'servidor ${ms}ms');
      return (
        ok: true,
        ms: ms,
        desdeCache: false,
        detalle: 'servidor OK',
      );
    } catch (e) {
      sw.stop();
      registrarEstadoGrpc(operativo: false, motivo: 'error');
      return (
        ok: false,
        ms: sw.elapsedMilliseconds,
        desdeCache: false,
        detalle: 'error gRPC: $e',
      );
    }
  }

  /// Crea un pedido. Si gRPC está caído (RedDiag), va **directo por REST** sin SDK Firestore.
  static Future<String> crearPedido(
    Map<String, dynamic> datos, {
    void Function(String mensaje)? onProgreso,
    bool? forzarRest,
  }) async {
    final saltarGrpc = forzarRest == true || _grpcCaido;

    if (saltarGrpc) {
      debugPrint('🔌 Fail-fast: REST HTTP directo (sin SDK Firestore/gRPC)');
      onProgreso?.call('Enviando pedido por HTTP...');
      final id = await _crearPedidoPorRest(datos);
      debugPrint('🔌 Pedido REST HTTP OK: $id');
      return id;
    }

    await asegurarAppCheckParaAuth(onProgreso: onProgreso);
    await reconectarGrpc(motivo: 'antes_pedido');
    onProgreso?.call('Enviando pedido...');

    try {
      final ref = await _db
          .collection('pedidos')
          .add(datos)
          .timeout(const Duration(seconds: 28));

      final confirmado = await _confirmarEnServidor(ref.id);
      if (confirmado) {
        registrarEstadoGrpc(operativo: true, motivo: 'pedido ok');
        debugPrint('🔌 Pedido gRPC OK: ${ref.id}');
        return ref.id;
      }
      debugPrint('🔌 Pedido gRPC sin confirmar en servidor');
      registrarEstadoGrpc(operativo: false, motivo: 'sin confirmar');
    } catch (e) {
      debugPrint('🔌 Pedido gRPC falló: $e');
      registrarEstadoGrpc(operativo: false, motivo: 'timeout/error');
    }

    onProgreso?.call('Enviando pedido por HTTP...');
    final idRest = await _crearPedidoPorRest(datos);
    debugPrint('🔌 Pedido REST HTTP OK: $idRest');
    return idRest;
  }

  static Future<bool> _confirmarEnServidor(String pedidoId) async {
    try {
      final snap = await _db
          .collection('pedidos')
          .doc(pedidoId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));
      return snap.exists && !snap.metadata.isFromCache;
    } catch (_) {
      return false;
    }
  }

  /// Tokens en caché, máx. 2 s cada uno; no bloquea con refresh de red.
  static Future<({String? idToken, String? appCheckToken})> _prepararTokensRest() async {
    String? idToken;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        idToken = await user.getIdToken(false).timeout(
              const Duration(seconds: 2),
              onTimeout: () => throw TimeoutException('auth'),
            );
      } on TimeoutException {
        debugPrint('REST: Auth token timeout 2s (caché), continúa');
      } catch (e) {
        debugPrint('REST: Auth token: $e');
      }
    }

    String? appCheckToken;
    try {
      appCheckToken = await FirebaseAppCheck.instance
          .getToken(false)
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => null,
          );
    } on TimeoutException {
      debugPrint('REST: App Check token timeout 2s, continúa');
    } catch (e) {
      debugPrint('REST: App Check token: $e');
    }

    return (idToken: idToken, appCheckToken: appCheckToken);
  }

  static Future<String> _crearPedidoPorRest(Map<String, dynamic> datos) async {
    try {
      return await _ejecutarRestPost(datos).timeout(const Duration(seconds: 5));
    } on TimeoutException {
      debugPrint('🔌 REST pedido: timeout estricto 5s');
      throw Exception(
        'No se pudo enviar el pedido a tiempo. Revisa tu señal e intenta de nuevo.',
      );
    }
  }

  /// Escribe o fusiona un documento. Si gRPC está caído, usa REST HTTP directo.
  static Future<void> escribirDocumento(
    String collection,
    String docId,
    Map<String, dynamic> datos, {
    bool merge = true,
    bool? forzarRest,
  }) async {
    final ruta = '$collection/$docId';
    final saltarGrpc = forzarRest == true || _grpcCaido;

    if (saltarGrpc) {
      debugPrint('🔌 REST PATCH directo: $ruta');
      await _patchDocumentoRest(ruta, datos);
      return;
    }

    try {
      final ref = _db.collection(collection).doc(docId);
      await ref
          .set(datos, SetOptions(merge: merge))
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('🔌 gRPC set falló ($ruta): $e → REST');
      registrarEstadoGrpc(operativo: false, motivo: 'escritura');
      await _patchDocumentoRest(ruta, datos);
    }
  }

  /// Comprueba si el documento existe en el servidor (REST GET, no gRPC).
  static Future<bool> documentoExisteRest(
    String collection,
    String docId,
  ) async {
    try {
      final response = await _restGet('$collection/$docId')
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } on TimeoutException {
      debugPrint('REST GET timeout: $collection/$docId');
      return false;
    } catch (e) {
      debugPrint('REST GET error: $e');
      return false;
    }
  }

  static Future<({int statusCode, String body})> _restGet(String rutaDoc) async {
    final tokens = await _prepararTokensRest();
    final idToken = tokens.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Sin token de sesión para lectura REST.');
    }

    final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
    final url =
        'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/$rutaDoc?key=$apiKey';

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('Authorization', 'Bearer $idToken');
      final appCheckToken = tokens.appCheckToken;
      if (appCheckToken != null && appCheckToken.isNotEmpty) {
        request.headers.set('X-Firebase-AppCheck', appCheckToken);
      }
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      return (statusCode: response.statusCode, body: body);
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> _patchDocumentoRest(
    String rutaDoc,
    Map<String, dynamic> datos,
  ) async {
    try {
      await _ejecutarRestPatch(rutaDoc, datos)
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      debugPrint('🔌 REST PATCH timeout 5s: $rutaDoc');
      throw Exception('No se pudo guardar a tiempo. Revisa tu señal.');
    }
  }

  /// Crea un documento con ID fijo (POST + documentId).
  static Future<void> crearDocumentoRest(
    String collection,
    String docId,
    Map<String, dynamic> datos,
  ) async {
    try {
      await _ejecutarRestPostConId(collection, docId, datos)
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      debugPrint('🔌 REST POST timeout 5s: $collection/$docId');
      throw Exception('No se pudo guardar a tiempo. Revisa tu señal.');
    }
  }

  static Future<void> _ejecutarRestPostConId(
    String collection,
    String docId,
    Map<String, dynamic> datos,
  ) async {
    final tokens = await _prepararTokensRest();
    final idToken = tokens.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Sin token de sesión para guardar.');
    }

    final datosRest = prepararMapaParaRest(datos);
    final body = jsonEncode({
      'fields': mapaAFirestoreRestFields(datosRest),
    });

    final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
    final url =
        'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/$collection?documentId=$docId&key=$apiKey';

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.postUrl(Uri.parse(url));
      request.headers.set('Authorization', 'Bearer $idToken');
      final appCheckToken = tokens.appCheckToken;
      if (appCheckToken != null && appCheckToken.isNotEmpty) {
        request.headers.set('X-Firebase-AppCheck', appCheckToken);
      }
      request.headers.contentType =
          ContentType('application', 'json', charset: 'utf-8');
      request.write(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('🔌 REST POST doc error ${response.statusCode}: $responseBody');
        throw Exception('Firestore REST ${response.statusCode}');
      }
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> _ejecutarRestPatch(
    String rutaDoc,
    Map<String, dynamic> datos,
  ) async {
    final tokens = await _prepararTokensRest();
    final idToken = tokens.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Sin token de sesión para guardar.');
    }

    final datosRest = prepararMapaParaRest(datos);
    final fields = mapaAFirestoreRestFields(datosRest);
    final body = jsonEncode({'fields': fields});

    final maskParams = datosRest.keys
        .map((k) => 'updateMask.fieldPaths=${Uri.encodeComponent(k)}')
        .join('&');

    final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
    final url =
        'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/$rutaDoc?$maskParams&key=$apiKey';

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.patchUrl(Uri.parse(url));
      request.headers.set('Authorization', 'Bearer $idToken');
      final appCheckToken = tokens.appCheckToken;
      if (appCheckToken != null && appCheckToken.isNotEmpty) {
        request.headers.set('X-Firebase-AppCheck', appCheckToken);
      }
      request.headers.contentType =
          ContentType('application', 'json', charset: 'utf-8');
      request.write(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('🔌 REST PATCH error ${response.statusCode}: $responseBody');
        throw Exception('Firestore REST ${response.statusCode}');
      }
    } finally {
      client.close(force: true);
    }
  }

  static Future<String> _ejecutarRestPost(Map<String, dynamic> datos) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Sin sesión activa para enviar el pedido.');
    }

    final tokens = await _prepararTokensRest();
    final idToken = tokens.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'No hay token de sesión disponible. Cierra sesión e intenta de nuevo.',
      );
    }

    final datosRest = prepararMapaParaRest(datos);
    final body = jsonEncode({
      'fields': mapaAFirestoreRestFields(datosRest),
    });

    final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
    final url =
        'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/pedidos?key=$apiKey';

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.postUrl(Uri.parse(url));
      request.headers.set('Authorization', 'Bearer $idToken');
      final appCheckToken = tokens.appCheckToken;
      if (appCheckToken != null && appCheckToken.isNotEmpty) {
        request.headers.set('X-Firebase-AppCheck', appCheckToken);
      }
      request.headers.contentType =
          ContentType('application', 'json', charset: 'utf-8');
      request.write(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('🔌 REST pedido error ${response.statusCode}: $responseBody');
        throw Exception(
          'Firestore REST ${response.statusCode}: no se pudo guardar el pedido.',
        );
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final name = json['name']?.toString() ?? '';
      final id = name.split('/').last;
      if (id.isEmpty) {
        throw Exception('Firestore REST no devolvió ID de pedido.');
      }
      return id;
    } finally {
      client.close(force: true);
    }
  }
}
