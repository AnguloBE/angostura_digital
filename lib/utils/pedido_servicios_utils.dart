import 'package:angostura_digital/utils/categorias_negocio.dart';
import 'package:angostura_digital/utils/servicio_cita_utils.dart';

/// Flujo simplificado para negocios de categoría Servicios (citas).
class PedidoServiciosUtils {
  PedidoServiciosUtils._();

  static const String estadoConfirmada = 'Confirmada';
  static const String estadoPendiente = 'Pendiente';
  static const String estadoCancelado = 'Cancelado';

  static bool esNegocioServicios(String? categoria) =>
      CategoriasNegocio.esServicios(categoria);

  static bool esPedidoServicios(Map<String, dynamic> data) {
    if (data['tipo_negocio'] == 'servicios') return true;
    if (data['tiene_cita'] == true) return true;
    final metodo = data['metodo_entrega']?.toString();
    return metodo == 'cita' || metodo == 'servicio_solicitud';
  }

  static bool usarFlujoCitas(String? categoriaNegocio, Map<String, dynamic>? pedido) {
    if (esNegocioServicios(categoriaNegocio)) return true;
    if (pedido != null && esPedidoServicios(pedido)) return true;
    return false;
  }

  static bool estaFinalizado(String estado) =>
      estado == estadoConfirmada || estado == 'Entregado';

  static String etiquetaEstadoParaCliente(String estado, Map<String, dynamic> data) {
    if (!esPedidoServicios(data)) return estado;
    switch (estado) {
      case estadoPendiente:
        return 'Pendiente';
      case estadoConfirmada:
        return 'Cita confirmada';
      case estadoCancelado:
        return 'Cita cancelada';
      default:
        return estado;
    }
  }

  static DateTime? inicioCita(Map<String, dynamic> data) {
    final directa = ServicioCitaUtils.parseCitaInicio(data['cita_inicio']);
    if (directa != null) return directa;
    final productos = data['productos'] as List? ?? [];
    for (final p in productos) {
      if (p is! Map) continue;
      final inicio = ServicioCitaUtils.parseCitaInicio(p['cita_inicio']);
      if (inicio != null) return inicio;
    }
    return null;
  }

  static int duracionCitaMinutos(Map<String, dynamic> data) {
    final directa = data['duracion_minutos'];
    if (directa is num && directa > 0) return directa.toInt();
    final productos = data['productos'] as List? ?? [];
    for (final p in productos) {
      if (p is! Map) continue;
      final d = (p['duracion_minutos'] as num?)?.toInt();
      if (d != null && d > 0) return d;
    }
    return ServicioCitaUtils.intervaloMinutosDefault;
  }

  /// La cita sigue en la bandeja hasta 3 horas después de terminar.
  /// Una solicitud sin hora se queda mientras esté pendiente.
  static bool sigueEnBandeja(Map<String, dynamic> data, {DateTime? ahora}) {
    final now = ahora ?? DateTime.now();
    final estado = (data['estado'] ?? '').toString();
    if (estado == estadoCancelado) return false;
    final inicio = inicioCita(data);
    if (inicio != null) {
      final fin = inicio.add(Duration(minutes: duracionCitaMinutos(data)));
      return now.isBefore(fin.add(const Duration(hours: 3)));
    }
    return estado == estadoPendiente;
  }

  static String grupoDiaCita(DateTime inicio, {DateTime? ahora}) {
    final now = ahora ?? DateTime.now();
    final dia = DateTime(inicio.year, inicio.month, inicio.day);
    final hoy = DateTime(now.year, now.month, now.day);
    if (dia == hoy) return 'Hoy';
    if (dia == hoy.add(const Duration(days: 1))) return 'Mañana';
    return ServicioCitaUtils.formatearFechaConDia(inicio);
  }

  static String resumenCitaDesdePedido(Map<String, dynamic> data) {
    final productos = data['productos'] as List? ?? [];
    for (final p in productos) {
      if (p is! Map) continue;
      final inicio = ServicioCitaUtils.parseCitaInicio(p['cita_inicio']);
      if (inicio != null) {
        final nombre = p['nombre']?.toString() ?? 'Servicio';
        return '$nombre · ${ServicioCitaUtils.formatearCita(inicio)}';
      }
    }
    if (data['metodo_entrega'] == 'cita') {
      return 'Cita en el local';
    }
    return '';
  }
}
