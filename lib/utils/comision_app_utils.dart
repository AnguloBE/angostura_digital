import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ComisionAppConfig {
  final double porcentaje;
  final double maximoPorPedido;
  final String pagadaPor;
  final String periodo;

  const ComisionAppConfig({
    this.porcentaje = 10,
    this.maximoPorPedido = 10,
    this.pagadaPor = 'negocio',
    this.periodo = 'mensual',
  });

  factory ComisionAppConfig.desdeMap(Map<String, dynamic>? data) {
    if (data == null) return const ComisionAppConfig();
    return ComisionAppConfig(
      porcentaje: (data['comision_porcentaje'] ?? 10).toDouble(),
      maximoPorPedido: (data['comision_maximo'] ?? 10).toDouble(),
      pagadaPor: (data['comision_pagada_por'] ?? 'negocio').toString(),
      periodo: (data['comision_periodo'] ?? 'mensual').toString(),
    );
  }

  Map<String, dynamic> aFirestore() => {
        'comision_porcentaje': porcentaje,
        'comision_maximo': maximoPorPedido,
        'comision_pagada_por': pagadaPor,
        'comision_periodo': periodo,
      };
}

class ComisionAppUtils {
  static const periodos = ['semanal', 'quincenal', 'mensual'];
  static const String estadoActivo = 'activo';
  static const String estadoPausado = 'pausado';

  static double leerAcumulada(dynamic valor) {
    if (valor == null) return 0;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString()) ?? 0;
  }

  static double leerUltimoPagoMonto(Map<String, dynamic> data) {
    final monto = data['comision_ultimo_pago_monto'];
    if (monto != null) return leerAcumulada(monto);
    return 0;
  }

  static Timestamp? leerUltimoPagoFecha(Map<String, dynamic> data) {
    final ts = data['comision_ultimo_pago_fecha'];
    if (ts is Timestamp) return ts;
    final legacy = data['comision_ultimo_cobro'];
    if (legacy is Timestamp) return legacy;
    return null;
  }

  static String formatearFechaPago(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate().toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  static String? textoUltimoPago(Map<String, dynamic> data) {
    final fecha = leerUltimoPagoFecha(data);
    if (fecha == null) return null;
    final monto = leerUltimoPagoMonto(data);
    if (monto <= 0) return 'Último pago: ${formatearFechaPago(fecha)}';
    return 'Último pago: \$${monto.toStringAsFixed(2)} · ${formatearFechaPago(fecha)}';
  }

  static double calcularMonto(double subtotal, ComisionAppConfig config) {
    if (subtotal <= 0 || config.porcentaje <= 0) return 0;
    final porcentaje = subtotal * (config.porcentaje / 100);
    if (config.maximoPorPedido > 0 && porcentaje > config.maximoPorPedido) {
      return config.maximoPorPedido;
    }
    return double.parse(porcentaje.toStringAsFixed(2));
  }

  /// Solo reinicia si ya había un inicio de periodo y este venció (no por inicio nulo).
  static bool debeReiniciarPeriodo(Timestamp? inicio, String periodo) {
    if (inicio == null) return false;
    final dias = DateTime.now().difference(inicio.toDate()).inDays;
    switch (periodo) {
      case 'semanal':
        return dias >= 7;
      case 'quincenal':
        return dias >= 15;
      default:
        return dias >= 30;
    }
  }

  static String etiquetaPeriodo(String periodo) {
    switch (periodo) {
      case 'semanal':
        return 'Semanal';
      case 'quincenal':
        return 'Quincenal';
      default:
        return 'Mensual';
    }
  }

  static String etiquetaPagador(String pagadaPor) {
    if (pagadaPor == 'cliente') {
      return 'Cliente paga extra en pedido';
    }
    return 'Negocio absorbe (sin extra al cliente)';
  }

  static String resumenComision(ComisionAppConfig config) {
    final max = config.maximoPorPedido > 0
        ? ' · máx \$${config.maximoPorPedido.toStringAsFixed(0)}'
        : '';
    return '${config.porcentaje.toStringAsFixed(0)}%$max · ${etiquetaPagador(config.pagadaPor)} · cobro ${etiquetaPeriodo(config.periodo).toLowerCase()}';
  }

  /// Siempre se suma al saldo del periodo; solo cambia si el cliente ve cargo en el carrito.
  static bool cobrarExtraAlCliente(String pagadaPor) => pagadaPor == 'cliente';

  static bool esActivo(String? estado) =>
      estado == estadoActivo || estado == 'aprobado';

  static bool esPausado(String? estado) => estado == estadoPausado;

  static bool visibleParaClientes(String? estado) => esActivo(estado);

  static String normalizarEstado(String? estado) {
    if (esPausado(estado)) return estadoPausado;
    return estadoActivo;
  }

  static ({Color color, String etiqueta}) estadoVisual(String? estado) {
    if (esPausado(estado)) {
      return (color: Colors.deepPurple, etiqueta: 'Pausado');
    }
    return (color: Colors.green, etiqueta: 'Activo');
  }
}
