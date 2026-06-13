import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:angostura_digital/utils/negocio_equipo_utils.dart';

class NegocioMiembro {
  final String uid;
  final String negocioId;
  final String rol;
  final String nombre;
  final String telefono;

  const NegocioMiembro({
    required this.uid,
    required this.negocioId,
    required this.rol,
    this.nombre = '',
    this.telefono = '',
  });

  factory NegocioMiembro.desdeDoc(String negocioId, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NegocioMiembro(
      uid: doc.id,
      negocioId: negocioId,
      rol: (data['rol'] ?? NegocioEquipoUtils.rolTrabajador).toString(),
      nombre: (data['nombre'] ?? '').toString(),
      telefono: (data['telefono'] ?? '').toString(),
    );
  }
}

class NegocioAcceso {
  final String negocioId;
  final String rol;
  final String nombre;
  final String categoria;
  final String estado;
  final String? fotoUrl;

  const NegocioAcceso({
    required this.negocioId,
    required this.rol,
    required this.nombre,
    this.categoria = '',
    this.estado = 'activo',
    this.fotoUrl,
  });

  bool get panelCompleto => NegocioEquipoUtils.accesoPanelCompleto(rol);

  factory NegocioAcceso.desdeMap(String negocioId, Map<String, dynamic> data) {
    return NegocioAcceso(
      negocioId: negocioId,
      rol: (data['rol'] ?? NegocioEquipoUtils.rolTrabajador).toString(),
      nombre: (data['nombre'] ?? 'Sin nombre').toString(),
      categoria: (data['categoria'] ?? '').toString(),
      estado: (data['estado'] ?? 'activo').toString(),
      fotoUrl: data['foto_url']?.toString(),
    );
  }
}

class NegocioEquipoService {
  static final _db = FirebaseFirestore.instance;
  static final Set<String> _legacySincronizado = {};

  static CollectionReference<Map<String, dynamic>> _equipoRef(String negocioId) =>
      _db.collection('negocios').doc(negocioId).collection(NegocioEquipoUtils.coleccionEquipo);

  static CollectionReference<Map<String, dynamic>> _accesoUsuarioRef(String uid) =>
      _db.collection('usuarios').doc(uid).collection(NegocioEquipoUtils.coleccionAccesoUsuario);

  static Future<String?> buscarUidPorTelefono(String telefono) async {
    final limpio = telefono.trim();
    if (limpio.isEmpty) return null;

    var snap = await _db.collection('usuarios').where('telefono', isEqualTo: limpio).limit(1).get();
    if (snap.docs.isNotEmpty) return snap.docs.first.id;

    if (!limpio.startsWith('+')) {
      snap = await _db.collection('usuarios').where('telefono', isEqualTo: '+52$limpio').limit(1).get();
      if (snap.docs.isNotEmpty) return snap.docs.first.id;
    }
    return null;
  }

  static Stream<List<NegocioMiembro>> streamEquipo(String negocioId) {
    return _equipoRef(negocioId).snapshots().map((snap) {
      final lista = snap.docs.map((d) => NegocioMiembro.desdeDoc(negocioId, d)).toList();
      lista.sort((a, b) {
        if (NegocioEquipoUtils.esDueno(a.rol) != NegocioEquipoUtils.esDueno(b.rol)) {
          return NegocioEquipoUtils.esDueno(a.rol) ? -1 : 1;
        }
        return a.nombre.compareTo(b.nombre);
      });
      return lista;
    });
  }

  /// Lista negocios del usuario vía espejo en su perfil (sin collectionGroup).
  static Stream<List<NegocioAcceso>> streamMisAccesos(String uid) {
    return Stream.fromFuture(sincronizarAccesosUsuario(uid)).asyncExpand((_) {
      return _accesoUsuarioRef(uid).snapshots().asyncMap((snap) async {
        final accesos = <NegocioAcceso>[];
        for (final doc in snap.docs) {
          final base = NegocioAcceso.desdeMap(doc.id, doc.data());
          final neg = await _db.collection('negocios').doc(doc.id).get();
          if (!neg.exists) continue;
          final data = neg.data()!;
          accesos.add(NegocioAcceso(
            negocioId: doc.id,
            rol: base.rol,
            nombre: (data['nombre'] ?? base.nombre).toString(),
            categoria: (data['categoria'] ?? base.categoria).toString(),
            estado: (data['estado'] ?? base.estado).toString(),
            fotoUrl: data['foto_url']?.toString() ?? base.fotoUrl,
          ));
        }
        accesos.sort((a, b) => a.nombre.compareTo(b.nombre));
        return accesos;
      });
    });
  }

