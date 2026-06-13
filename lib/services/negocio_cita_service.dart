import 'package:cloud_firestore/cloud_firestore.dart';

/// Horario y bloqueos de citas guardados en el documento del negocio.
class NegocioCitaService {
  NegocioCitaService._();

  static const List<String> diasSemana = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  /// Horario semanal solo para citas (`horario_citas`). Si no existe, vacío.
  static Map<String, dynamic> horarioCitas(Map<String, dynamic>? negocio) {
    final h = negocio?['horario_citas'];
    if (h is Map) return Map<String, dynamic>.from(h);
    return {};
  }

  static Map<String, dynamic> horarioCitasPorDefecto() {
    final m = <String, dynamic>{};
    for (var i = 1; i <= 7; i++) {
      m['$i'] = {
        'activo': i <= 6,
        'abre': '09:00',
        'cierra': '18:00',
      };
    }
    return m;
  }

  /// Horas que el dueño bloqueó manualmente (ISO 8601).
  static List<String> bloqueosManuales(Map<String, dynamic>? negocio) {
    final raw = negocio?['citas_bloqueadas'];
    if (raw is! List) return [];
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  static Future<void> guardarHorarioCitas(
    String negocioId,
    Map<String, dynamic> horario,
  ) async {
    await FirebaseFirestore.instance.collection('negocios').doc(negocioId).update({
      'horario_citas': horario,
    });
  }

  static Future<void> guardarBloqueos(
    String negocioId,
    List<String> bloqueos,
  ) async {
    await FirebaseFirestore.instance.collection('negocios').doc(negocioId).update({
      'citas_bloqueadas': bloqueos,
    });
  }

  static Future<void> guardarConfig(
    String negocioId, {
    required Map<String, dynamic> horario,
    required List<String> bloqueos,
    int? intervaloMinutos,
    int? diasAdelante,
  }) async {
    final data = <String, dynamic>{
      'horario_citas': horario,
      'citas_bloqueadas': bloqueos,
    };
    if (intervaloMinutos != null) {
      data['intervalo_citas_minutos'] = intervaloMinutos;
    }
    if (diasAdelante != null) {
      data['dias_citas_adelante'] = diasAdelante;
    }
    await FirebaseFirestore.instance.collection('negocios').doc(negocioId).update(data);
  }
}
