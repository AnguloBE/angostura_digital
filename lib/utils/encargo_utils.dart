import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Pedido para una fecha futura: un pastel el 15 a las 4, sushis el viernes.
class EncargoUtils {
  EncargoUtils._();

  static const _dias = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static const _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static DateTime? leerFecha(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  static bool esEncargo(Map<String, dynamic> data) =>
      data['es_encargo'] == true && leerFecha(data['fecha_encargo']) != null;

  static bool cerrado(Map<String, dynamic> data) {
    final estado = (data['estado'] ?? '').toString();
    return estado == 'Entregado' || estado == 'Cancelado' || estado == 'Confirmada';
  }

  static bool abierto(Map<String, dynamic> data) => esEncargo(data) && !cerrado(data);

  static bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Atrasado, hoy, mañana o más adelante. Null si no es un encargo abierto.
  static String? cuando(Map<String, dynamic> data, {DateTime? ahora}) {
    if (!abierto(data)) return null;
    final fecha = leerFecha(data['fecha_encargo'])!.toLocal();
    final n = ahora ?? DateTime.now();
    if (fecha.isBefore(n)) return 'Atrasados';
    if (_mismoDia(fecha, n)) return 'Hoy';
    if (_mismoDia(fecha, n.add(const Duration(days: 1)))) return 'Mañana';
    return 'Más adelante';
  }

  /// Hoy o ya se pasó la hora: hay que atenderlo junto con los pedidos del día.
  static bool esParaAhora(Map<String, dynamic> data, {DateTime? ahora}) {
    final grupo = cuando(data, ahora: ahora);
    return grupo == 'Atrasados' || grupo == 'Hoy';
  }

  static Widget burbuja(int cantidad, {required bool urgente}) {
    if (cantidad <= 0) return const SizedBox.shrink();
    final texto = cantidad > 99 ? '99+' : '$cantidad';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: urgente ? Colors.red.shade700 : Colors.deepOrange.shade700,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        texto,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  static String texto(DateTime fecha) {
    final local = fecha.toLocal();
    final h = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final minuto = local.minute.toString().padLeft(2, '0');
    final dia = _dias[local.weekday - 1];
    final mes = _meses[local.month - 1];
    return '$dia ${local.day} de $mes, $h:$minuto $ampm';
  }

  static String? textoDePedido(Map<String, dynamic> data) {
    final fecha = leerFecha(data['fecha_encargo']);
    if (data['es_encargo'] != true || fecha == null) return null;
    return texto(fecha);
  }

  /// Sigue en la bandeja del local hasta un día después de la hora pedida.
  static bool sigueVigente(Map<String, dynamic> data, {DateTime? ahora}) {
    if (data['es_encargo'] != true) return false;
    final estado = (data['estado'] ?? '').toString();
    if (estado == 'Entregado' || estado == 'Cancelado' || estado == 'Confirmada') {
      return false;
    }
    final fecha = leerFecha(data['fecha_encargo']);
    if (fecha == null) return false;
    final limite = (ahora ?? DateTime.now()).subtract(const Duration(hours: 24));
    return !fecha.isBefore(limite);
  }

  static Widget? banner(Map<String, dynamic> data) {
    final textoFecha = textoDePedido(data);
    if (textoFecha == null) return null;
    final detalle = (data['detalle_encargo'] ?? '').toString().trim();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepOrange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.deepOrange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available, color: Colors.deepOrange.shade800, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Encargo · $textoFecha',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange.shade900,
                  ),
                ),
              ),
            ],
          ),
          if (detalle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(detalle, style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
