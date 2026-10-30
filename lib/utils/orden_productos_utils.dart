import 'package:cloud_firestore/cloud_firestore.dart';

/// Destacados primero; el resto por nombre A–Z.
List<QueryDocumentSnapshot> ordenarProductosDocumentos(
  List<QueryDocumentSnapshot> docs,
) {
  final lista = List<QueryDocumentSnapshot>.from(docs);
  lista.sort((a, b) {
    final da = a.data() as Map<String, dynamic>;
    final db = b.data() as Map<String, dynamic>;
    final destacadoA = da['destacado'] == true;
    final destacadoB = db['destacado'] == true;
    if (destacadoA != destacadoB) return destacadoA ? -1 : 1;

    final nombreA = (da['nombre'] ?? '').toString().toLowerCase().trim();
    final nombreB = (db['nombre'] ?? '').toString().toLowerCase().trim();
    return nombreA.compareTo(nombreB);
  });
  return lista;
}

bool productoEsDestacado(Map<String, dynamic> data) => data['destacado'] == true;