  static Stream<List<NegocioMiembro>> streamMisMembresias(String uid) {
    return streamMisAccesos(uid).map((lista) => lista
        .map((a) => NegocioMiembro(
              uid: uid,
              negocioId: a.negocioId,
              rol: a.rol,
              nombre: a.nombre,
            ))
        .toList());
  }

  /// Asegura índices de acceso para dueños legacy y miembros del equipo.
  static Future<void> sincronizarAccesosUsuario(String uid) async {
    if (_legacySincronizado.contains(uid)) return;
    _legacySincronizado.add(uid);

    try {
      final legacy = await _db.collection('negocios').where('propietario_uid', isEqualTo: uid).get();
      for (final neg in legacy.docs) {
        final enEquipo = await _equipoRef(neg.id).doc(uid).get();
        if (!enEquipo.exists) continue;
        await _escribirAccesoUsuario(
          uid: uid,
          negocioId: neg.id,
          rol: NegocioEquipoUtils.rolDueno,
          negocioData: neg.data(),
        );
      }

      await _sincronizarDesdeEquipoCollectionGroup(uid);
    } catch (_) {
      _legacySincronizado.remove(uid);
    }
  }

  /// Intento único vía collectionGroup (puede fallar sin índice); si funciona, crea espejos.
  static Future<void> _sincronizarDesdeEquipoCollectionGroup(String uid) async {
    try {
      final snap = await _db
          .collectionGroup(NegocioEquipoUtils.coleccionEquipo)
          .where('uid', isEqualTo: uid)
          .get();
      for (final doc in snap.docs) {
        final negocioId = doc.reference.parent.parent?.id;
        if (negocioId == null) continue;
        final rol = (doc.data()['rol'] ?? NegocioEquipoUtils.rolTrabajador).toString();
        await _escribirAccesoUsuario(uid: uid, negocioId: negocioId, rol: rol);
      }
    } catch (_) {
      // Sin índice o reglas: el admin/dueño sincroniza al abrir Equipo.
    }
  }

