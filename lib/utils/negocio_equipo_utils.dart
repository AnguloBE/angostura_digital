/// Roles dentro de un negocio (subcolección `negocios/{id}/equipo/{uid}`).
class NegocioEquipoUtils {
  static const String rolDueno = 'dueno';
  static const String rolTrabajador = 'trabajador';

  static const String coleccionEquipo = 'equipo';

  /// Espejo en el perfil del usuario para listar negocios sin collectionGroup.
  static const String coleccionAccesoUsuario = 'negocios_acceso';

  static String etiquetaRol(String rol) {
    switch (rol) {
      case rolDueno:
        return 'Dueño';
      case rolTrabajador:
        return 'Trabajador';
      default:
        return rol;
    }
  }

  static bool esDueno(String? rol) => rol == rolDueno;

  static bool esTrabajador(String? rol) => rol == rolTrabajador;

  /// Dueño: panel completo. Trabajador: solo pedidos (opción A).
  static bool accesoPanelCompleto(String? rol) => esDueno(rol);

  static bool accesoPedidos(String? rol) => esDueno(rol) || esTrabajador(rol);

  static String descripcionPermisosTrabajador() =>
      'Ver pedidos/ventas, registrar ventas en el local, cambiar estados y tiempo estimado. '
      'Sin acceso a productos, promos, envíos, horario ni equipo.';
}
