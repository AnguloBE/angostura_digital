import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Pide al backend que envíe push al dueño/trabajadores (respaldo del trigger de Firestore).
class NotificacionesPedidoService {
  NotificacionesPedidoService._();

  static Future<void> solicitarAvisoDueno(String pedidoId) async {
    if (pedidoId.isEmpty) return;
    try {
      await FirebaseFunctions.instance
          .httpsCallable('avisarNuevoPedido')
          .call({'pedidoId': pedidoId});
    } catch (e, st) {
      debugPrint('avisarNuevoPedido: $e\n$st');
    }
  }
}
