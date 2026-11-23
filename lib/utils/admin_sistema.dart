import 'package:cloud_firestore/cloud_firestore.dart';

/// Quién ve el menú de la plataforma (aceptar y administrar negocios).
class AdminSistema {
  AdminSistema._();

  /// Cuenta con la que se opera Angostura. Si en Firestore quedó como cliente,
  /// el menú de administrador igual tiene que salir.
  static const String telefonoDueno = '6971094100';

  static final Set<String> _rolEscrito = {};

  static bool es(Map<String, dynamic>? data, {String? telefonoAuth}) {
    final rol = (data?['rol'] ?? '').toString().trim().toLowerCase();
    if (rol == 'admin' || rol == 'administrador') return true;
    if (_esDueno(data?['telefono']?.toString())) return true;
    if (_esDueno(telefonoAuth)) return true;
    return false;
  }

  static bool _esDueno(String? raw) {
    final digitos = (raw ?? '').replaceAll(RegExp(r'\D'), '');
    return digitos.endsWith(telefonoDueno) && digitos.length >= 10;
  }

  /// Deja el rol guardado para el resto de pantallas que lo leen.
  static void asegurarRol(String uid, Map<String, dynamic>? data, {String? telefonoAuth}) {
    if (!es(data, telefonoAuth: telefonoAuth)) return;
    final rol = (data?['rol'] ?? '').toString().trim().toLowerCase();
    if (rol == 'admin') return;
    if (!_rolEscrito.add(uid)) return;
    FirebaseFirestore.instance.collection('usuarios').doc(uid).set(
      {'rol': 'admin'},
      SetOptions(merge: true),
    );
  }
}
