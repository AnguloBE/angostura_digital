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
