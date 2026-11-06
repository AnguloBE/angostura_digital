import 'package:cloud_firestore/cloud_firestore.dart';

/// Días en que un anuncio o una promoción se muestra.
/// Lista vacía = todos los días. 1 = lunes … 7 = domingo.
class DiasSemana {
  DiasSemana._();

  static const List<String> _cortos = ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const List<String> _largos = [
    '',
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static String corto(int dia) => dia >= 1 && dia <= 7 ? _cortos[dia] : '';

  static List<int> leer(dynamic raw) {
    final dias = <int>{};
    if (raw is Iterable) {
      for (final item in raw) {
        final n = item is int ? item : int.tryParse(item.toString());
        if (n != null && n >= 1 && n <= 7) dias.add(n);
      }
    }
    if (dias.length >= 7) return [];
    return dias.toList()..sort();
  }

  static bool aplicaHoy(dynamic raw, [DateTime? ahora]) {
    final dias = leer(raw);
    if (dias.isEmpty) return true;
    return dias.contains((ahora ?? DateTime.now()).weekday);
  }

  /// Visible hoy: día de la semana y, si hay fecha límite, todavía no vence.
  /// Con [ocultarInactivos], `activo: false` lo esconde (anuncios pausados).
  static bool vigente(Map<String, dynamic> data, {bool ocultarInactivos = false}) {
    if (ocultarInactivos && data['activo'] == false) return false;
    if (!aplicaHoy(data['dias_semana'])) return false;
    final fin = data['fecha_final'];
    if (fin is Timestamp) {
      final limite = fin.toDate().add(const Duration(days: 1));
      if (!limite.isAfter(DateTime.now())) return false;
    }
    return true;
  }

  /// "los lunes", "de lunes a miércoles" o "todos los días".
  static String frase(dynamic raw) {
    final dias = leer(raw);
    if (dias.isEmpty) return 'todos los días';
    if (dias.length == 1) return 'los ${_largos[dias.first]}';
    final contiguo = dias.last - dias.first + 1 == dias.length;
    if (contiguo) return 'de ${_largos[dias.first]} a ${_largos[dias.last]}';
    final partes = dias.map((d) => _largos[d]).toList();
    if (partes.length == 2) return 'los ${partes[0]} y ${partes[1]}';
    final cuerpo = partes.sublist(0, partes.length - 1).join(', ');
    return 'los $cuerpo y ${partes.last}';
  }

  static String vigencia(
    Map<String, dynamic> data, {
    String sinFecha = 'Hasta agotar existencias',
  }) {
    final dias = leer(data['dias_semana']);
    final fin = data['fecha_final'];
    String? hasta;
    if (fin is Timestamp) {
      final dt = fin.toDate();
      hasta = '${dt.day}/${dt.month}/${dt.year}';
    }
    if (dias.isNotEmpty) {
      final base = 'Cada semana, ${frase(dias)}';
      return hasta == null ? base : '$base · hasta $hasta';
    }
    if (hasta != null) return 'Válido hasta: $hasta';
    return sinFecha;
  }
}
