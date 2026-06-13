/// Teléfono local (mostrador): solo 10 dígitos, sin lada.
class TelefonoLocalUtils {
  TelefonoLocalUtils._();

  static String soloDigitos(String texto) =>
      texto.replaceAll(RegExp(r'\D'), '');

  /// Vacío = válido (opcional). Con texto = exactamente 10 dígitos.
  static bool esValidoOpcional(String texto) {
    final d = soloDigitos(texto.trim());
    if (d.isEmpty) return true;
    return d.length == 10;
  }

  static String? mensajeErrorOpcional(String texto) {
    final d = soloDigitos(texto.trim());
    if (d.isEmpty) return null;
    if (d.length != 10) {
      return 'El teléfono debe tener exactamente 10 dígitos.';
    }
    return null;
  }

  static String normalizar(String texto) => soloDigitos(texto.trim());
}
