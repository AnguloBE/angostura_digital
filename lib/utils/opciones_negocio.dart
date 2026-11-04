import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:angostura_digital/utils/categorias_negocio.dart';

/// Lo que el administrador puede prender o apagar en un negocio.
/// Si no hay valor guardado, se usa lo normal de ese tipo.
class OpcionesNegocio {
  final bool stock;
  final bool repisas;
  final bool whatsappEncargos;

  const OpcionesNegocio({
    required this.stock,
    required this.repisas,
    required this.whatsappEncargos,
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
    return OpcionesNegocio(
      stock: stock,
      repisas: repisas,
      whatsappEncargos: whatsapp,
    );
  }

  OpcionesNegocio copiar({
    bool? stock,
    bool? repisas,
    bool? whatsappEncargos,
  }) {
    final nuevoStock = stock ?? this.stock;
    return OpcionesNegocio(
      stock: nuevoStock,
      repisas: nuevoStock ? (repisas ?? this.repisas) : false,
      whatsappEncargos: whatsappEncargos ?? this.whatsappEncargos,
    );
  }

  Map<String, dynamic> aMapa() => {
        'stock': stock,
        'repisas': repisas && stock,
        'whatsapp_encargos': whatsappEncargos,
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
