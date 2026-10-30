import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:angostura_digital/services/negocio_ubicacion_service.dart';

class ProductoStockService {
  ProductoStockService._();

  static Future<QueryDocumentSnapshot<Map<String, dynamic>>?> buscarPorCodigo(
    String negocioId,
    String codigo,
  ) async {
    final limpio = codigo.trim();
    if (limpio.isEmpty) return null;

    final snap = await FirebaseFirestore.instance
        .collection('productos')
        .where('negocio_id', isEqualTo: negocioId)
        .where('codigo_barras', isEqualTo: limpio)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first;
  }

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> listarProductosTienda(
    String negocioId,
  ) async {
    final snap = await FirebaseFirestore.instance
        .collection('productos')
        .where('negocio_id', isEqualTo: negocioId)
        .get();

    final lista = snap.docs.where((d) => d.data()['es_servicio'] != true).toList();
    lista.sort((a, b) {
      final na = (a.data()['nombre'] ?? '').toString().toLowerCase();
      final nb = (b.data()['nombre'] ?? '').toString().toLowerCase();
      return na.compareTo(nb);
    });
    return lista;
  }

  static List<QueryDocumentSnapshot<Map<String, dynamic>>> filtrarPorNombre(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> productos,
    String consulta,
  ) {
    final q = consulta.trim().toLowerCase();
    if (q.isEmpty) return const [];

    return productos.where((doc) {
      final data = doc.data();
      final nombre = (data['nombre'] ?? '').toString().toLowerCase();
      final desc = (data['descripcion'] ?? '').toString().toLowerCase();
      final codigo = (data['codigo_barras'] ?? '').toString().toLowerCase();
      return nombre.contains(q) || desc.contains(q) || codigo.contains(q);
    }).toList();
  }

  static Future<void> agregarStock({
    required DocumentReference<Map<String, dynamic>> productoRef,
    required Map<String, dynamic> productoData,
    required String lugar,
    required int cantidad,
  }) async {
    final actuales = NegocioUbicacionService.ubicacionesProducto(productoData);
    final nuevas = [...actuales];
    final idx = nuevas.indexWhere(
      (u) => u.lugar.toLowerCase() == lugar.toLowerCase(),
    );
    if (idx >= 0) {
      nuevas[idx] = nuevas[idx].copyWith(cantidad: nuevas[idx].cantidad + cantidad);
    } else {
      nuevas.add(StockUbicacion(lugar: lugar, cantidad: cantidad));
    }

    await productoRef.update({
      'ubicaciones': nuevas.map((u) => u.toMap()).toList(),
      'stock_total': NegocioUbicacionService.sumarCantidades(nuevas),
      'controla_inventario': true,
    });
  }
}
