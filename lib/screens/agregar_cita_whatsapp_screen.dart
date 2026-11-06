import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/screens/agregar_servicio_screen.dart';
import 'package:angostura_digital/services/reservar_cita_service.dart';
import 'package:angostura_digital/utils/servicio_cita_utils.dart';
import 'package:angostura_digital/utils/telefono_local_utils.dart';
import 'package:angostura_digital/widgets/cita_calendario_mes.dart';

class _ServicioCita {
  final String id;
  final String nombre;
  final double precio;
  final int duracionMinutos;
  final String? fotoUrl;

  const _ServicioCita({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.duracionMinutos,
    this.fotoUrl,
  });
}

/// El negocio anota una cita en persona o por mensaje.
class AgregarCitaWhatsappScreen extends StatefulWidget {
  final String negocioId;
  final String nombreNegocio;

  const AgregarCitaWhatsappScreen({
    super.key,
    required this.negocioId,
    required this.nombreNegocio,
  });

  @override
  State<AgregarCitaWhatsappScreen> createState() => _AgregarCitaWhatsappScreenState();
}

class _AgregarCitaWhatsappScreenState extends State<AgregarCitaWhatsappScreen> {
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  Map<String, dynamic>? _negocio;
  List<_ServicioCita> _servicios = [];
  String? _servicioId;
  bool _cargando = true;
  bool _guardando = false;
  String? _errorTelefono;

  late DateTime _mesVisible;
  DateTime? _diaSel;
  DateTime? _horaSel;
  AgendaCitas _agenda = const AgendaCitas();

  _ServicioCita? get _servicio {
    for (final s in _servicios) {
      if (s.id == _servicioId) return s;
    }
    return _servicios.isEmpty ? null : _servicios.first;
  }

  int get _duracion => _servicio?.duracionMinutos ?? 30;

  int get _intervalo => ServicioCitaUtils.intervaloDesdeNegocio(_negocio);

  bool get _tieneHorario {
    final h = ServicioCitaUtils.horarioParaCitas(_negocio);
    return h.isNotEmpty && h.values.any((v) => v is Map && v['activo'] == true);
  }

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _mesVisible = DateTime(hoy.year, hoy.month);
    _diaSel = DateTime(hoy.year, hoy.month, hoy.day);
    _cargar();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final negocio = await FirebaseFirestore.instance.collection('negocios').doc(widget.negocioId).get();
      final productos = await FirebaseFirestore.instance
          .collection('productos')
          .where('negocio_id', isEqualTo: widget.negocioId)
          .get();

      final servicios = <_ServicioCita>[];
      for (final doc in productos.docs) {
        final data = doc.data();
        if (data['es_servicio'] != true) continue;
        final tipo = data['tipo_servicio']?.toString() ?? 'cita';
        if (tipo != 'cita') continue;
        servicios.add(_ServicioCita(
          id: doc.id,
          nombre: (data['nombre'] ?? 'Servicio').toString(),
          precio: (data['precio'] as num?)?.toDouble() ?? 0,
          duracionMinutos: (data['duracion_minutos'] as num?)?.toInt() ?? 30,
          fotoUrl: data['foto_url']?.toString(),
        ));
      }
      servicios.sort((a, b) => a.nombre.compareTo(b.nombre));

      if (!mounted) return;
      setState(() {
        _negocio = negocio.data();
        _servicios = servicios;
        _servicioId = servicios.isEmpty ? null : servicios.first.id;
        _diaSel = ServicioCitaUtils.primerDiaReservable(_negocio) ?? _diaSel;
        _cargando = false;
      });
      await _cargarOcupadas();
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _cargarOcupadas() async {
    final o = await ServicioCitaUtils.cargarAgenda(
      widget.negocioId,
      negocio: _negocio,
    );
    if (mounted) setState(() => _agenda = o);
  }

  List<DateTime> get _horasDelDia {
    final dia = _diaSel;
    if (dia == null) return [];
    return ServicioCitaUtils.horariosDelDia(
      dia,
      ServicioCitaUtils.horarioParaCitas(_negocio),
      duracionMinutos: _duracion,
      intervaloMinutos: _intervalo,
    );
  }

  bool _diaHabilitado(DateTime dia) {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    if (dia.isBefore(inicioHoy)) return false;
    final ultimo = ServicioCitaUtils.ultimoDiaReservable(_negocio);
    if (ultimo != null && dia.isAfter(DateTime(ultimo.year, ultimo.month, ultimo.day))) {
      return false;
    }
    return true;
  }

