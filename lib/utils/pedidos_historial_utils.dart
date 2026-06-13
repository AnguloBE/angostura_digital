import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show Color, Colors;
import 'package:angostura_digital/utils/pedido_ubicacion_utils.dart';
import 'package:angostura_digital/utils/pedido_servicios_utils.dart';

enum PeriodoPedidosHistorial { hoy, semana, mes, todos }

enum FiltroEstadoPedidos { todos, activos, entregado, cancelado }

enum VistaAdminActividad { resumen, pedidos, negocios, productos, usuarios }

class PedidoHistorialItem {
  final String id;
  final DateTime? fecha;
  final String estado;
  final double subtotal;
  final double costoEnvio;
  final double comisionApp;
  final String comisionPagadaPor;
  final double total;
  final String metodoEntrega;
  final String direccion;
  final String tiempoEstimado;
  final String notas;
  final String? clienteId;
  final String negocioId;
  final String negocioNombre;
  final List<Map<String, dynamic>> productos;
  final PedidoUbicacionCoords? coordenadasEntrega;
  final PedidoUbicacionCoords? coordenadasNegocio;
  final double? distanciaEnvioKm;
  final double? distanciaCobroKm;
  final bool entregaConfirmadaMapa;
  final bool tieneCita;
  final String? tipoNegocio;

  const PedidoHistorialItem({
    required this.id,
    this.fecha,
    required this.estado,
    required this.subtotal,
    required this.costoEnvio,
    required this.comisionApp,
    required this.comisionPagadaPor,
    required this.total,
    required this.metodoEntrega,
    this.direccion = '',
    this.tiempoEstimado = '',
    this.notas = '',
    this.clienteId,
    this.negocioId = '',
    this.negocioNombre = '',
    this.productos = const [],
    this.coordenadasEntrega,
    this.coordenadasNegocio,
    this.distanciaEnvioKm,
    this.distanciaCobroKm,
    this.entregaConfirmadaMapa = false,
    this.tieneCita = false,
    this.tipoNegocio,
  });

  factory PedidoHistorialItem.desdeDoc(String id, Map<String, dynamic> data) {
    final productosRaw = data['productos'];
    final productos = <Map<String, dynamic>>[];
    if (productosRaw is List) {
      for (final p in productosRaw) {
        if (p is Map) {
          productos.add(Map<String, dynamic>.from(p));
        }
      }
    }

    DateTime? fecha;
    final ts = data['fecha'];
    if (ts is Timestamp) fecha = ts.toDate().toLocal();

    return PedidoHistorialItem(
      id: id,
      fecha: fecha,
      estado: (data['estado'] ?? 'Pendiente').toString(),
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
      costoEnvio: (data['costo_envio'] as num?)?.toDouble() ?? 0,
      comisionApp: (data['comision_app'] as num?)?.toDouble() ?? 0,
      comisionPagadaPor: (data['comision_pagada_por'] ?? 'negocio').toString(),
      total: (data['total'] as num?)?.toDouble() ?? 0,
      metodoEntrega: (data['metodo_entrega'] ?? 'domicilio').toString(),
      direccion: (data['direccion'] ?? '').toString().replaceAll(RegExp(r'\n?\[Coords:.*\]'), ''),
      tiempoEstimado: (data['tiempo_estimado'] ?? '').toString(),
      notas: (data['notas'] ?? '').toString(),
      clienteId: data['cliente_id']?.toString(),
      negocioId: (data['negocio_id'] ?? '').toString(),
      negocioNombre: (data['negocio_nombre'] ?? 'Negocio').toString(),
      productos: productos,
      coordenadasEntrega: PedidoUbicacionUtils.resolverEntrega(data),
      coordenadasNegocio: PedidoUbicacionUtils.resolverNegocio(data),
      distanciaEnvioKm: (data['distancia_envio_km'] as num?)?.toDouble(),
      distanciaCobroKm: (data['distancia_cobro_km'] as num?)?.toDouble(),
      entregaConfirmadaMapa: data['entrega_confirmada_mapa'] == true,
      tieneCita: data['tiene_cita'] == true,
      tipoNegocio: data['tipo_negocio']?.toString(),
    );
  }

