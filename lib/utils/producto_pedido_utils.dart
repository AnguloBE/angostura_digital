import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:angostura_digital/widgets/square_image.dart';
import 'package:angostura_digital/services/negocio_ubicacion_service.dart';

/// Detalles de productos y promociones en carrito y pedidos.
class ProductoPedidoUtils {
  static Map<String, String> detallesDesdeFirestore(Map<String, dynamic> data) {
    final detalles = <String, String>{};
    void put(String key, dynamic value) {
      if (value == null) return;
      final texto = value.toString().trim();
      if (texto.isNotEmpty) detalles[key] = texto;
    }

    put('contenido', data['peso_o_contenido']);
    put('ingredientes', data['ingredientes']);
    put('tallas', data['tallas_disponibles']);
    put('colores', data['colores']);
    put('descripcion', data['descripcion']);
    return detalles;
  }

  static Map<String, String> detallesDesdePromocion(Map<String, dynamic> data) {
    final detalles = <String, String>{'tipo': 'promocion'};
    void put(String key, dynamic value) {
      if (value == null) return;
      final texto = value.toString().trim();
      if (texto.isNotEmpty) detalles[key] = texto;
    }

    put('descripcion', data['descripcion']);
    put('titulo', data['titulo']);

    final precioNormal = data['precio_normal'];
    final precioPromo = data['precio_promo'];
    if (precioNormal is num && precioNormal > 0) {
      detalles['precio_normal'] = '\$${precioNormal.toStringAsFixed(2)}';
    }
    if (precioPromo is num) {
      detalles['precio_promo'] = '\$${precioPromo.toStringAsFixed(2)}';
    }

    final fechaFinal = data['fecha_final'];
    if (fechaFinal is Timestamp) {
      final d = fechaFinal.toDate();
      detalles['vigencia'] = '${d.day}/${d.month}/${d.year}';
    }

    put('negocio', data['nombre_negocio']);
    return detalles;
  }

  static String? fotoUrlDesdeItem(Map<String, dynamic> item) {
    final url = item['foto_url']?.toString().trim();
    if (url != null && url.isNotEmpty) return url;
    return null;
  }

  static Future<String?> fotoUrlCompleta(Map<String, dynamic> item) async {
    final guardada = fotoUrlDesdeItem(item);
    if (guardada != null) return guardada;

    final id = item['id']?.toString();
    if (id == null || id.isEmpty) return null;

    try {
      if (esPromocionItem(item)) {
        final doc = await FirebaseFirestore.instance.collection('promociones').doc(id).get();
        if (doc.exists) return doc.data()?['foto_url']?.toString();
      } else {
        final doc = await FirebaseFirestore.instance.collection('productos').doc(id).get();
        if (doc.exists) return doc.data()?['foto_url']?.toString();
        final promoDoc = await FirebaseFirestore.instance.collection('promociones').doc(id).get();
        if (promoDoc.exists) return promoDoc.data()?['foto_url']?.toString();
      }
    } catch (_) {}

    return null;
  }