  Future<void> _elegirHoraManual() async {
    final dia = _diaSel;
    if (dia == null) return;
    final inicial = _horaSel ?? DateTime.now();
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: inicial.hour, minute: inicial.minute),
      helpText: 'Hora de la cita',
    );
    if (hora == null || !mounted) return;
    final slot = DateTime(dia.year, dia.month, dia.day, hora.hour, hora.minute);
    if (ServicioCitaUtils.yaPaso(slot)) {
      _aviso('Esa hora ya pasó. Elige una más tarde.');
      return;
    }
    if (ServicioCitaUtils.noSePuedeAgendar(
      slot: slot,
      agenda: _agenda,
      duracionMinutos: _duracion,
      intervaloMinutos: _intervalo,
      cupo: ServicioCitaUtils.cupoPorHora(_negocio),
    )) {
      _aviso(ServicioCitaUtils.motivoNoDisponible(
        slot: slot,
        agenda: _agenda,
        duracionMinutos: _duracion,
        intervaloMinutos: _intervalo,
        cupo: ServicioCitaUtils.cupoPorHora(_negocio),
      ));
      return;
    }
    setState(() => _horaSel = slot);
  }

  Future<void> _guardar() async {
    final servicio = _servicio;
    final hora = _horaSel;
    final nombre = _nombreCtrl.text.trim();
    final telError = TelefonoLocalUtils.mensajeErrorOpcional(_telefonoCtrl.text);
    setState(() => _errorTelefono = telError);

    if (nombre.isEmpty) {
      _aviso('Escribe el nombre de la persona.');
      return;
    }
    if (telError != null) {
      _aviso(telError);
      return;
    }
    if (servicio == null) {
      _aviso('Primero agrega un servicio con cita.');
      return;
    }
    if (hora == null) {
      _aviso('Elige el día y la hora.');
      return;
    }

    setState(() => _guardando = true);
    try {
      await ReservarCitaService.crearCitaManual(
        negocioId: widget.negocioId,
        servicioId: servicio.id,
        servicioNombre: servicio.nombre,
        precio: servicio.precio,
        citaInicio: hora,
        duracionMinutos: servicio.duracionMinutos,
        clienteNombre: nombre,
        clienteTelefono: _telefonoCtrl.text,
        notas: _notasCtrl.text,
        fotoUrl: servicio.fotoUrl,
        datosNegocio: _negocio,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _aviso(e.toString().replaceFirst('Exception: ', ''));
      await _cargarOcupadas();
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: Colors.redAccent),
    );
  }

  List<Widget> _camposPersona(_ServicioCita? servicio) {
    return [
      Text(
        'Anota la cita, en persona o por mensaje. Queda confirmada y ocupa ese horario.',
        style: TextStyle(color: Colors.grey.shade700, height: 1.3),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _nombreCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Nombre',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.person_outline),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _telefonoCtrl,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
        decoration: InputDecoration(
          labelText: 'Teléfono (opcional, 10 dígitos)',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.phone_outlined),
          errorText: _errorTelefono,
        ),
        onChanged: (_) {
          if (_errorTelefono != null) setState(() => _errorTelefono = null);
        },
      ),
      const SizedBox(height: 12),
      if (_servicios.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Todavía no tienes un servicio con cita.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text('Crea uno (corte, consulta, etc.) y luego agenda aquí.'),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AgregarServicioScreen(negocioId: widget.negocioId),
                    ),
                  );
                  if (mounted) {
                    setState(() => _cargando = true);
                    await _cargar();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Crear servicio'),
              ),
            ],
          ),
        )
      else
        DropdownButtonFormField<String>(
          initialValue: _servicioId,
          decoration: const InputDecoration(
            labelText: 'Servicio',
            border: OutlineInputBorder(),
          ),
          items: _servicios
              .map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text('${s.nombre} · \$${s.precio.toStringAsFixed(0)} · ${s.duracionMinutos} min'),
                  ))
              .toList(),
          onChanged: (id) async {
            setState(() {
              _servicioId = id;
              _horaSel = null;
            });
            await _cargarOcupadas();
          },
        ),
      const SizedBox(height: 16),
      TextField(
        controller: _notasCtrl,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'Nota (opcional)',
          hintText: 'Ej. viene con un acompañante',
          border: OutlineInputBorder(),
        ),
      ),
      if (servicio != null && _horaSel != null) ...[
        const SizedBox(height: 14),
        Text(
          '${servicio.nombre} · ${ServicioCitaUtils.formatearCita(_horaSel!)} · \$${servicio.precio.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ];
  }

  List<Widget> _camposHorario(List<DateTime> horas, DateTime hoy, DateTime? ultimo) {
    return [
      const Text('Día', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      CitaCalendarioMes(
        mesVisible: _mesVisible,
        diaSeleccionado: _diaSel,
        diasHabilitados: _diaHabilitado,
        primerDiaHabilitado: DateTime(hoy.year, hoy.month, hoy.day),
        ultimoDiaHabilitado: ultimo,
        onDiaTap: (d) => setState(() {
          _diaSel = d;
          _horaSel = null;
        }),
        onMesAnterior: () => setState(() {
          _mesVisible = DateTime(_mesVisible.year, _mesVisible.month - 1);
        }),
        onMesSiguiente: () => setState(() {
          _mesVisible = DateTime(_mesVisible.year, _mesVisible.month + 1);
        }),
      ),
      const SizedBox(height: 16),
      Text(
        _diaSel == null
            ? 'Hora'
            : 'Hora · ${ServicioCitaUtils.formatearFechaConDia(_diaSel!, conAnio: false)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      if (!_tieneHorario)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Aún no hay horario de citas. Elige una hora que todavía no pase.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        )
      else if (horas.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            _diaSel != null &&
                    ServicioCitaUtils.diaAtiendeCitas(
                      ServicioCitaUtils.horarioParaCitas(_negocio),
                      _diaSel!,
                    )
                ? 'Esas horas ya pasaron. Elige otro día.'
                : 'Este día no está en el horario. Puedes elegir una hora más tarde.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ),
      if (horas.isEmpty &&
          (!_tieneHorario ||
              _diaSel == null ||
              !ServicioCitaUtils.diaAtiendeCitas(
                ServicioCitaUtils.horarioParaCitas(_negocio),
                _diaSel!,
              )))
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _diaSel == null ? null : _elegirHoraManual,
            icon: const Icon(Icons.schedule),
            label: Text(_horaSel == null ? 'Elegir hora' : ServicioCitaUtils.formatearSoloHora(_horaSel!)),
          ),
        )
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: horas.map((h) {
            final cupo = ServicioCitaUtils.cupoPorHora(_negocio);
            final ocupado = ServicioCitaUtils.noSePuedeAgendar(
              slot: h,
              agenda: _agenda,
              duracionMinutos: _duracion,
              intervaloMinutos: _intervalo,
              cupo: cupo,
            );
            final encimadas = ServicioCitaUtils.citasEncimadas(h, _duracion, _agenda.citas);
            final sel = _horaSel == h;
            return FilterChip(
              label: Text(
                cupo > 1 && encimadas > 0 && !ocupado
                    ? '${ServicioCitaUtils.formatearSoloHora(h)} · $encimadas/$cupo'
                    : ServicioCitaUtils.formatearSoloHora(h),
              ),
              selected: sel,
              selectedColor: Colors.deepPurple.shade100,
              checkmarkColor: Colors.deepPurple,
              onSelected: ocupado || _guardando ? null : (_) => setState(() => _horaSel = h),
              backgroundColor: ocupado ? Colors.grey.shade200 : null,
              labelStyle: TextStyle(
                color: ocupado ? Colors.grey : null,
                decoration: ocupado ? TextDecoration.lineThrough : null,
              ),
            );
          }).toList(),
        ),
    ];
  }

  Widget _scroll(List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final servicio = _servicio;
    final horas = _horasDelDia;
    final hoy = DateTime.now();
    final ultimo = ServicioCitaUtils.ultimoDiaReservable(_negocio);
    final persona = _camposPersona(servicio);
    final horario = _camposHorario(horas, hoy, ultimo);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Agregar cita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final ancha = constraints.maxWidth >= 760;
                          if (!ancha) return _scroll([...persona, const SizedBox(height: 18), ...horario]);
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _scroll(persona)),
                              SizedBox(width: 420, child: _scroll(horario)),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _guardando || _servicios.isEmpty ? null : _guardar,
                            icon: _guardando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.event_available),
                            label: const Text('Guardar cita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
