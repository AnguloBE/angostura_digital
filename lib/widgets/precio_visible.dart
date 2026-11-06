import 'package:flutter/material.dart';
import 'package:angostura_digital/utils/precio_producto_utils.dart';

/// Precio que ve quien compra: venta, o venta tachada más el descuento.
class PrecioVisible extends StatelessWidget {
  final PrecioCobrado cobro;
  final bool activo;
  final double fontSize;

  const PrecioVisible({
    super.key,
    required this.cobro,
    this.activo = true,
    this.fontSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    final color = activo ? Colors.green : Colors.grey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cobro.aplicado)
          Text(
            PrecioProducto.texto(cobro.venta),
            style: TextStyle(
              fontSize: fontSize - 4,
              color: Colors.grey,
              decoration: TextDecoration.lineThrough,
              height: 1.1,
            ),
          ),
        Text(
          PrecioProducto.texto(cobro.cobrar),
          style: TextStyle(
            color: cobro.aplicado ? Colors.teal.shade800 : color,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
            height: 1.1,
          ),
        ),
        if (cobro.aplicado)
          Text(
            'Precio con descuento',
            style: TextStyle(
              fontSize: 11,
              color: Colors.teal.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

/// Costo, venta y descuento. Solo en el panel del negocio.
class PreciosInternos extends StatelessWidget {
  final Map<String, dynamic> data;

  const PreciosInternos({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final costo = PrecioProducto.costo(data);
    final venta = PrecioProducto.venta(data);
    final desc = PrecioProducto.descuento(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (costo > 0)
          Text(
            'Costo ${PrecioProducto.texto(costo)}',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700, height: 1.2),
          ),
        Text(
          'Venta ${PrecioProducto.texto(venta)}',
          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16, height: 1.2),
        ),
        if (desc > 0)
          Text(
            'Descuento ${PrecioProducto.texto(desc)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.teal.shade800,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
      ],
    );
  }
}
