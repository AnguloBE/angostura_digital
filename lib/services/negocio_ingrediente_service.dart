import 'package:cloud_firestore/cloud_firestore.dart';

/// Un ingrediente del catálogo de un negocio (ej. "Lechuga", "Carne", "Queso").
class NegocioIngrediente {
  final String id;
  final String nombre;

  /// Costo extra si el cliente lo agrega (para usarse en el futuro). 0 = sin costo.
  final double precioExtra;

  const NegocioIngrediente({
    required this.id,
    required this.nombre,
    this.precioExtra = 0,
  });

  factory NegocioIngrediente.desdeDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NegocioIngrediente(
      id: doc.id,
      nombre: (data['nombre'] ?? '').toString(),
      precioExtra: (data['precio_extra'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Maneja el catálogo de ingredientes de cada negocio.
///
/// Se guarda en la subcolección `negocios/{negocioId}/ingredientes`.
class NegocioIngredienteService {
  static final _db = FirebaseFirestore.instance;

  /// Categorías de negocio que usan ingredientes (comida, antojos, etc.).
  static const Set<String> categoriasConIngredientes = {
    'Restaurante / Comida',
    'Postres y Antojos',
  };

  static bool usaIngredientes(String? categoria) =>
      categoria != null && categoriasConIngredientes.contains(categoria);

  static CollectionReference<Map<String, dynamic>> _ref(String negocioId) =>
      _db.collection('negocios').doc(negocioId).collection('ingredientes');

  static Stream<List<NegocioIngrediente>> stream(String negocioId) {
    return _ref(negocioId).snapshots().map((snap) {
      final lista =
          snap.docs.map((d) => NegocioIngrediente.desdeDoc(d)).toList();
      lista.sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      );
      return lista;
    });
  }

  static Future<List<NegocioIngrediente>> obtener(String negocioId) async {
    final snap = await _ref(negocioId).get();
    final lista = snap.docs.map((d) => NegocioIngrediente.desdeDoc(d)).toList();
    lista.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );
    return lista;
  }

  static Future<void> agregar(
    String negocioId,
    String nombre, {
    double precioExtra = 0,
  }) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) {
      throw Exception('Escribe el nombre del ingrediente.');
    }

    final existentes = await _ref(negocioId).get();
    final yaExiste = existentes.docs.any((d) =>
        (d.data()['nombre'] ?? '').toString().toLowerCase() ==
        limpio.toLowerCase());
    if (yaExiste) {
      throw Exception('Ese ingrediente ya está en tu lista.');
    }

    await _ref(negocioId).add({
      'nombre': limpio,
      'precio_extra': precioExtra,
      'fecha': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> actualizar(
    String negocioId,
    String ingredienteId, {
    required String nombre,
    double precioExtra = 0,
  }) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) {
      throw Exception('Escribe el nombre del ingrediente.');
    }
    await _ref(negocioId).doc(ingredienteId).update({
      'nombre': limpio,
      'precio_extra': precioExtra,
    });
  }

  static Future<void> eliminar(String negocioId, String ingredienteId) async {
    await _ref(negocioId).doc(ingredienteId).delete();
  }

  /// Texto legible de los ingredientes de un producto.
  ///
  /// Prioriza la lista estructurada `ingredientes_lista`; si no existe,
  /// usa el texto libre `ingredientes` (compatibilidad con productos viejos).
  static String? textoIngredientes(Map<String, dynamic> productoData) {
    final lista = productoData['ingredientes_lista'];
    if (lista is List && lista.isNotEmpty) {
      return lista.map((e) => e.toString()).join(', ');
    }
    final texto = productoData['ingredientes'];
    if (texto != null && texto.toString().trim().isNotEmpty) {
      return texto.toString().trim();
    }
    return null;
  }

  /// Lista estructurada de ingredientes de un producto (para selección/edición).
  static List<String> listaIngredientes(Map<String, dynamic> productoData) {
    final lista = productoData['ingredientes_lista'];
    if (lista is List) {
      return lista.map((e) => e.toString()).toList();
    }
    return [];
  }
}
