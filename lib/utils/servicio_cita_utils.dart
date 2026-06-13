import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:angostura_digital/services/negocio_cita_service.dart';

/// Horarios y citas para negocios de servicios.
class ServicioCitaUtils {
  ServicioCitaUtils._();

  static const int diasAdelanteDefault = 60;
  static const int intervaloMinutosDefault = 30;

  static int intervaloDesdeNegocio(Map<String, dynamic>? negocio) {
    final v = negocio?['intervalo_citas_minutos'];
    if (v is num && v > 0) return v.toInt();
    return intervaloMinutosDefault;
  }

  static int diasAdelanteDesdeNegocio(Map<String, dynamic>? negocio) {
    final v = negocio?['dias_citas_adelante'];
    if (v is num && v > 0) return v.toInt();
    return diasAdelanteDefault;
  }

  static Map<String, dynamic> horarioParaCitas(Map<String, dynamic>? negocio) {
    final citas = NegocioCitaService.horarioCitas(negocio);
    if (citas.isNotEmpty) return citas;
    return {};
  }

  static String claveDia(DateTime dia) =>
      '${dia.year}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';

  static String claveSlot(DateTime slot) => slot.toIso8601String();

  static bool diaAtiendeCitas(Map<String, dynamic>? horarioCitas, DateTime dia) {
    if (horarioCitas == null || horarioCitas.isEmpty) return false;
    final config = horarioCitas['${dia.weekday}'] as Map?;
    return config?['activo'] == true;
  }

  static DateTime? primerDiaReservable(Map<String, dynamic>? negocio) {
    final horario = horarioParaCitas(negocio);
    final max = diasAdelanteDesdeNegocio(negocio);
    final hoy = DateTime.now();
    for (var i = 0; i < max; i++) {
      final d = DateTime(hoy.year, hoy.month, hoy.day + i);
      if (diaAtiendeCitas(horario, d)) return d;
    }
    return null;
  }

  static DateTime? ultimoDiaReservable(Map<String, dynamic>? negocio) {
    final hoy = DateTime.now();
    final max = diasAdelanteDesdeNegocio(negocio);
    return DateTime(hoy.year, hoy.month, hoy.day + max - 1);
  }

  static bool diaReservable(Map<String, dynamic>? negocio, DateTime dia) {
    final horario = horarioParaCitas(negocio);
    if (!diaAtiendeCitas(horario, dia)) return false;
    final primero = DateTime.now();
    final ultimo = ultimoDiaReservable(negocio);
    if (dia.isBefore(DateTime(primero.year, primero.month, primero.day))) return false;
    if (ultimo != null && dia.isAfter(ultimo)) return false;
    return true;
  }

  static int _minutosDesdeMedianoche(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  /// Todas las franjas del día según horario de citas del negocio.
  static List<DateTime> horariosDelDia(
    DateTime dia,
    Map<String, dynamic>? horarioCitas, {
    int duracionMinutos = 30,
    int intervaloMinutos = intervaloMinutosDefault,
    bool soloFuturas = true,
  }) {
    if (horarioCitas == null || horarioCitas.isEmpty) return [];
    final config = horarioCitas['${dia.weekday}'] as Map?;
    if (config == null || config['activo'] != true) return [];

    final abre = _minutosDesdeMedianoche(config['abre']?.toString() ?? '09:00');
    final cierra = _minutosDesdeMedianoche(config['cierra']?.toString() ?? '18:00');
    final slots = <DateTime>[];
    final ahora = DateTime.now();

    for (var m = abre; m + duracionMinutos <= cierra; m += intervaloMinutos) {
      final slot = DateTime(dia.year, dia.month, dia.day, m ~/ 60, m % 60);
      if (!soloFuturas || slot.isAfter(ahora.subtract(const Duration(minutes: 1)))) {
        slots.add(slot);
      }
    }
    return slots;
  }

  static const List<String> diasSemana = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  static String nombreDiaSemana(DateTime dt) => diasSemana[dt.weekday - 1];

  /// Ej: Lunes 10/06/2026
  static String formatearFechaConDia(DateTime dt, {bool conAnio = true}) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    if (conAnio) {
      return '${nombreDiaSemana(dt)} $d/$m/${dt.year}';
    }
    return '${nombreDiaSemana(dt)} $d/$m';
  }

  /// Fecha y hora de la cita. Ej: Lunes 10/06/2026 · 3:30 PM
  static String formatearCita(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${formatearFechaConDia(dt)} · $h:$min $ampm';
  }

  static String formatearSoloHora(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m $ampm';
  }

  static DateTime? parseCitaInicio(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static Set<String> bloqueosManualesClaves(Map<String, dynamic>? negocio) {
    return NegocioCitaService.bloqueosManuales(negocio).toSet();
  }

  /// Citas de clientes + horas bloqueadas por el dueño.
  static Future<Set<String>> slotsNoDisponibles(
    String negocioId, {
    Map<String, dynamic>? negocio,
    int duracionMinutos = 30,
    int intervaloMinutos = intervaloMinutosDefault,
  }) async {
    final claves = <String>{...bloqueosManualesClaves(negocio)};

    final desde = DateTime.now().subtract(const Duration(days: 1));
    try {
      final snap = await FirebaseFirestore.instance
          .collection('pedidos')
          .where('negocio_id', isEqualTo: negocioId)
          .where('fecha', isGreaterThan: Timestamp.fromDate(desde))
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['estado'] == 'Cancelado') continue;
        final productos = data['productos'] as List? ?? [];
        for (final p in productos) {
          if (p is! Map) continue;
          final inicio = parseCitaInicio(p['cita_inicio']);
          if (inicio == null) continue;
          final dur = (p['duracion_minutos'] as num?)?.toInt() ?? duracionMinutos;
          for (var m = 0; m < dur; m += intervaloMinutos) {
            claves.add(claveSlot(inicio.add(Duration(minutes: m))));
          }
        }
      }
    } catch (_) {}

    return claves;
  }

  static bool slotOcupado(
    DateTime slot,
    Set<String> noDisponibles,
    int duracionMinutos, {
    int intervaloMinutos = intervaloMinutosDefault,
  }) {
    for (var m = 0; m < duracionMinutos; m += intervaloMinutos) {
      if (noDisponibles.contains(claveSlot(slot.add(Duration(minutes: m))))) {
        return true;
      }
    }
    return false;
  }

  static List<DateTime> horariosLibresDelDia(
    DateTime dia,
    Map<String, dynamic>? negocio,
    Set<String> noDisponibles, {
    int duracionMinutos = 30,
    int intervaloMinutos = intervaloMinutosDefault,
  }) {
    final horario = horarioParaCitas(negocio);
    final todos = horariosDelDia(
      dia,
      horario,
      duracionMinutos: duracionMinutos,
      intervaloMinutos: intervaloMinutos,
    );
    return todos
        .where((s) => !slotOcupado(s, noDisponibles, duracionMinutos,
            intervaloMinutos: intervaloMinutos))
        .toList();
  }
}