  bool get cancelado => estado == 'Cancelado';
  bool get entregado =>
      estado == 'Entregado' || estado == PedidoServiciosUtils.estadoConfirmada;
  bool get esServicios => PedidoServiciosUtils.esPedidoServicios({
        if (tipoNegocio != null) 'tipo_negocio': tipoNegocio,
        'tiene_cita': tieneCita,
        'metodo_entrega': metodoEntrega,
      });
  bool get esDomicilio => metodoEntrega == 'domicilio';
  bool get tieneUbicacionEntrega => coordenadasEntrega != null;
  bool get comisionLaPagaCliente => comisionPagadaPor == 'cliente' && comisionApp > 0;

  double get totalCobrado {
    if (total > 0) return total;
    return subtotal + costoEnvio + (comisionLaPagaCliente ? comisionApp : 0);
  }

  int get cantidadArticulos {
    var n = 0;
    for (final p in productos) {
      n += (p['cantidad'] as num?)?.toInt() ?? 1;
    }
    return n;
  }
}

class ProductoAgregadoHistorial {
  final String nombre;
  final int cantidad;
  final double monto;
  final int pedidos;
  final List<String> negocios;

  const ProductoAgregadoHistorial({
    required this.nombre,
    required this.cantidad,
    required this.monto,
    this.pedidos = 0,
    this.negocios = const [],
  });
}

class UsuarioAgregadoHistorial {
  final String uid;
  final int pedidos;
  final int cancelados;
  final int entregados;
  final double gastoTotal;

  const UsuarioAgregadoHistorial({
    required this.uid,
    required this.pedidos,
    required this.cancelados,
    required this.entregados,
    required this.gastoTotal,
  });
}

class NegocioAgregadoHistorial {
  final String negocioId;
  final String nombre;
  final int pedidos;
  final double ventas;
  final double comisionApp;

  const NegocioAgregadoHistorial({
    required this.negocioId,
    required this.nombre,
    required this.pedidos,
    required this.ventas,
    required this.comisionApp,
  });
}

class ResumenHistorialPlataforma {
  final ResumenHistorialPedidos general;
  final double comisionTotalApp;
  final int negociosConPedidos;
  final List<NegocioAgregadoHistorial> topNegocios;

  const ResumenHistorialPlataforma({
    required this.general,
    this.comisionTotalApp = 0,
    this.negociosConPedidos = 0,
    this.topNegocios = const [],
  });
}

class ResumenHistorialPedidos {
  final int totalPedidos;
  final int entregados;
  final int cancelados;
  final int enProceso;
  final double ventasTotales;
  final double subtotalProductos;
  final double totalEnvios;
  final double totalComisionApp;
  final int unidadesVendidas;
  final List<ProductoAgregadoHistorial> topProductos;
  final Map<String, int> conteoPorEstado;

  const ResumenHistorialPedidos({
    this.totalPedidos = 0,
    this.entregados = 0,
    this.cancelados = 0,
    this.enProceso = 0,
    this.ventasTotales = 0,
    this.subtotalProductos = 0,
    this.totalEnvios = 0,
    this.totalComisionApp = 0,
    this.unidadesVendidas = 0,
    this.topProductos = const [],
    this.conteoPorEstado = const {},
  });
}

class PedidosHistorialUtils {
  /// Bandeja operativa del negocio: ventana móvil (no “día calendario”) para turnos que pasan medianoche.
  static const Duration ventanaPedidosActivosNegocio = Duration(hours: 24);

  static bool esPedidoEnVentanaActiva(Map<String, dynamic> data, {DateTime? ahora}) {
    final ts = data['fecha'];
    if (ts is! Timestamp) return false;
    final fecha = ts.toDate().toLocal();
    final limite = (ahora ?? DateTime.now()).subtract(ventanaPedidosActivosNegocio);
    return !fecha.isBefore(limite);
  }