  static List<String> ingredientesQuitados(Map<String, dynamic> item) {
    final raw = item['ingredientes_quitados'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  static List<String> ingredientesBase(Map<String, dynamic> item) {
    final raw = item['ingredientes_base'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  /// Ingredientes del platillo ya sin los que el cliente pidió quitar.
  static List<String> ingredientesFinales(Map<String, dynamic> item) {
    final base = ingredientesBase(item);
    if (base.isEmpty) return const [];
    final quitados = ingredientesQuitados(item).toSet();
    return base.where((i) => !quitados.contains(i)).toList();
  }

  /// Lista final de ingredientes para preparar: base sin los quitados y con
  /// los extras agregados (los extras se marcan para distinguirlos).
  static List<String> ingredientesConExtras(Map<String, dynamic> item) {
    final lista = [...ingredientesFinales(item)];
    for (final extra in extrasItem(item)) {
      final nombre = extra['nombre']?.toString() ?? '';
      if (nombre.isEmpty) continue;
      lista.add('$nombre (extra)');
    }
    return lista;
  }

  /// Lista de extras como pares {nombre, precio}.
  static List<Map<String, dynamic>> extrasItem(Map<String, dynamic> item) {
    final raw = item['extras'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => {
                'nombre': e['nombre']?.toString() ?? '',
                'precio': (e['precio'] as num?)?.toDouble() ?? 0,
              })
          .toList();
    }
    return const [];
  }

  /// Texto corto de la personalización (sin X • extra Y).
  static String? personalizacionLinea(Map<String, dynamic> item) {
    final quitados = ingredientesQuitados(item);
    final extras = extrasItem(item);
    final partes = <String>[];
    if (quitados.isNotEmpty) partes.add('Sin ${quitados.join(', ')}');
    if (extras.isNotEmpty) {
      partes.add('Extra ${extras.map((e) => e['nombre']).join(', ')}');
    }
    return partes.isEmpty ? null : partes.join('  •  ');
  }

  /// Dónde está el producto (para que el trabajador lo encuentre rápido).
  /// Primero usa lo guardado en el pedido; si no, lo busca en el producto.
  static Future<String?> ubicacionDesdePedido(Map<String, dynamic> item) async {
    final propia = NegocioUbicacionService.textoUbicaciones(item);
    if (propia != null) return propia;
    if (esPromocionItem(item)) return null;

    final id = item['id']?.toString();
    if (id == null || id.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('productos')
          .doc(id)
          .get();
      if (doc.exists && doc.data() != null) {
        return NegocioUbicacionService.textoUbicaciones(doc.data()!);
      }
    } catch (_) {}
    return null;
  }

  static bool esPromocionItem(Map<String, dynamic> item) {
    if (item['es_promocion'] == true) return true;
    final raw = item['detalles'];
    if (raw is Map && raw['tipo']?.toString() == 'promocion') return true;
    return false;
  }

  static Map<String, String> detallesDesdeItemPedido(Map<String, dynamic> item) {
    final raw = item['detalles'];
    if (raw is Map) {
      return Map<String, String>.from(
        raw.map((k, v) => MapEntry(k.toString(), v.toString())),
      );
    }
    if (item['es_promocion'] == true) {
      return detallesDesdePromocion(item);
    }
    return detallesDesdeFirestore(item);
  }

  static String? subtituloLinea(Map<String, dynamic> item) {
    if (esPromocionItem(item)) {
      final d = detallesDesdeItemPedido(item);
      if (d['descripcion'] != null) {
        final desc = d['descripcion']!;
        return desc.length > 55 ? '${desc.substring(0, 55)}…' : desc;
      }
      if (d['precio_normal'] != null && d['precio_promo'] != null) {
        return 'Oferta: ${d['precio_normal']} → ${d['precio_promo']}';
      }
      if (d['vigencia'] != null) {
        return 'Válida hasta ${d['vigencia']}';
      }
      return 'Promoción / oferta';
    }

    final d = detallesDesdeItemPedido(item);
    if (d['contenido'] != null) return d['contenido'];
    if (d['tallas'] != null && d['colores'] != null) {
      return '${d['tallas']} · ${d['colores']}';
    }
    if (d['tallas'] != null) return 'Tallas: ${d['tallas']}';
    if (d['colores'] != null) return 'Colores: ${d['colores']}';
    if (d['ingredientes'] != null) return d['ingredientes'];
    if (d['descripcion'] != null) {
      final desc = d['descripcion']!;
      return desc.length > 60 ? '${desc.substring(0, 60)}…' : desc;
    }
    return null;
  }

  static Future<Map<String, String>> detallesCompletos(
    Map<String, dynamic> item,
  ) async {
    var detalles = detallesDesdeItemPedido(item);
    final tieneDatosUtiles = detalles.entries.any(
      (e) => e.key != 'tipo' && e.value.isNotEmpty,
    );
    if (tieneDatosUtiles) return detalles;

    final id = item['id']?.toString();
    if (id == null || id.isEmpty) return detalles;

    try {
      if (esPromocionItem(item)) {
        final doc = await FirebaseFirestore.instance
            .collection('promociones')
            .doc(id)
            .get();
        if (doc.exists && doc.data() != null) {
          return detallesDesdePromocion(doc.data()!);
        }
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('productos')
            .doc(id)
            .get();
        if (doc.exists && doc.data() != null) {
          return detallesDesdeFirestore(doc.data()!);
        }
        final promoDoc = await FirebaseFirestore.instance
            .collection('promociones')
            .doc(id)
            .get();
        if (promoDoc.exists && promoDoc.data() != null) {
          return detallesDesdePromocion(promoDoc.data()!);
        }
      }
    } catch (_) {}

    return detalles;
  }

  static Future<void> mostrarDetallePedido(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final esPromo = esPromocionItem(item);
    final resultados = await Future.wait([
      detallesCompletos(item),
      fotoUrlCompleta(item),
      ubicacionDesdePedido(item),
    ]);
    if (!context.mounted) return;

    final detalles = resultados[0] as Map<String, String>;
    final fotoUrl = resultados[1] as String?;
    final ubicacion = resultados[2] as String?;

    final nombre = item['nombre']?.toString() ?? (esPromo ? 'Promoción' : 'Producto');
    final cantidad = item['cantidad'] ?? 1;
    final precio = (item['precio'] as num?)?.toDouble() ?? 0;

    final tieneBase = ingredientesBase(item).isNotEmpty;
    final filas = detalles.entries
        .where((e) => e.key != 'tipo' && !(tieneBase && e.key == 'ingredientes'))
        .map((e) => _filaDetalle(_etiqueta(e.key, esPromo: esPromo), e.value))
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            if (esPromo)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.local_offer, color: Colors.redAccent),
              ),
            Expanded(
              child: Text(nombre, style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: SquareImage(
                  imageUrl: fotoUrl,
                  size: 140,
                  borderRadius: BorderRadius.circular(12),
                  useCachedNetwork: true,
                ),
              ),
              const SizedBox(height: 14),
              if (esPromo)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Text(
                    'Promoción / oferta',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              Text(
                'Cantidad: $cantidad',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Precio en pedido: \$${precio.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              if (ubicacion != null && ubicacion.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.place, color: Colors.indigo, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '¿Dónde está?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                            Text(
                              ubicacion,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (tieneBase || extrasItem(item).isNotEmpty) ...[
                _filaDetalle(
                  'Ingredientes',
                  ingredientesConExtras(item).isEmpty
                      ? 'Sin ingredientes'
                      : ingredientesConExtras(item).join(', '),
                ),
              ],
              if (ingredientesQuitados(item).isNotEmpty) ...[
                _filaDetalle(
                  'Quitar / Sin (no poner)',
                  ingredientesQuitados(item).join(', '),
                  valorColor: Colors.redAccent,
                  etiquetaColor: Colors.redAccent,
                ),
              ],
              if (extrasItem(item).isNotEmpty) ...[
                _filaDetalle(
                  'Extras',
                  extrasItem(item)
                      .map((e) => (e['precio'] as num) > 0
                          ? '${e['nombre']} (+\$${(e['precio'] as num).toStringAsFixed(2)})'
                          : '${e['nombre']}')
                      .join(', '),
                ),
              ],
              if (filas.isEmpty)
                Text(
                  esPromo
                      ? 'No hay descripción ni precios guardados para esta promoción. '
                          'Edita la promoción en tu negocio y agrega descripción.'
                      : 'No hay medida ni detalles guardados para este producto. '
                          'Revisa el catálogo o pide al cliente confirmar la presentación.',
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 14),
                )
              else
                ...filas,
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  static String _etiqueta(String key, {required bool esPromo}) {
    switch (key) {
      case 'contenido':
        return 'Presentación / medida';
      case 'codigo_barras':
        return 'Código de barras';
      case 'ingredientes':
        return 'Ingredientes';
      case 'tallas':
        return 'Tallas';
      case 'colores':
        return 'Colores';
      case 'descripcion':
        return esPromo ? 'Descripción de la oferta' : 'Descripción';
      case 'titulo':
        return 'Título de la promoción';
      case 'precio_normal':
        return 'Precio regular';
      case 'precio_promo':
        return 'Precio en promoción';
      case 'vigencia':
        return 'Válida hasta';
      case 'negocio':
        return 'Negocio';
      default:
        return key;
    }
  }

  static Widget _filaDetalle(
    String etiqueta,
    String valor, {
    Color? valorColor,
    Color? etiquetaColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: etiquetaColor ?? Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: TextStyle(
              fontSize: 15,
              color: valorColor,
              fontWeight: valorColor != null ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }
}
