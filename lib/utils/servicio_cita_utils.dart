import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:angostura_digital/services/negocio_cita_service.dart';

/// Horarios y citas para negocios de servicios.
class ServicioCitaUtils {
  ServicioCitaUtils._();

  static const int diasAdelanteDefault = 60;
  static const int intervaloMinutosDefault = 30;
  static const int cupoPorHoraDefault = 1;

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

  /// Cuántas citas pueden coincidir en la misma hora. 1 = esa hora queda ocupada.
  static int cupoPorHora(Map<String, dynamic>? negocio) {
    final v = negocio?['cupo_citas_por_hora'];
    if (v is num && v >= 1) return v.toInt().clamp(1, 20);
    return cupoPorHoraDefault;
  }

  static bool yaPaso(DateTime slot) => !slot.isAfter(DateTime.now());

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
      if (!soloFuturas || slot.isAfter(ahora)) {
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

  static DateTime? inicioDePedido(Map<String, dynamic> data) {
    final directa = parseCitaInicio(data['cita_inicio']);
    if (directa != null) return directa;
    final productos = data['productos'] as List? ?? [];
    for (final p in productos) {
      if (p is! Map) continue;
      final inicio = parseCitaInicio(p['cita_inicio']);
      if (inicio != null) return inicio;
    }
    return null;
  }

  static int duracionDePedido(Map<String, dynamic> data, {int fallback = 30}) {
    final directa = data['duracion_minutos'];
    if (directa is num && directa > 0) return directa.toInt();
    final productos = data['productos'] as List? ?? [];
    for (final p in productos) {
      if (p is! Map) continue;
      final d = (p['duracion_minutos'] as num?)?.toInt();
      if (d != null && d > 0) return d;
    }
    return fallback;
  }

  /// Citas reales del negocio. Una consulta solo por negocio, sin índice extra.
  static Future<List<CitaAgendada>> citasDelNegocio(String negocioId) async {
    final snap = await FirebaseFirestore.instance
        .collection('pedidos')
        .where('negocio_id', isEqualTo: negocioId)
        .get();
    final ahora = DateTime.now();
    final lista = <CitaAgendada>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      if ((data['estado'] ?? '').toString() == 'Cancelado') continue;
      final inicio = inicioDePedido(data);
      if (inicio == null) continue;
      final fin = inicio.add(Duration(minutes: duracionDePedido(data)));
      if (fin.isBefore(ahora.subtract(const Duration(hours: 12)))) continue;
      lista.add(CitaAgendada(inicio: inicio, fin: fin));
    }
    return lista;
  }

  static Future<AgendaCitas> cargarAgenda(
    String negocioId, {
    Map<String, dynamic>? negocio,
  }) async {
    final citas = await citasDelNegocio(negocioId);
    return AgendaCitas(
      citas: citas,
      bloqueos: bloqueosManualesClaves(negocio),
    );
  }

  static int citasEncimadas(DateTime slot, int duracionMinutos, List<CitaAgendada> citas) {
    final fin = slot.add(Duration(minutes: duracionMinutos));
    var n = 0;
    for (final c in citas) {
      if (slot.isBefore(c.fin) && c.inicio.isBefore(fin)) n++;
    }
    return n;
  }

  static bool bloqueoManualCubre(
    DateTime slot,
    int duracionMinutos,
    Set<String> bloqueos, {
    int intervaloMinutos = intervaloMinutosDefault,
  }) {
    final fin = slot.add(Duration(minutes: duracionMinutos));
    for (final clave in bloqueos) {
      final inicio = DateTime.tryParse(clave);
      if (inicio == null) continue;
      final finBloqueo = inicio.add(Duration(minutes: intervaloMinutos));
      if (slot.isBefore(finBloqueo) && inicio.isBefore(fin)) return true;
    }
    return false;
  }

  /// Hora pasada, bloqueada o con el cupo de esa hora ya lleno.
  static bool noSePuedeAgendar({
    required DateTime slot,
    required AgendaCitas agenda,
    required int duracionMinutos,
    required int intervaloMinutos,
    required int cupo,
  }) {
    if (yaPaso(slot)) return true;
    if (bloqueoManualCubre(
      slot,
      duracionMinutos,
      agenda.bloqueos,
      intervaloMinutos: intervaloMinutos,
    )) {
      return true;
    }
    return citasEncimadas(slot, duracionMinutos, agenda.citas) >= cupo;
  }

  static String motivoNoDisponible({
    required DateTime slot,
    required AgendaCitas agenda,
    required int duracionMinutos,
    required int intervaloMinutos,
    required int cupo,
  }) {
    if (yaPaso(slot)) return 'Esa hora ya pasó. Elige una más tarde.';
    if (bloqueoManualCubre(
      slot,
      duracionMinutos,
      agenda.bloqueos,
      intervaloMinutos: intervaloMinutos,
    )) {
      return 'Esa hora está bloqueada. Elige otra.';
    }
    final n = citasEncimadas(slot, duracionMinutos, agenda.citas);
    if (n >= cupo) {
      return cupo <= 1
          ? 'Esa hora ya tiene una cita. Elige otra.'
          : 'Esa hora ya tiene $n citas (cupo $cupo). Elige otra.';
    }
    return 'Esa hora no está disponible.';
  }
}

class CitaAgendada {
  final DateTime inicio;
  final DateTime fin;

  const CitaAgendada({required this.inicio, required this.fin});
}

class AgendaCitas {
  final List<CitaAgendada> citas;
  final Set<String> bloqueos;

  const AgendaCitas({
    this.citas = const [],
    this.bloqueos = const {},
  });
}