  static bool esPedidoEnVentanaActivaItem(PedidoHistorialItem p, {DateTime? ahora}) {
    final fecha = p.fecha;
    if (fecha == null) return false;
    final limite = (ahora ?? DateTime.now()).subtract(ventanaPedidosActivosNegocio);
    return !fecha.isBefore(limite);
  }

  static String etiquetaPeriodo(PeriodoPedidosHistorial p) {
    switch (p) {
      case PeriodoPedidosHistorial.hoy:
        return 'Hoy';
      case PeriodoPedidosHistorial.semana:
        return 'Esta semana';
      case PeriodoPedidosHistorial.mes:
        return 'Este mes';
      case PeriodoPedidosHistorial.todos:
        return 'Todos';
    }
  }

  static DateTime inicioPeriodo(PeriodoPedidosHistorial periodo) {
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    switch (periodo) {
      case PeriodoPedidosHistorial.hoy:
        return hoy;
      case PeriodoPedidosHistorial.semana:
        return hoy.subtract(Duration(days: now.weekday - 1));
      case PeriodoPedidosHistorial.mes:
        return DateTime(now.year, now.month, 1);
      case PeriodoPedidosHistorial.todos:
        return DateTime(2000, 1, 1);
    }
  }

  static String formatearFecha(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    final h = fecha.hour > 12 ? fecha.hour - 12 : (fecha.hour == 0 ? 12 : fecha.hour);
    final ampm = fecha.hour >= 12 ? 'p. m.' : 'a. m.';
    return '${fecha.day}/${fecha.month}/${fecha.year} · '
        '$h:${fecha.minute.toString().padLeft(2, '0')} $ampm';
  }

