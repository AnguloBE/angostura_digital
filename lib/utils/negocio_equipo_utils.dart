/// Roles dentro de un negocio (subcolección `negocios/{id}/equipo/{uid}`).
class NegocioEquipoUtils {
  static const String rolDueno = 'dueno';
  static const String rolEncargado = 'encargado';
  static const String rolTrabajador = 'trabajador';

  static const String coleccionEquipo = 'equipo';

  /// Espejo en el perfil del usuario para listar negocios sin collectionGroup.
  static const String coleccionAccesoUsuario = 'negocios_acceso';

  static String etiquetaRol(String rol) {
    switch (rol) {
      case rolDueno:
        return 'Dueño';
      case rolEncargado:
        return 'Encargado';
      case rolTrabajador:
        return 'Trabajador';
      default:
        return rol;
    }
  }

  static bool esDueno(String? rol) => rol == rolDueno;

  static bool esEncargado(String? rol) => rol == rolEncargado;

  static bool esTrabajador(String? rol) => rol == rolTrabajador;

  /// Dueño y encargado: panel completo. Trabajador: solo pedidos.
  static bool accesoPanelCompleto(String? rol) => esDueno(rol) || esEncargado(rol);

  static bool accesoPedidos(String? rol) =>
      esDueno(rol) || esEncargado(rol) || esTrabajador(rol);

  static bool accesoGestionEquipo(String? rol) => esDueno(rol) || esEncargado(rol);

  /// Encargado no puede quitar a un dueño del equipo.
  static bool puedeQuitarMiembro({
    required String? rolQuienQuita,
    required String rolObjetivo,
    bool esAdmin = false,
  }) {
    if (esAdmin) return true;
    if (esDueno(rolQuienQuita)) return true;
    if (esEncargado(rolQuienQuita) && !esDueno(rolObjetivo)) return true;
    return false;
  }

  static String descripcionPermisosEncargado() =>
      'Mismo acceso que el dueño al panel (productos, promos, envíos, horario y equipo). '
      'No puede quitar al dueño del negocio.';

  static String descripcionPermisosTrabajador() =>
      'Ver pedidos/ventas, registrar ventas en el local, cambiar estados y tiempo estimado. '
      'Sin acceso a productos, promos, envíos, horario ni equipo.';
}
