import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:angostura_digital/services/negocio_cita_service.dart';
import 'package:angostura_digital/utils/servicio_cita_utils.dart';
import 'package:angostura_digital/widgets/cita_calendario_mes.dart';

/// Horario semanal de citas y bloqueo manual de franjas horarias.
class HorarioCitasNegocioScreen extends StatefulWidget {
  const HorarioCitasNegocioScreen({
    super.key,
    required this.negocioId,
    required this.nombreNegocio,
  });

  final String negocioId;
  final String nombreNegocio;

  @override
  State<HorarioCitasNegocioScreen> createState() =>
      _HorarioCitasNegocioScreenState();
}

class _HorarioCitasNegocioScreenState extends State<HorarioCitasNegocioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic> _horario = NegocioCitaService.horarioCitasPorDefecto();
  List<String> _bloqueos = [];
  Set<String> _ocupadasPedidos = {};
  int _intervalo = ServicioCitaUtils.intervaloMinutosDefault;
  int _diasAdelante = ServicioCitaUtils.diasAdelanteDefault;
  bool _cambiosLocales = false;
  bool _guardando = false;
  bool _cargandoDoc = true;

  DateTime _mesVisible = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _diaBloqueo;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _diaBloqueo = DateTime.now();
    _cargarDocumento();
  }

  Future<void> _cargarDocumento() async {
    final doc = await FirebaseFirestore.instance
        .collection('negocios')
        .doc(widget.negocioId)
        .get();
    if (!mounted) return;
    if (!_cambiosLocales) {
      _aplicarDatosNegocio(doc.data());
    }
    setState(() => _cargandoDoc = false);
    await _cargarOcupadasPedidos();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cargarOcupadasPedidos() async {
    final o = await ServicioCitaUtils.slotsNoDisponibles(
      widget.negocioId,
      negocio: {'citas_bloqueadas': _bloqueos},
    );
    if (!mounted) return;
    final manual = _bloqueos.toSet();
    setState(() {
      _ocupadasPedidos = o.difference(manual);
    });
  }

  void _aplicarDatosNegocio(Map<String, dynamic>? data) {
    final h = NegocioCitaService.horarioCitas(data);
    _horario = h.isNotEmpty
        ? Map<String, dynamic>.from(h)
        : NegocioCitaService.horarioCitasPorDefecto();
    _bloqueos = List<String>.from(NegocioCitaService.bloqueosManuales(data));
    _intervalo = ServicioCitaUtils.intervaloDesdeNegocio(data);
    _diasAdelante = ServicioCitaUtils.diasAdelanteDesdeNegocio(data);
  }

  Map<String, dynamic> get _negocioSnapshot => {
        'horario_citas': _horario,
        'citas_bloqueadas': _bloqueos,
        'intervalo_citas_minutos': _intervalo,
        'dias_citas_adelante': _diasAdelante,
      };

  Future<void> _guardarTodo() async {
    setState(() => _guardando = true);
    try {
      await NegocioCitaService.guardarConfig(
        widget.negocioId,
        horario: _horario,
        bloqueos: _bloqueos,
        intervaloMinutos: _intervalo,
        diasAdelante: _diasAdelante,
      );
      _cambiosLocales = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración de citas guardada'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _cargarOcupadasPedidos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _toggleBloqueo(DateTime slot) {
    final clave = ServicioCitaUtils.claveSlot(slot);
    if (_ocupadasPedidos.contains(clave)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta hora ya tiene una cita de un cliente'),
        ),
      );
      return;
    }
    setState(() {
      _cambiosLocales = true;
      if (_bloqueos.contains(clave)) {
        _bloqueos.remove(clave);
      } else {
        _bloqueos.add(clave);
      }
    });
  }

  Widget _buildHorarioSemanal() {
    final dias = NegocioCitaService.diasSemana;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (_, index) {
        final diaId = '${index + 1}';
        final config = Map<String, dynamic>.from(
          (_horario[diaId] as Map?)?.cast<String, dynamic>() ??
              {'activo': false, 'abre': '09:00', 'cierra': '18:00'},
        );
        final activo = config['activo'] == true;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: activo ? Colors.white : Colors.grey.shade100,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dias[index],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: activo ? Colors.black : Colors.grey,
                      ),
                    ),
                    Switch(
                      value: activo,
                      activeColor: Colors.deepPurple,
                      onChanged: (v) {
                        setState(() {
                          config['activo'] = v;
                          _horario[diaId] = config;
                          _cambiosLocales = true;
                        });
                      },
                    ),
                  ],
                ),
                if (activo)
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.wb_sunny_outlined, size: 18),
                          label: Text('Desde: ${config['abre']}'),
                          onPressed: () async {
                            final parts = config['abre'].toString().split(':');
                            final t = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: int.parse(parts[0]),
                                minute: int.parse(parts[1]),
                              ),
                            );
                            if (t != null) {
                              setState(() {
                                config['abre'] =
                                    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                                _horario[diaId] = config;
                                _cambiosLocales = true;
                              });
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.nightlight_round, size: 18),
                          label: Text('Hasta: ${config['cierra']}'),
                          onPressed: () async {
                            final parts = config['cierra'].toString().split(':');
                            final t = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: int.parse(parts[0]),
                                minute: int.parse(parts[1]),
                              ),
                            );
                            if (t != null) {
                              setState(() {
                                config['cierra'] =
                                    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                                _horario[diaId] = config;
                                _cambiosLocales = true;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    'Sin citas este día',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBloqueos() {
    final negocio = _negocioSnapshot;
    final dia = _diaBloqueo ?? DateTime.now();
    final slots = ServicioCitaUtils.horariosDelDia(
      dia,
      ServicioCitaUtils.horarioParaCitas(negocio),
      intervaloMinutos: _intervalo,
      soloFuturas: false,
    );
    final bloqueosSet = _bloqueos.toSet();
    final primero = DateTime.now();
    final ultimo = ServicioCitaUtils.ultimoDiaReservable(negocio);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Toca una hora para marcarla como ocupada o liberarla. '
          'Las citas de clientes aparecen en rojo y no se pueden quitar desde aquí.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _leyenda(Colors.green.shade100, 'Disponible'),
            const SizedBox(width: 8),
            _leyenda(Colors.orange.shade100, 'Bloqueada por ti'),
            const SizedBox(width: 8),
            _leyenda(Colors.red.shade100, 'Cita de cliente'),
          ],
        ),
        const SizedBox(height: 12),
        CitaCalendarioMes(
          mesVisible: _mesVisible,
          diaSeleccionado: dia,
          diasHabilitados: (d) =>
              ServicioCitaUtils.diaAtiendeCitas(
                ServicioCitaUtils.horarioParaCitas(negocio),
                d,
              ),
          primerDiaHabilitado: primero,
          ultimoDiaHabilitado: ultimo,
          onDiaTap: (d) => setState(() => _diaBloqueo = d),
          onMesAnterior: () => setState(() {
            _mesVisible = DateTime(_mesVisible.year, _mesVisible.month - 1);
          }),
          onMesSiguiente: () => setState(() {
            _mesVisible = DateTime(_mesVisible.year, _mesVisible.month + 1);
          }),
        ),
        const SizedBox(height: 16),
        Text(
          'Horas del ${ServicioCitaUtils.formatearFechaConDia(dia)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (slots.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Este día no tiene franjas de citas. Actívalo en la pestaña Horario.',
              textAlign: TextAlign.center,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slots.map((slot) {
              final clave = ServicioCitaUtils.claveSlot(slot);
              final esCliente = _ocupadasPedidos.contains(clave);
              final esManual = bloqueosSet.contains(clave);
              Color fondo;
              Color borde;
              if (esCliente) {
                fondo = Colors.red.shade50;
                borde = Colors.red.shade300;
              } else if (esManual) {
                fondo = Colors.orange.shade50;
                borde = Colors.orange;
              } else {
                fondo = Colors.green.shade50;
                borde = Colors.green.shade400;
              }
              return Material(
                color: fondo,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: esCliente ? null : () => _toggleBloqueo(slot),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borde),
                    ),
                    child: Text(
                      ServicioCitaUtils.formatearSoloHora(slot),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration:
                            esCliente ? TextDecoration.lineThrough : null,
                        color: esCliente ? Colors.grey : null,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _leyenda(Color color, String texto) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoDoc) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Citas · ${widget.nombreNegocio}'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
          appBar: AppBar(
            title: Text('Citas · ${widget.nombreNegocio}'),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            bottom: TabBar(
              controller: _tabs,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Horario'),
                Tab(text: 'Horas ocupadas'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _intervalo,
                            decoration: const InputDecoration(
                              labelText: 'Cada cuántos minutos',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [15, 20, 30, 45, 60]
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text('$m min'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _intervalo = v;
                                  _cambiosLocales = true;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _diasAdelante,
                            decoration: const InputDecoration(
                              labelText: 'Días a reservar',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [14, 30, 60, 90]
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d,
                                    child: Text('$d días'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _diasAdelante = v;
                                  _cambiosLocales = true;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildHorarioSemanal()),
                ],
              ),
              _buildBloqueos(),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _guardando ? null : _guardarTodo,
            backgroundColor: Colors.deepPurple,
            icon: _guardando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(_guardando ? 'Guardando...' : 'Guardar'),
          ),
        );
  }
}
