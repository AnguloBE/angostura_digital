import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:angostura_digital/utils/categorias_negocio.dart';

/// Lo que el administrador puede prender o apagar en un negocio.
/// Si no hay valor guardado, se usa lo normal de ese tipo.
class OpcionesNegocio {
  final bool stock;
  final bool repisas;
  final bool whatsappEncargos;

  /// Precios distintos: costo, venta y precio para clientes con descuento.
  final bool clientesDescuento;

  const OpcionesNegocio({
    required this.stock,
    required this.repisas,
    required this.whatsappEncargos,
    required this.clientesDescuento,
  });

  static bool tipoPuedeStock(String? categoria) =>
      CategoriasNegocio.esProductos(categoria) ||
      CategoriasNegocio.esFarmacia(categoria) ||
      CategoriasNegocio.esBodega(categoria) ||
      CategoriasNegocio.esImprenta(categoria);

  static OpcionesNegocio porDefecto(String? categoria) {
    final conStock = CategoriasNegocio.esProductos(categoria) ||
        CategoriasNegocio.esFarmacia(categoria) ||
        CategoriasNegocio.esBodega(categoria);
    return OpcionesNegocio(
      stock: conStock,
      repisas: conStock,
      whatsappEncargos: CategoriasNegocio.esImprenta(categoria),
      clientesDescuento: false,
    );
  }

  static OpcionesNegocio desde(String? categoria, Map<String, dynamic>? data) {
    final base = porDefecto(categoria);
    final raw = data?['opciones'];
    if (raw is! Map) return base;

    bool leer(String clave, bool fallback) {
      if (!raw.containsKey(clave)) return fallback;
      return raw[clave] == true;
    }

    final stock = tipoPuedeStock(categoria) ? leer('stock', base.stock) : false;
    final repisas =
        stock && tipoPuedeStock(categoria) ? leer('repisas', base.repisas) : false;
    final whatsapp = CategoriasNegocio.visibleAlPublico(categoria)
        ? leer('whatsapp_encargos', base.whatsappEncargos)
        : false;
    final descuento = CategoriasNegocio.visibleAlPublico(categoria)
        ? leer('clientes_descuento', base.clientesDescuento)
        : false;
    return OpcionesNegocio(
      stock: stock,
      repisas: repisas,
      whatsappEncargos: whatsapp,
      clientesDescuento: descuento,
    );
  }

  OpcionesNegocio copiar({
    bool? stock,
    bool? repisas,
    bool? whatsappEncargos,
    bool? clientesDescuento,
  }) {
    final nuevoStock = stock ?? this.stock;
    return OpcionesNegocio(
      stock: nuevoStock,
      repisas: nuevoStock ? (repisas ?? this.repisas) : false,
      whatsappEncargos: whatsappEncargos ?? this.whatsappEncargos,
      clientesDescuento: clientesDescuento ?? this.clientesDescuento,
    );
  }

  Map<String, dynamic> aMapa() => {
        'stock': stock,
        'repisas': repisas && stock,
        'whatsapp_encargos': whatsappEncargos,
        'clientes_descuento': clientesDescuento,
      };
}

/// Lee las opciones del negocio y las pasa al resto de la pantalla.
class ConOpcionesNegocio extends StatelessWidget {
  final String negocioId;
  final String? categoria;
  final Widget Function(BuildContext context, OpcionesNegocio opciones) builder;

  const ConOpcionesNegocio({
    super.key,
    required this.negocioId,
    required this.categoria,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('negocios').doc(negocioId).snapshots(),
      builder: (context, snap) {
        return builder(
          context,
          OpcionesNegocio.desde(categoria, snap.data?.data()),
        );
      },
    );
  }
}
