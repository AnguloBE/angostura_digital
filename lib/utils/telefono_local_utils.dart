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

  /// Dígitos para wa.me. Un celular de 10 dígitos sale con lada de México (52).
  /// El enlace no lleva el signo +, WhatsApp no lo acepta.
  static String paraWhatsapp(String telefono) {
    var d = soloDigitos(telefono);
    if ((d.startsWith('044') || d.startsWith('045')) && d.length == 13) {
      d = d.substring(3);
    }
    if (d.startsWith('52') && (d.length == 12 || d.length == 13)) return d;
    if (d.length == 10) return '52$d';
    return d;
  }
}
