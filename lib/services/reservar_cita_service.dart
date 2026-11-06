import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:angostura_digital/services/firestore_grpc_service.dart';
import 'package:angostura_digital/services/notificaciones_pedido_service.dart';
import 'package:angostura_digital/utils/comision_app_utils.dart';
import 'package:angostura_digital/utils/pedido_servicios_utils.dart';
import 'package:angostura_digital/utils/servicio_cita_utils.dart';
import 'package:angostura_digital/utils/telefono_local_utils.dart';
import 'package:angostura_digital/utils/telefono_obligatorio_utils.dart';

/// Reserva una cita creando el pedido en Firestore (sin carrito).
class ReservarCitaService {
  ReservarCitaService._();

  static Future<String> crearCita({
    required String negocioId,
    required String servicioId,
    required String servicioNombre,
    required double precio,
    double? precioLista,
    bool esPrecioDescuento = false,
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

    await _exigirHorarioLibre(
      negocioId: negocioId,
      citaInicio: citaInicio,
      duracionMinutos: duracionMinutos,
      negocio: datosNegocio,
    );

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
      if (esPrecioDescuento) 'es_precio_descuento': true,
      if (esPrecioDescuento && precioLista != null) 'precio_lista': precioLista,
      'cantidad': 1,
      'es_servicio': true,
      'tipo_servicio': 'cita',
      'cita_inicio': citaInicio.toIso8601String(),
      'duracion_minutos': duracionMinutos,
      if (fotoUrl != null && fotoUrl.isNotEmpty) 'foto_url': fotoUrl,
    };

    final pedidoId = await FirestoreGrpcService.crearPedido(
      {
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
        'cita_inicio': Timestamp.fromDate(citaInicio),
        'duracion_minutos': duracionMinutos,
        if (esPrecioDescuento) 'cliente_con_descuento': true,
        'direccion': 'Cita en el local del negocio.',
        'fecha': FieldValue.serverTimestamp(),
      },
      forzarRest: FirestoreGrpcService.usarRestDirecto,
    );

    await NotificacionesPedidoService.solicitarAvisoDueno(pedidoId);
    return pedidoId;
  }

  /// Cita que el negocio anota a mano (en persona o por mensaje).
  static Future<String> crearCitaManual({
    required String negocioId,
    required String servicioId,
    required String servicioNombre,
    required double precio,
    required DateTime citaInicio,
    required int duracionMinutos,
    required String clienteNombre,
    required String clienteTelefono,
    String notas = '',
    String? fotoUrl,
    Map<String, dynamic>? datosNegocio,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para agendar la cita.');
    }

    final nombre = clienteNombre.trim();
    final telefono = TelefonoLocalUtils.normalizar(clienteTelefono);
    if (nombre.isEmpty) {
      throw Exception('Escribe el nombre de la persona.');
    }
    if (telefono.isNotEmpty && telefono.length != 10) {
      throw Exception('El teléfono debe tener 10 dígitos.');
    }

    await _exigirHorarioLibre(
      negocioId: negocioId,
      citaInicio: citaInicio,
      duracionMinutos: duracionMinutos,
      negocio: datosNegocio,
    );

    String negocioNombre = datosNegocio?['nombre']?.toString() ?? 'Local';
    Map<String, dynamic>? negocioData = datosNegocio;
    if (negocioData == null || negocioData['nombre'] == null) {
      final doc = await FirebaseFirestore.instance.collection('negocios').doc(negocioId).get();
      if (doc.exists) {
        negocioData = doc.data();
        negocioNombre = negocioData?['nombre']?.toString() ?? 'Local';
      }
    }

    var creadoPorNombre = user.displayName ?? 'Personal';
    try {
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (userDoc.exists) {
        creadoPorNombre = (userDoc.data()?['nombre'] ?? creadoPorNombre).toString();
      }
    } catch (_) {}

    final config = ComisionAppConfig.desdeMap(negocioData);
    final comisionMonto = ComisionAppUtils.calcularMonto(precio, config);
    final extraComision =
        ComisionAppUtils.cobrarExtraAlCliente(config.pagadaPor) ? comisionMonto : 0.0;

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

    return FirestoreGrpcService.crearPedido(
      {
        'negocio_id': negocioId,
        'negocio_nombre': negocioNombre,
        'creado_por_uid': user.uid,
        'creado_por_nombre': creadoPorNombre,
        'cliente_nombre': nombre,
        if (telefono.isNotEmpty) 'cliente_telefono': telefono,
        'origen_cita': 'manual',
        'es_cita_manual': true,
        'notificacion_dueno_enviada': true,
        'productos': [producto],
        'subtotal': precio,
        'costo_envio': 0.0,
        'comision_app': comisionMonto,
        'comision_pagada_por': config.pagadaPor,
        'total': precio + extraComision,
        'estado': PedidoServiciosUtils.estadoConfirmada,
        'notas': notas.trim(),
        'metodo_pago': 'efectivo',
        'metodo_entrega': 'cita',
        'tipo_negocio': 'servicios',
        'tiene_cita': true,
        'cita_inicio': Timestamp.fromDate(citaInicio),
        'duracion_minutos': duracionMinutos,
        'direccion': 'Cita anotada en el local · $nombre',
        'fecha': FieldValue.serverTimestamp(),
      },
      forzarRest: FirestoreGrpcService.usarRestDirecto,
    );
  }

  static Future<void> _exigirHorarioLibre({
    required String negocioId,
    required DateTime citaInicio,
    required int duracionMinutos,
    Map<String, dynamic>? negocio,
  }) async {
    final intervalo = ServicioCitaUtils.intervaloDesdeNegocio(negocio);
    final cupo = ServicioCitaUtils.cupoPorHora(negocio);
    final agenda = await ServicioCitaUtils.cargarAgenda(negocioId, negocio: negocio);
    if (ServicioCitaUtils.noSePuedeAgendar(
      slot: citaInicio,
      agenda: agenda,
      duracionMinutos: duracionMinutos,
      intervaloMinutos: intervalo,
      cupo: cupo,
    )) {
      throw Exception(ServicioCitaUtils.motivoNoDisponible(
        slot: citaInicio,
        agenda: agenda,
        duracionMinutos: duracionMinutos,
        intervaloMinutos: intervalo,
        cupo: cupo,
      ));
    }
  }
}
