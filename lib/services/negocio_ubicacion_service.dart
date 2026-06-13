import 'package:cloud_firestore/cloud_firestore.dart';

/// Una repisa/zona del catálogo de un negocio (ej. "Repisa A2", "Bodega").
class NegocioUbicacion {
  final String id;
  final String nombre;

  /// Código opcional de la etiqueta impresa (para escanearla con la cámara).
  final String codigo;

  const NegocioUbicacion({
    required this.id,
    required this.nombre,
    this.codigo = '',
  });

  factory NegocioUbicacion.desdeDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NegocioUbicacion(
      id: doc.id,
      nombre: (data['nombre'] ?? '').toString(),
      codigo: (data['codigo'] ?? '').toString(),
    );
  }
}

/// Una cantidad de producto guardada en un lugar concreto.
class StockUbicacion {
  final String lugar;
  final int cantidad;

  const StockUbicacion({required this.lugar, this.cantidad = 0});

  factory StockUbicacion.desdeMap(Map<String, dynamic> map) => StockUbicacion(
        lugar: (map['lugar'] ?? '').toString(),
        cantidad: (map['cantidad'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {'lugar': lugar, 'cantidad': cantidad};

  StockUbicacion copyWith({String? lugar, int? cantidad}) => StockUbicacion(
        lugar: lugar ?? this.lugar,
        cantidad: cantidad ?? this.cantidad,
      );
}

/// Maneja el catálogo de ubicaciones (repisas/zonas) de cada negocio y los
/// ayudantes para el inventario por ubicación de los productos.
///
/// El catálogo se guarda en `negocios/{negocioId}/ubicaciones`.
/// En cada producto se guarda `ubicaciones: [{lugar, cantidad}]` y `stock_total`.
class NegocioUbicacionService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _ref(String negocioId) =>
      _db.collection('negocios').doc(negocioId).collection('ubicaciones');

  static Stream<List<NegocioUbicacion>> stream(String negocioId) {
    return _ref(negocioId).snapshots().map((snap) {
      final lista = snap.docs.map((d) => NegocioUbicacion.desdeDoc(d)).toList();
      lista.sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      );
      return lista;
    });
  }

  static Future<List<NegocioUbicacion>> obtener(String negocioId) async {
    final snap = await _ref(negocioId).get();
    final lista = snap.docs.map((d) => NegocioUbicacion.desdeDoc(d)).toList();
    lista.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );
    return lista;
  }

  static Future<void> agregar(
    String negocioId,
    String nombre, {
    String codigo = '',
  }) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) {
      throw Exception('Escribe el nombre de la ubicación.');
    }
    final existentes = await _ref(negocioId).get();
    final yaExiste = existentes.docs.any((d) =>
        (d.data()['nombre'] ?? '').toString().toLowerCase() ==
        limpio.toLowerCase());
    if (yaExiste) {
      throw Exception('Esa ubicación ya existe.');
    }
    await _ref(negocioId).add({
      'nombre': limpio,
      'codigo': codigo.trim(),
      'fecha': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> actualizar(
    String negocioId,
    String ubicacionId,
    String nombre, {
    String codigo = '',
  }) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) {
      throw Exception('Escribe el nombre de la ubicación.');
    }
    await _ref(negocioId).doc(ubicacionId).update({
      'nombre': limpio,
      'codigo': codigo.trim(),
    });
  }

  static Future<void> eliminar(String negocioId, String ubicacionId) async {
    await _ref(negocioId).doc(ubicacionId).delete();
  }

  /// Busca una ubicación del catálogo por su código de etiqueta o por su nombre.
  static NegocioUbicacion? emparejarPorCodigo(
    List<NegocioUbicacion> catalogo,
    String escaneado,
  ) {
    final valor = escaneado.trim().toLowerCase();
    if (valor.isEmpty) return null;
    for (final u in catalogo) {
      if (u.codigo.trim().isNotEmpty && u.codigo.trim().toLowerCase() == valor) {
        return u;
      }
    }
    for (final u in catalogo) {
      if (u.nombre.trim().toLowerCase() == valor) return u;
    }
    return null;
  }

  // ---------- Ayudantes de inventario por producto ----------

  /// Lee la lista de stock por ubicación de un producto.
  static List<StockUbicacion> ubicacionesProducto(
    Map<String, dynamic> productoData,
  ) {
    final raw = productoData['ubicaciones'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => StockUbicacion.desdeMap(Map<String, dynamic>.from(m)))
          .where((u) => u.lugar.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static int stockTotal(Map<String, dynamic> productoData) {
    final guardado = productoData['stock_total'];
    if (guardado is num) return guardado.toInt();
    return ubicacionesProducto(productoData)
        .fold(0, (suma, u) => suma + u.cantidad);
  }

  static int sumarCantidades(List<StockUbicacion> ubicaciones) =>
      ubicaciones.fold(0, (suma, u) => suma + u.cantidad);

  /// Texto legible de dónde está el producto (ej. "Repisa A2 (5), Bodega (3)").
  static String? textoUbicaciones(Map<String, dynamic> productoData) {
    final lista = ubicacionesProducto(productoData);
    if (lista.isEmpty) return null;
    return lista.map((u) => '${u.lugar} (${u.cantidad})').join(', ');
  }
}
