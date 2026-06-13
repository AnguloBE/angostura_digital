import 'package:flutter/material.dart';
import 'package:angostura_digital/utils/pedido_ubicacion_utils.dart';
import 'package:angostura_digital/utils/pedidos_historial_utils.dart';

class PedidoUbicacionEntregaBlock extends StatelessWidget {
  final PedidoHistorialItem pedido;
  final bool compacto;

  const PedidoUbicacionEntregaBlock({
    super.key,
    required this.pedido,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    if (pedido.metodoEntrega == 'recoger' || pedido.metodoEntrega == 'mostrador') {
      return const SizedBox.shrink();
    }

    final entrega = pedido.coordenadasEntrega;
    if (entrega == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.location_off, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sin coordenadas GPS en este pedido',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      );
    }

    final distanciaTexto = _textoDistancia();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pin_drop, size: 16, color: Colors.green.shade800),
              const SizedBox(width: 6),
              Text(
                'Ubicación de entrega',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade900),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            PedidoUbicacionUtils.formatear(entrega),
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          ),
          if (distanciaTexto != null) ...[
            const SizedBox(height: 4),
            Text(distanciaTexto, style: TextStyle(fontSize: 12, color: Colors.green.shade800)),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => PedidoUbicacionUtils.abrirUbicacion(context, entrega),
            icon: const Icon(Icons.map, size: 16),
            label: const Text('Ver en Maps'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }

  String? _textoDistancia() {
    if (pedido.distanciaEnvioKm != null && pedido.distanciaCobroKm != null) {
      if ((pedido.distanciaEnvioKm! - pedido.distanciaCobroKm!).abs() > 0.01) {
        return 'Distancia real: ${pedido.distanciaEnvioKm!.toStringAsFixed(2)} km · Cobro: ${pedido.distanciaCobroKm!.toStringAsFixed(2)} km';
      }
      return 'Distancia: ${pedido.distanciaEnvioKm!.toStringAsFixed(2)} km';
    }
    if (pedido.distanciaEnvioKm != null) {
      return 'Distancia: ${pedido.distanciaEnvioKm!.toStringAsFixed(2)} km';
    }
    if (pedido.distanciaCobroKm != null) {
      return 'Distancia de cobro: ${pedido.distanciaCobroKm!.toStringAsFixed(2)} km';
    }
    return null;
  }
}
