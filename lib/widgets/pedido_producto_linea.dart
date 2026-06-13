import 'package:flutter/material.dart';
import 'package:angostura_digital/utils/producto_pedido_utils.dart';
import 'package:angostura_digital/utils/servicio_cita_utils.dart';
import 'package:angostura_digital/widgets/square_image.dart';

/// Línea de producto en un pedido: foto, nombre, medida/detalle y precio.
class PedidoProductoLinea extends StatelessWidget {
  const PedidoProductoLinea({
    super.key,
    required this.item,
    this.mostrarVerDetalle = true,
    this.tamanoFoto = 56,
    this.surtido,
  });

  final Map<String, dynamic> item;
  final bool mostrarVerDetalle;
  final double tamanoFoto;

  /// Piezas ya surtidas de esta línea (null = no mostrar progreso de surtido).
  final int? surtido;

  @override
  Widget build(BuildContext context) {
    final cantidad = item['cantidad'] ?? 1;
    final nombre = item['nombre']?.toString() ?? '';
    final precio = (item['precio'] as num?)?.toDouble() ?? 0;
    final subtitulo = ProductoPedidoUtils.subtituloLinea(item);
    final personalizacion = ProductoPedidoUtils.personalizacionLinea(item);
    final esPromo = ProductoPedidoUtils.esPromocionItem(item);
    final fotoUrl = ProductoPedidoUtils.fotoUrlDesdeItem(item);
    String? lineaServicio;
    if (item['es_servicio'] == true) {
      final cita = ServicioCitaUtils.parseCitaInicio(item['cita_inicio']);
      lineaServicio = item['tipo_servicio'] == 'cita' && cita != null
          ? '📅 ${ServicioCitaUtils.formatearCita(cita)}'
          : '🏠 Solicitud a domicilio';
    }

    return InkWell(
      onTap: mostrarVerDetalle
          ? () => ProductoPedidoUtils.mostrarDetallePedido(context, item)
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SquareImage(
              imageUrl: fotoUrl,
              size: tamanoFoto,
              borderRadius: BorderRadius.circular(8),
              useCachedNetwork: true,
              placeholder: Container(
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: Icon(
                  esPromo ? Icons.local_offer : Icons.fastfood_outlined,
                  color: Colors.grey.shade500,
                  size: tamanoFoto * 0.4,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (esPromo)
                        const Padding(
                          padding: EdgeInsets.only(right: 6, top: 2),
                          child: Icon(
                            Icons.local_offer,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          '${cantidad}x $nombre',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (subtitulo != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blueGrey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (personalizacion != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      personalizacion,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (lineaServicio != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      lineaServicio,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (mostrarVerDetalle)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        esPromo
                            ? 'Toca para ver detalles de la promoción'
                            : 'Toca para ver detalles',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blueAccent.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '\$${(precio * (cantidad as num)).toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.black54),
                ),
                if (surtido != null) ...[
                  const SizedBox(height: 4),
                  _badgeSurtido(surtido!, (cantidad).toInt()),
                ],
              ],
            ),
            if (mostrarVerDetalle) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.info_outline,
                size: 20,
                color: Colors.blueAccent.shade400,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badgeSurtido(int surtido, int total) {
    final completo = surtido >= total && total > 0;
    final color = completo ? Colors.green : Colors.orange.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completo ? Icons.check_circle : Icons.shopping_bag_outlined,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            completo ? 'Surtido' : '$surtido/$total',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
