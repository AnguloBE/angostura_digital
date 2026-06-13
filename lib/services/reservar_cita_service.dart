import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:angostura_digital/services/notificaciones_pedido_service.dart';
import 'package:angostura_digital/utils/comision_app_utils.dart';
import 'package:angostura_digital/utils/servicio_cita_utils.dart';
import 'package:angostura_digital/utils/telefono_obligatorio_utils.dart';

/// Reserva una cita creando el pedido en Firestore (sin carrito).
class ReservarCitaService {
  ReservarCitaService._();

  static Future<String> crearCita({
    required String negocioId,
    required String servicioId,
    required String servicioNombre,
    required double precio,
    required DateTime citaInicio,
    required int duracionMinutos,
    String? fotoUrl,
    Map<String, dynamic>? datosNegocio,
    String metodoPago = 'efectivo',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para reservar una cita.');
    }
    if (!await TelefonoObligatorioUtils.tieneTelefonoVerificado()) {
      throw Exception('Verifica tu número de teléfono antes de reservar.');
    }

    final intervalo = ServicioCitaUtils.intervaloDesdeNegocio(datosNegocio);
    final ocupadas = await ServicioCitaUtils.slotsNoDisponibles(
      negocioId,
      negocio: datosNegocio,
      duracionMinutos: duracionMinutos,
      intervaloMinutos: intervalo,
    );
    if (ServicioCitaUtils.slotOcupado(
      citaInicio,
      ocupadas,
      duracionMinutos,
      intervaloMinutos: intervalo,
    )) {
      throw Exception('Esa hora ya no está disponible. Elige otra.');
    }

    String negocioNombre = 'Negocio';
    Map<String, dynamic>? negocioData = datosNegocio;
    if (negocioData == null || negocioData['nombre'] == null) {
      final doc =
          await FirebaseFirestore.instance.collection('negocios').doc(negocioId).get();
      if (doc.exists) {
        negocioData = doc.data();
        negocioNombre = negocioData?['nombre']?.toString() ?? 'Local';
      }
    } else {
      negocioNombre = negocioData['nombre']?.toString() ?? 'Local';
    }

    final config = ComisionAppConfig.desdeMap(negocioData);
    final subtotal = precio;
    final comisionMonto = ComisionAppUtils.calcularMonto(subtotal, config);
    final extraComision =
        ComisionAppUtils.cobrarExtraAlCliente(config.pagadaPor) ? comisionMonto : 0.0;
    final total = subtotal + extraComision;

    final producto = <String, dynamic>{
      'id': servicioId,
      'nombre': servicioNombre,
      'precio': precio,
      'precio_base': precio,
      'cantidad': 1,
      'es_servicio': true,
      'tipo_servicio': 'cita',
      'cita_inicio': citaInicio.toIso8601String(),
      'duracion_minutos': duracionMinutos,
      if (fotoUrl != null && fotoUrl.isNotEmpty) 'foto_url': fotoUrl,
    };

    final ref = await FirebaseFirestore.instance.collection('pedidos').add({
      'cliente_id': user.uid,
      'negocio_id': negocioId,
      'negocio_nombre': negocioNombre,
      'productos': [producto],
      'subtotal': subtotal,
      'costo_envio': 0.0,
      'comision_app': comisionMonto,
      'comision_pagada_por': config.pagadaPor,
      'total': total,
      'estado': 'Pendiente',
      'notas': '',
      'metodo_pago': metodoPago,
      'metodo_entrega': 'cita',
      'tipo_negocio': 'servicios',
      'tiene_cita': true,
      'direccion': 'Cita en el local del negocio.',
      'fecha': FieldValue.serverTimestamp(),
    });

    await NotificacionesPedidoService.solicitarAvisoDueno(ref.id);
    return ref.id;
  }
}