  static String formatearFechaCorta(DateTime? fecha) {
    if (fecha == null) return '—';
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  static List<PedidoHistorialItem> filtrar(
    List<PedidoHistorialItem> todos, {
    required PeriodoPedidosHistorial periodo,
    FiltroEstadoPedidos estado = FiltroEstadoPedidos.todos,
  }) {
    final inicio = inicioPeriodo(periodo);
    return todos.where((p) {
      if (p.fecha != null && p.fecha!.isBefore(inicio)) return false;
      switch (estado) {
        case FiltroEstadoPedidos.entregado:
          return p.entregado;
        case FiltroEstadoPedidos.cancelado:
          return p.cancelado;
        case FiltroEstadoPedidos.activos:
          return !p.cancelado && !p.entregado;
        case FiltroEstadoPedidos.todos:
          return true;
      }
    }).toList()
      ..sort((a, b) {
        if (a.fecha == null && b.fecha == null) return 0;
        if (a.fecha == null) return 1;
        if (b.fecha == null) return -1;
        return b.fecha!.compareTo(a.fecha!);
      });
  }

  static ResumenHistorialPedidos calcularResumen(List<PedidoHistorialItem> pedidos) {
    var entregados = 0;
    var cancelados = 0;
    var enProceso = 0;
    var ventas = 0.0;
    var subtotal = 0.0;
    var envios = 0.0;
    var comision = 0.0;
    var unidades = 0;
    final conteoEstado = <String, int>{};
    final prodCant = <String, int>{};
    final prodMonto = <String, double>{};
    final prodPedidos = <String, Set<String>>{};
    final prodNegocios = <String, Set<String>>{};

    for (final p in pedidos) {
      conteoEstado[p.estado] = (conteoEstado[p.estado] ?? 0) + 1;
      if (p.cancelado) {
        cancelados++;
        continue;
      }
      if (p.entregado) {
        entregados++;
      } else {
        enProceso++;
      }
      ventas += p.totalCobrado;
      subtotal += p.subtotal;
      envios += p.costoEnvio;
      if (p.comisionLaPagaCliente) comision += p.comisionApp;

      for (final item in p.productos) {
        final nombre = (item['nombre'] ?? 'Sin nombre').toString();
        final qty = (item['cantidad'] as num?)?.toInt() ?? 1;
        final precio = (item['precio'] as num?)?.toDouble() ?? 0;
        unidades += qty;
        prodCant[nombre] = (prodCant[nombre] ?? 0) + qty;
        prodMonto[nombre] = (prodMonto[nombre] ?? 0) + precio * qty;
        prodPedidos.putIfAbsent(nombre, () => {}).add(p.id);
        prodNegocios.putIfAbsent(nombre, () => {}).add(p.negocioNombre);
      }
    }

    final top = prodCant.entries.map((e) {
      return ProductoAgregadoHistorial(
        nombre: e.key,
        cantidad: e.value,
        monto: prodMonto[e.key] ?? 0,
        pedidos: prodPedidos[e.key]?.length ?? 0,
        negocios: prodNegocios[e.key]?.toList() ?? [],
      );
    }).toList()
      ..sort((a, b) => b.cantidad.compareTo(a.cantidad));

    return ResumenHistorialPedidos(
      totalPedidos: pedidos.length,
      entregados: entregados,
      cancelados: cancelados,
      enProceso: enProceso,
      ventasTotales: ventas,
      subtotalProductos: subtotal,
      totalEnvios: envios,
      totalComisionApp: comision,
      unidadesVendidas: unidades,
      topProductos: top.take(8).toList(),
      conteoPorEstado: conteoEstado,
    );
  }

  static ResumenHistorialPlataforma calcularResumenPlataforma(List<PedidoHistorialItem> pedidos) {
    final general = calcularResumen(pedidos);
    final negPedidos = <String, int>{};
    final negVentas = <String, double>{};
    final negComision = <String, double>{};
    final negNombre = <String, String>{};
    var comisionTotal = 0.0;

    for (final p in pedidos) {
      if (p.cancelado) continue;
      final id = p.negocioId.isNotEmpty ? p.negocioId : 'sin_id';
      negNombre[id] = p.negocioNombre.isNotEmpty ? p.negocioNombre : 'Sin nombre';
      negPedidos[id] = (negPedidos[id] ?? 0) + 1;
      negVentas[id] = (negVentas[id] ?? 0) + p.totalCobrado;
      negComision[id] = (negComision[id] ?? 0) + p.comisionApp;
      comisionTotal += p.comisionApp;
    }

    final topNeg = negPedidos.entries.map((e) {
      return NegocioAgregadoHistorial(
        negocioId: e.key,
        nombre: negNombre[e.key] ?? 'Negocio',
        pedidos: e.value,
        ventas: negVentas[e.key] ?? 0,
        comisionApp: negComision[e.key] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.ventas.compareTo(a.ventas));

    return ResumenHistorialPlataforma(
      general: general,
      comisionTotalApp: comisionTotal,
      negociosConPedidos: negPedidos.length,
      topNegocios: topNeg,
    );
  }

  static List<NegocioAgregadoHistorial> agruparNegocios(List<PedidoHistorialItem> pedidos) {
    return calcularResumenPlataforma(pedidos).topNegocios;
  }

  static List<ProductoAgregadoHistorial> agruparProductos(List<PedidoHistorialItem> pedidos) {
    return todosProductos(pedidos);
  }

  static List<ProductoAgregadoHistorial> todosProductos(List<PedidoHistorialItem> pedidos) {
    final activos = pedidos.where((p) => !p.cancelado).toList();
    final prodCant = <String, int>{};
    final prodMonto = <String, double>{};
    final prodPedidos = <String, Set<String>>{};
    final prodNegocios = <String, Set<String>>{};

    for (final p in activos) {
      for (final item in p.productos) {
        final nombre = (item['nombre'] ?? 'Sin nombre').toString();
        final qty = (item['cantidad'] as num?)?.toInt() ?? 1;
        final precio = (item['precio'] as num?)?.toDouble() ?? 0;
        prodCant[nombre] = (prodCant[nombre] ?? 0) + qty;
        prodMonto[nombre] = (prodMonto[nombre] ?? 0) + precio * qty;
        prodPedidos.putIfAbsent(nombre, () => {}).add(p.id);
        prodNegocios.putIfAbsent(nombre, () => {}).add(p.negocioNombre);
      }
    }

    return prodCant.entries
        .map((e) => ProductoAgregadoHistorial(
              nombre: e.key,
              cantidad: e.value,
              monto: prodMonto[e.key] ?? 0,
              pedidos: prodPedidos[e.key]?.length ?? 0,
              negocios: prodNegocios[e.key]?.toList() ?? [],
            ))
        .toList()
      ..sort((a, b) => b.cantidad.compareTo(a.cantidad));
  }

  static List<UsuarioAgregadoHistorial> agruparUsuarios(List<PedidoHistorialItem> pedidos) {
    final map = <String, ({int pedidos, int cancelados, int entregados, double gasto})>{};

    for (final p in pedidos) {
      final uid = p.clienteId;
      if (uid == null || uid.isEmpty) continue;
      final actual = map[uid] ?? (pedidos: 0, cancelados: 0, entregados: 0, gasto: 0.0);
      map[uid] = (
        pedidos: actual.pedidos + 1,
        cancelados: actual.cancelados + (p.cancelado ? 1 : 0),
        entregados: actual.entregados + (p.entregado ? 1 : 0),
        gasto: actual.gasto + (p.cancelado ? 0 : p.totalCobrado),
      );
    }

    return map.entries
        .map((e) => UsuarioAgregadoHistorial(
              uid: e.key,
              pedidos: e.value.pedidos,
              cancelados: e.value.cancelados,
              entregados: e.value.entregados,
              gastoTotal: e.value.gasto,
            ))
        .toList()
      ..sort((a, b) => b.gastoTotal.compareTo(a.gastoTotal));
  }

  static List<PedidoHistorialItem> pedidosDeNegocio(List<PedidoHistorialItem> pedidos, String negocioId) {
    return pedidos.where((p) => p.negocioId == negocioId).toList();
  }

  static List<PedidoHistorialItem> pedidosDeUsuario(List<PedidoHistorialItem> pedidos, String uid) {
    return pedidos.where((p) => p.clienteId == uid).toList();
  }

  static List<PedidoHistorialItem> pedidosConProducto(List<PedidoHistorialItem> pedidos, String nombreProducto) {
    return pedidos.where((p) {
      return p.productos.any((item) => (item['nombre'] ?? '').toString() == nombreProducto);
    }).toList();
  }

  static List<PedidoHistorialItem> filtrarPorTexto(
    List<PedidoHistorialItem> pedidos,
    String busqueda,
  ) {
    final q = busqueda.trim().toLowerCase();
    if (q.isEmpty) return pedidos;
    return pedidos.where((p) {
      if (p.negocioNombre.toLowerCase().contains(q)) return true;
      if (p.negocioId.toLowerCase().contains(q)) return true;
      if (p.id.toLowerCase().contains(q)) return true;
      if ((p.clienteId ?? '').toLowerCase().contains(q)) return true;
      return p.productos.any((item) => (item['nombre'] ?? '').toString().toLowerCase().contains(q));
    }).toList();
  }

  static String etiquetaVista(VistaAdminActividad v) {
    switch (v) {
      case VistaAdminActividad.resumen:
        return 'Resumen';
      case VistaAdminActividad.pedidos:
        return 'Pedidos';
      case VistaAdminActividad.negocios:
        return 'Negocios';
      case VistaAdminActividad.productos:
        return 'Productos';
      case VistaAdminActividad.usuarios:
        return 'Usuarios';
    }
  }

  static List<PedidoHistorialItem> filtrarPorNegocio(
    List<PedidoHistorialItem> pedidos,
    String busquedaNegocio,
  ) {
    final q = busquedaNegocio.trim().toLowerCase();
    if (q.isEmpty) return pedidos;
    return pedidos
        .where((p) =>
            p.negocioNombre.toLowerCase().contains(q) ||
            p.negocioId.toLowerCase().contains(q))
        .toList();
  }

  static Color estadoColor(String estado) {
    switch (estado) {
      case 'Entregado':
        return Colors.green;
      case 'Cancelado':
        return Colors.red;
      case 'Preparando':
        return Colors.blueAccent;
      case 'Confirmada':
        return Colors.green;
      case 'En Camino':
      case 'Listo para recoger':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }
}
