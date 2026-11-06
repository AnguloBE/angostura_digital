import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:angostura_digital/utils/categorias_negocio.dart';

/// Lo que un negocio puede prender o apagar.
/// Repisas, envíos y clientes con descuento los cambia el dueño o el encargado.
/// Si no hay valor guardado, se usa lo normal de ese tipo.
class OpcionesNegocio {
  final bool stock;
  final bool repisas;
  final bool whatsappEncargos;

  /// Pedidos a domicilio. Apagado, el cliente solo puede recoger y seguir pagando.
  final bool enviosCobros;

  /// Precios distintos: costo, venta y precio para clientes con descuento.
  final bool clientesDescuento;

  const OpcionesNegocio({
    required this.stock,
    required this.repisas,
    required this.whatsappEncargos,
    required this.enviosCobros,
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
      enviosCobros: CategoriasNegocio.puedeEnvios(categoria),
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
    final envios = CategoriasNegocio.puedeEnvios(categoria)
        ? leer('envios_cobros', base.enviosCobros)
        : false;
    final descuento = CategoriasNegocio.visibleAlPublico(categoria)
        ? leer('clientes_descuento', base.clientesDescuento)
        : false;
    return OpcionesNegocio(
      stock: stock,
      repisas: repisas,
      whatsappEncargos: whatsapp,
      enviosCobros: envios,
      clientesDescuento: descuento,
    );
  }

  OpcionesNegocio copiar({
    bool? stock,
    bool? repisas,
    bool? whatsappEncargos,
    bool? enviosCobros,
    bool? clientesDescuento,
  }) {
    final nuevoStock = stock ?? this.stock;
    return OpcionesNegocio(
      stock: nuevoStock,
      repisas: nuevoStock ? (repisas ?? this.repisas) : false,
      whatsappEncargos: whatsappEncargos ?? this.whatsappEncargos,
      enviosCobros: enviosCobros ?? this.enviosCobros,
      clientesDescuento: clientesDescuento ?? this.clientesDescuento,
    );
  }

  Map<String, dynamic> aMapa() => {
        'stock': stock,
        'repisas': repisas && stock,
        'whatsapp_encargos': whatsappEncargos,
        'envios_cobros': enviosCobros,
        'clientes_descuento': clientesDescuento,
      };

  /// El dueño o encargado cambia una sola función sin perder las demás.
  static Future<void> guardarCampo(
    String negocioId, {
    bool? enviosCobros,
    bool? repisas,
    bool? clientesDescuento,
  }) async {
    final ref = FirebaseFirestore.instance.collection('negocios').doc(negocioId);
    final doc = await ref.get();
    final data = doc.data();
    final actual = desde(data?['categoria']?.toString(), data);
    final siguiente = repisas == true
        ? actual.copiar(
            stock: true,
            repisas: true,
            enviosCobros: enviosCobros,
            clientesDescuento: clientesDescuento,
          )
        : actual.copiar(
            enviosCobros: enviosCobros,
            repisas: repisas,
            clientesDescuento: clientesDescuento,
          );
    await ref.update({'opciones': siguiente.aMapa()});
  }
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