  /// Sincroniza espejos de acceso solo para miembros actuales del equipo (sin re-agregar legacy).
  static Future<void> sincronizarMirrorsDesdeEquipo(String negocioId) async {
    final neg = await _db.collection('negocios').doc(negocioId).get();
    if (!neg.exists) return;

    final equipo = await _equipoRef(negocioId).get();
    for (final doc in equipo.docs) {
      final rol = (doc.data()['rol'] ?? NegocioEquipoUtils.rolTrabajador).toString();
      await _equipoRef(negocioId).doc(doc.id).set({
        ...doc.data(),
        'uid': doc.id,
        'rol': rol,
        '_sync': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Migración única: negocio antiguo con propietario_uid pero sin equipo.
  static Future<void> migrarPropietarioLegacy(String negocioId) async {
    final neg = await _db.collection('negocios').doc(negocioId).get();
    if (!neg.exists) return;
    final negData = neg.data()!;
    if (negData['equipo_legacy_migrado'] == true) return;

    final uid = negData['propietario_uid']?.toString();
    if (uid == null || uid.isEmpty) {
      await _db.collection('negocios').doc(negocioId).update({'equipo_legacy_migrado': true});
      return;
    }

    final equipo = await _equipoRef(negocioId).limit(1).get();
    if (equipo.docs.isNotEmpty) {
      await _db.collection('negocios').doc(negocioId).update({'equipo_legacy_migrado': true});
      return;
    }

    final userSnap = await _db.collection('usuarios').doc(uid).get();
    final userData = userSnap.data() ?? {};

    await _equipoRef(negocioId).doc(uid).set({
      'uid': uid,
      'rol': NegocioEquipoUtils.rolDueno,
      'nombre': (userData['nombre'] ?? 'Dueño').toString(),
      'telefono': (userData['telefono'] ?? negData['telefono_propietario'] ?? '').toString(),
      'agregado_por': 'sistema',
      'fecha': FieldValue.serverTimestamp(),
    });

    await _db.collection('negocios').doc(negocioId).update({'equipo_legacy_migrado': true});
  }

  static Future<void> _actualizarPropietarioPrincipal(String negocioId) async {
    final equipo = await _equipoRef(negocioId).get();
    final duenos = equipo.docs
        .where((d) => (d.data()['rol'] ?? '') == NegocioEquipoUtils.rolDueno)
        .toList();

    if (duenos.isEmpty) {
      await _db.collection('negocios').doc(negocioId).update({
        'propietario_uid': FieldValue.delete(),
        'telefono_propietario': FieldValue.delete(),
      });
      return;
    }

    final primero = duenos.first;
    final tel = (primero.data()['telefono'] ?? '').toString();
    await _db.collection('negocios').doc(negocioId).update({
      'propietario_uid': primero.id,
      'telefono_propietario': tel,
    });
  }

  static Future<void> _escribirAccesoUsuario({
    required String uid,
    required String negocioId,
    required String rol,
    Map<String, dynamic>? negocioData,
  }) async {
    negocioData ??= (await _db.collection('negocios').doc(negocioId).get()).data();
    if (negocioData == null) return;

    try {
      await _accesoUsuarioRef(uid).doc(negocioId).set({
        'negocio_id': negocioId,
        'rol': rol,
        'nombre': (negocioData['nombre'] ?? 'Sin nombre').toString(),
        'categoria': (negocioData['categoria'] ?? '').toString(),
        'estado': (negocioData['estado'] ?? 'activo').toString(),
        'foto_url': negocioData['foto_url'],
        'actualizado': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Otro usuario (ej. admin agrega dueño): lo sincroniza Cloud Function.
    }
  }

  static Future<void> _quitarAccesoUsuario({
    required String uid,
    required String negocioId,
  }) async {
    try {
      await _accesoUsuarioRef(uid).doc(negocioId).delete();
    } catch (_) {}
  }

  static Future<String?> obtenerRolEnNegocio(String negocioId, String uid) async {
    final acceso = await _accesoUsuarioRef(uid).doc(negocioId).get();
    if (acceso.exists) return (acceso.data()?['rol'] ?? NegocioEquipoUtils.rolTrabajador).toString();

    final doc = await _equipoRef(negocioId).doc(uid).get();
    if (doc.exists) return (doc.data()?['rol'] ?? NegocioEquipoUtils.rolTrabajador).toString();

    final neg = await _db.collection('negocios').doc(negocioId).get();
    if (neg.exists && neg.data()?['propietario_uid'] == uid) {
      final enEquipo = await _equipoRef(negocioId).doc(uid).get();
      if (enEquipo.exists) return NegocioEquipoUtils.rolDueno;
    }
    return null;
  }

  static Future<void> agregarMiembroPorUid({
    required String negocioId,
    required String uid,
    required String rol,
    required String agregadoPorUid,
  }) async {
    final negSnap = await _db.collection('negocios').doc(negocioId).get();
    if (!negSnap.exists) {
      throw Exception('El negocio ya no existe.');
    }

    final yaEnEquipo = await _equipoRef(negocioId).doc(uid).get();
    if (yaEnEquipo.exists) {
      throw Exception('Esa persona ya está en el equipo.');
    }

    final userSnap = await _db.collection('usuarios').doc(uid).get();
    if (!userSnap.exists) {
      throw Exception('Usuario no encontrado.');
    }
    final userData = userSnap.data() ?? {};

    await _equipoRef(negocioId).doc(uid).set({
      'uid': uid,
      'rol': rol,
      'nombre': (userData['nombre'] ?? 'Usuario').toString(),
      'telefono': (userData['telefono'] ?? '').toString(),
      'agregado_por': agregadoPorUid,
      'fecha': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _escribirAccesoUsuario(
      uid: uid,
      negocioId: negocioId,
      rol: rol,
      negocioData: negSnap.data(),
    );

    if (rol == NegocioEquipoUtils.rolDueno) {
      await _db.collection('negocios').doc(negocioId).set({
        'propietario_uid': uid,
        'telefono_propietario': (userData['telefono'] ?? '').toString(),
      }, SetOptions(merge: true));
    }
  }

  static Future<void> agregarMiembro({
    required String negocioId,
    required String telefono,
    required String rol,
    required String agregadoPorUid,
  }) async {
    final uid = await buscarUidPorTelefono(telefono);
    if (uid == null) {
      throw Exception('No encontramos un usuario con ese teléfono. Debe iniciar sesión al menos una vez.');
    }
    await agregarMiembroPorUid(
      negocioId: negocioId,
      uid: uid,
      rol: rol,
      agregadoPorUid: agregadoPorUid,
    );
  }

  static Future<void> quitarMiembro({
    required String negocioId,
    required String uid,
  }) async {
    final miembro = await _equipoRef(negocioId).doc(uid).get();
    final eraDueno =
        miembro.exists && (miembro.data()?['rol'] ?? '') == NegocioEquipoUtils.rolDueno;

    await _equipoRef(negocioId).doc(uid).delete();
    await _quitarAccesoUsuario(uid: uid, negocioId: negocioId);

    if (eraDueno) {
      await _actualizarPropietarioPrincipal(negocioId);
    }
  }
}
