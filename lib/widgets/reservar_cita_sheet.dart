import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:angostura_digital/services/reservar_cita_service.dart';
import 'package:angostura_digital/utils/servicio_cita_utils.dart';
import 'package:angostura_digital/utils/telefono_obligatorio_utils.dart';
import 'package:angostura_digital/widgets/cita_calendario_mes.dart';

/// Elige día y hora y crea la cita directamente (sin carrito).
class ReservarCitaSheet extends StatefulWidget {
  final String negocioId;
  final String servicioId;
  final String servicioNombre;
  final double precio;
  final String? fotoUrl;
  final int duracionMinutos;
  final Map<String, dynamic>? datosNegocio;

  const ReservarCitaSheet({
    super.key,
    required this.negocioId,
    required this.servicioId,
    required this.servicioNombre,
    required this.precio,
    this.fotoUrl,
    this.duracionMinutos = 30,
    this.datosNegocio,
  });

  static Future<bool> mostrar(
    BuildContext context, {
    required String negocioId,
    required String servicioId,
    required String servicioNombre,
    required double precio,
    String? fotoUrl,
    int duracionMinutos = 30,
    Map<String, dynamic>? datosNegocio,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inicia sesión para reservar una cita.'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    final resultado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReservarCitaSheet(
        negocioId: negocioId,
        servicioId: servicioId,
        servicioNombre: servicioNombre,
        precio: precio,
        fotoUrl: fotoUrl,
        duracionMinutos: duracionMinutos,
        datosNegocio: datosNegocio,
      ),
    );
    return resultado == true;
  }

  @override
  State<ReservarCitaSheet> createState() => _ReservarCitaSheetState();
}

class _ReservarCitaSheetState extends State<ReservarCitaSheet> {
  late DateTime _mesVisible;
  DateTime? _diaSel;
  DateTime? _horaSel;
  Set<String> _noDisponibles = {};
  bool _cargandoSlots = true;
  bool _reservando = false;

  int get _intervalo =>
      ServicioCitaUtils.intervaloDesdeNegocio(widget.datosNegocio);

  bool get _tieneHorarioCitas {
    final h = ServicioCitaUtils.horarioParaCitas(widget.datosNegocio);
    return h.isNotEmpty &&
        h.values.any((v) => v is Map && v['activo'] == true);
  }

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _mesVisible = DateTime(hoy.year, hoy.month);
    _diaSel = ServicioCitaUtils.primerDiaReservable(widget.datosNegocio);
    _cargarOcupadas();
  }

  Future<void> _cargarOcupadas() async {
    final o = await ServicioCitaUtils.slotsNoDisponibles(
      widget.negocioId,
      negocio: widget.datosNegocio,
      duracionMinutos: widget.duracionMinutos,
      intervaloMinutos: _intervalo,
    );
    if (mounted) {
      setState(() {
        _noDisponibles = o;
        _cargandoSlots = false;
      });
    }
  }

  List<DateTime> get _horasDelDia {
    if (_diaSel == null) return [];
    return ServicioCitaUtils.horariosDelDia(
      _diaSel!,
      ServicioCitaUtils.horarioParaCitas(widget.datosNegocio),
      duracionMinutos: widget.duracionMinutos,
      intervaloMinutos: _intervalo,
    );
  }

  String _metodoPagoPorDefecto() {
    final metodos = (widget.datosNegocio?['metodos_pago'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    if (metodos.isEmpty) return 'efectivo';
    return metodos.first;
  }

  Future<void> _confirmarCita() async {
    final hora = _horaSel;
    if (hora == null || _reservando) return;

    final telefonoOk = await TelefonoObligatorioUtils.solicitarVerificacion(context);
    if (!telefonoOk || !mounted) return;

    setState(() => _reservando = true);
    try {
      await ReservarCitaService.crearCita(
        negocioId: widget.negocioId,
        servicioId: widget.servicioId,
        servicioNombre: widget.servicioNombre,
        precio: widget.precio,
        citaInicio: hora,
        duracionMinutos: widget.duracionMinutos,
        fotoUrl: widget.fotoUrl,
        datosNegocio: widget.datosNegocio,
        metodoPago: _metodoPagoPorDefecto(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
      await _cargarOcupadas();
    } finally {
      if (mounted) setState(() => _reservando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final primero = DateTime.now();
    final ultimo = ServicioCitaUtils.ultimoDiaReservable(widget.datosNegocio);
    final horas = _horasDelDia;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        widget.servicioNombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Duración: ${widget.duracionMinutos} min · \$${widget.precio.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Al confirmar se reserva tu cita. El negocio la confirmará pronto.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      if (!_tieneHorarioCitas)
                        const Text(
                          'Este negocio aún no configuró horarios para citas. '
                          'Contacta al local para que active días y horas en '
                          '"Horario para citas".',
                          textAlign: TextAlign.center,
                        )
                      else ...[
                        const Text(
                          'Elige el día',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        CitaCalendarioMes(
                          mesVisible: _mesVisible,
                          diaSeleccionado: _diaSel,
                          diasHabilitados: (d) =>
                              ServicioCitaUtils.diaReservable(
                                widget.datosNegocio,
                                d,
                              ),
                          primerDiaHabilitado: primero,
                          ultimoDiaHabilitado: ultimo,
                          onDiaTap: (d) => setState(() {
                            _diaSel = d;
                            _horaSel = null;
                          }),
                          onMesAnterior: () => setState(() {
                            _mesVisible = DateTime(
                              _mesVisible.year,
                              _mesVisible.month - 1,
                            );
                          }),
                          onMesSiguiente: () => setState(() {
                            _mesVisible = DateTime(
                              _mesVisible.year,
                              _mesVisible.month + 1,
                            );
                          }),
                        ),
                        if (_diaSel != null) ...[
                          const SizedBox(height: 20),
                          Text(
                            'Horas disponibles · ${ServicioCitaUtils.formatearFechaConDia(_diaSel!, conAnio: false)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          if (_cargandoSlots)
                            const Center(child: CircularProgressIndicator())
                          else if (horas.isEmpty)
                            Text(
                              'No hay horarios para este día.',
                              style: TextStyle(color: Colors.grey.shade600),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: horas.map((h) {
                                final ocupado = ServicioCitaUtils.slotOcupado(
                                  h,
                                  _noDisponibles,
                                  widget.duracionMinutos,
                                  intervaloMinutos: _intervalo,
                                );
                                final sel = _horaSel == h;
                                return FilterChip(
                                  label: Text(
                                    ServicioCitaUtils.formatearSoloHora(h),
                                  ),
                                  selected: sel,
                                  selectedColor: Colors.deepPurple.shade100,
                                  checkmarkColor: Colors.deepPurple,
                                  onSelected: ocupado || _reservando
                                      ? null
                                      : (_) => setState(() => _horaSel = h),
                                  backgroundColor: ocupado
                                      ? Colors.grey.shade200
                                      : null,
                                  labelStyle: TextStyle(
                                    color: ocupado ? Colors.grey : null,
                                    decoration: ocupado
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _horaSel == null || _reservando
                              ? null
                              : _confirmarCita,
                          child: _reservando
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Confirmar cita',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
