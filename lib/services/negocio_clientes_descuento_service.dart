import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:angostura_digital/utils/opciones_negocio.dart';

/// Cliente que paga el precio con descuento en un negocio.
/// No entra al equipo: no ve el panel ni los pedidos.
class ClienteDescuento {
  final String uid;
  final String nombre;
  final String telefono;

  const ClienteDescuento({
    required this.uid,
    this.nombre = '',
    this.telefono = '',
  });

  factory ClienteDescuento.desdeDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ClienteDescuento(
      uid: doc.id,
      nombre: (data['nombre'] ?? '').toString(),
      telefono: (data['telefono'] ?? '').toString(),
    );
  }
}

class NegocioClientesDescuentoService {
  NegocioClientesDescuentoService._();

  static final _db = FirebaseFirestore.instance;
  static const String coleccion = 'clientes_descuento';
  static const String coleccionUsuario = 'descuentos_negocio';

  static CollectionReference<Map<String, dynamic>> _clientesRef(String negocioId) =>
      _db.collection('negocios').doc(negocioId).collection(coleccion);

  static CollectionReference<Map<String, dynamic>> _mirrorRef(String uid) =>
      _db.collection('usuarios').doc(uid).collection(coleccionUsuario);

  static Stream<List<ClienteDescuento>> streamClientes(String negocioId) {
    return _clientesRef(negocioId).snapshots().map((snap) {
      final lista = snap.docs.map(ClienteDescuento.desdeDoc).toList();
      lista.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      return lista;
    });
  }

  /// Negocios donde este usuario tiene precio con descuento y la opción sigue prendida.
  static Stream<Set<String>> streamNegociosActivos(String uid) {
    return _mirrorRef(uid).snapshots().asyncMap((snap) async {
      final activos = <String>{};
      for (final doc in snap.docs) {
        try {
          final neg = await _db.collection('negocios').doc(doc.id).get();
          if (!neg.exists) continue;
          final data = neg.data();
          final op = OpcionesNegocio.desde(data?['categoria']?.toString(), data);
          if (op.clientesDescuento) activos.add(doc.id);
        } catch (_) {}
      }
      return activos;
    });
  }

  static Future<bool> esCliente(String negocioId, String uid) async {
    final mirror = await _mirrorRef(uid).doc(negocioId).get();
    if (mirror.exists) return true;

    final directo = await _clientesRef(negocioId).doc(uid).get();
    if (!directo.exists) return false;

    await _escribirMirror(
      uid: uid,
      negocioId: negocioId,
      nombreNegocio: '',
    );
    return true;
  }

  static Future<void> agregar({
    required String negocioId,
    required String nombreNegocio,
    required String uid,
    required String agregadoPorUid,
  }) async {
    final ya = await _clientesRef(negocioId).doc(uid).get();
    if (ya.exists) {
      throw Exception('Esa persona ya tiene precio con descuento.');
    }

    final userSnap = await _db.collection('usuarios').doc(uid).get();
    if (!userSnap.exists) {
      throw Exception('Usuario no encontrado.');
    }
    final userData = userSnap.data() ?? {};

    await _clientesRef(negocioId).doc(uid).set({
      'uid': uid,
      'nombre': (userData['nombre'] ?? 'Usuario').toString(),
      'telefono': (userData['telefono'] ?? '').toString(),
      'agregado_por': agregadoPorUid,
      'fecha': FieldValue.serverTimestamp(),
    });

    await _escribirMirror(uid: uid, negocioId: negocioId, nombreNegocio: nombreNegocio);
  }

  static Future<void> quitar({
    required String negocioId,
    required String uid,
  }) async {
    await _clientesRef(negocioId).doc(uid).delete();
    try {
      await _mirrorRef(uid).doc(negocioId).delete();
    } catch (_) {}
  }

  static Future<void> _escribirMirror({
    required String uid,
    required String negocioId,
    required String nombreNegocio,
  }) async {
    try {
      await _mirrorRef(uid).doc(negocioId).set({
        'negocio_id': negocioId,
        'nombre': nombreNegocio,
        'actualizado': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
