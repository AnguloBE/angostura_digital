import 'package:cloud_firestore/cloud_firestore.dart';

/// Solo el estado Preparando debe mostrar el tiempo estimado activo del pedido.
bool debeMostrarTiempoEnPedido(String estado) => estado == 'Preparando';

String formatearFechaHoraCorta(DateTime dt) {
  final hora12 = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  final hoy = DateTime.now();
  final esHoy = dt.year == hoy.year && dt.month == hoy.month && dt.day == hoy.day;
  final fecha = esHoy
      ? 'hoy'
      : '${dt.day}/${dt.month}/${dt.year}';
  return '$fecha $hora12:${dt.minute.toString().padLeft(2, '0')} $ampm';
}

String? formatearTimestampFirestore(dynamic valor) {
  if (valor is! Timestamp) return null;
  return formatearFechaHoraCorta(valor.toDate());
}

bool esFechaFirestoreHoy(dynamic valor) {
  if (valor is! Timestamp) return false;
  final dt = valor.toDate();
  final hoy = DateTime.now();
  return dt.year == hoy.year && dt.month == hoy.month && dt.day == hoy.day;
}

/// Tiempo estimado del negocio solo si se actualizó hoy (mismo día calendario).
String? ultimoTiempoEstimadoHoy(Map<String, dynamic> data) {
  if (!esFechaFirestoreHoy(data['fecha_ultimo_tiempo'])) return null;
  final tiempo = (data['ultimo_tiempo_estimado'] ?? '').toString().trim();
  return tiempo.isEmpty ? null : tiempo;
}

String? textoUltimoTiempoNegocio(Map<String, dynamic> data, {String etiqueta = 'Último tiempo estimado'}) {
  final tiempo = ultimoTiempoEstimadoHoy(data);
  if (tiempo == null) return null;
  final fecha = formatearTimestampFirestore(data['fecha_ultimo_tiempo']);
  if (fecha != null) return '$etiqueta: $tiempo · $fecha';
  return '$etiqueta: $tiempo';
}
