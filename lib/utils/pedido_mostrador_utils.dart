import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:angostura_digital/utils/comision_app_utils.dart';

class PedidoMostradorUtils {
  PedidoMostradorUtils._();

  static double calcularSubtotal(List<Map<String, dynamic>> productos) {
    var total = 0.0;
    for (final p in productos) {
      final precio = (p['precio'] as num?)?.toDouble() ?? 0;
      final cant = (p['cantidad'] as num?)?.toInt() ?? 1;
      total += precio * cant;
    }
    return total;
  }

  static Future<Map<String, dynamic>> totalesActualizados({
    required List<Map<String, dynamic>> productos,
    required Map<String, dynamic> pedido,
    required String negocioId,
  }) async {
    final subtotal = calcularSubtotal(productos);

    ComisionAppConfig config = const ComisionAppConfig();
    try {
      final neg = await FirebaseFirestore.instance.collection('negocios').doc(negocioId).get();
      if (neg.exists) config = ComisionAppConfig.desdeMap(neg.data());
    } catch (_) {}

    final comisionMonto = ComisionAppUtils.calcularMonto(subtotal, config);
    final costoEnvio = (pedido['costo_envio'] as num?)?.toDouble() ?? 0;
    final extraComision =
        ComisionAppUtils.cobrarExtraAlCliente(config.pagadaPor) ? comisionMonto : 0;
    final total = subtotal + costoEnvio + extraComision;

    final datos = <String, dynamic>{
      'productos': productos,
      'subtotal': subtotal,
      'comision_app': comisionMonto,
      'total': total,
    };

    final metodoPago = (pedido['metodo_pago'] ?? 'efectivo').toString();
    if (metodoPago == 'efectivo') {
      final pagaCon = (pedido['paga_con'] as num?)?.toDouble();
      if (pagaCon != null && pagaCon > 0) {
        datos['cambio'] = pagaCon - total;
      }
    }

    return datos;
  }

  static String textoDireccionMostrador(String nombreCliente) {
    final nombre = nombreCliente.trim();
    return nombre.isNotEmpty
        ? 'Pedido en el local · $nombre'
        : 'Pedido tomado en el mostrador.';
  }

  static bool puedeEditarContenido(String? estado) {
    final e = estado ?? '';
    return e != 'Entregado' && e != 'Cancelado';
  }
}
