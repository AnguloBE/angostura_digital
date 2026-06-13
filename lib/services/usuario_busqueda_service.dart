import 'package:cloud_firestore/cloud_firestore.dart';

class UsuarioBusqueda {
  final String uid;
  final String nombre;
  final String telefono;
  final String rol;

  const UsuarioBusqueda({
    required this.uid,
    required this.nombre,
    this.telefono = '',
    this.rol = 'cliente',
  });

  factory UsuarioBusqueda.desdeDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UsuarioBusqueda(
      uid: doc.id,
      nombre: (data['nombre'] ?? 'Usuario').toString(),
      telefono: (data['telefono'] ?? '').toString(),
      rol: (data['rol'] ?? 'cliente').toString(),
    );
  }

  String get telefonoVisible {
    if (telefono.isEmpty) return 'Sin teléfono';
    final digits = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 4) return telefono;
    return '···${digits.substring(digits.length - 4)}';
  }
}

class UsuarioBusquedaService {
  static final _db = FirebaseFirestore.instance;

  /// Busca por nombre (contiene) o dígitos del teléfono. Mínimo 2 caracteres.
  static Future<List<UsuarioBusqueda>> buscar(String query, {int limite = 20}) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];

    final digitos = q.replaceAll(RegExp(r'[^0-9]'), '');
    final snap = await _db.collection('usuarios').limit(400).get();

    final resultados = <UsuarioBusqueda>[];
    for (final doc in snap.docs) {
      final u = UsuarioBusqueda.desdeDoc(doc);
      final nombre = u.nombre.toLowerCase();
      final tel = u.telefono.replaceAll(RegExp(r'[^0-9]'), '');

      final coincideNombre = nombre.contains(q);
      final coincideTel = digitos.length >= 2 &&
          (tel.contains(digitos) || tel.endsWith(digitos));

      if (coincideNombre || coincideTel) {
        resultados.add(u);
      }
      if (resultados.length >= limite) break;
    }

    resultados.sort((a, b) => a.nombre.compareTo(b.nombre));
    return resultados;
  }
}
