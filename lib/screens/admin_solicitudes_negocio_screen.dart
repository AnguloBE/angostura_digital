import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/utils/categorias_negocio.dart';
import 'package:angostura_digital/utils/comision_app_utils.dart';
import 'package:angostura_digital/utils/negocio_equipo_utils.dart';
import 'package:angostura_digital/services/negocio_equipo_service.dart';

class AdminSolicitudesNegocioScreen extends StatefulWidget {
  const AdminSolicitudesNegocioScreen({super.key});

  @override
  State<AdminSolicitudesNegocioScreen> createState() => _AdminSolicitudesNegocioScreenState();
}

class _AdminSolicitudesNegocioScreenState extends State<AdminSolicitudesNegocioScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  String _filtro = 'pendiente';
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('solicitudes_negocio')
        .orderBy('fecha', descending: true)
        .limit(100)
        .snapshots();
  }

  String _cuando(dynamic raw) {
    if (raw is! Timestamp) return '';
    final d = raw.toDate();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} $hh:$mm';
  }

  Future<void> _crear(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final nombre = (data['nombre'] ?? '').toString();
    final descripcion = (data['descripcion'] ?? '').toString();
    final telefono = (data['telefono'] ?? '').toString();
    final clienteId = (data['cliente_id'] ?? '').toString();
    var categoria = CategoriasNegocio.lista.first;
    var comoDueno = clienteId.isNotEmpty;

    final decision = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Crear este negocio'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(descripcion, style: const TextStyle(height: 1.3)),
                if (telefono.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(telefono, style: const TextStyle(color: Colors.black54)),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: categoria,
                  decoration: const InputDecoration(labelText: 'Tipo de negocio', border: OutlineInputBorder()),
                  items: CategoriasNegocio.lista
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialog(() => categoria = v ?? categoria),
                ),
                const SizedBox(height: 8),
                const Text(
                  'El negocio queda en pausa. El dueño lo publica cuando ya tenga productos y quiera que todos lo vean.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: comoDueno,
                  onChanged: clienteId.isEmpty ? null : (v) => setDialog(() => comoDueno = v ?? false),
                  title: const Text('Agregar a esta persona como dueño'),
                  subtitle: Text(
                    clienteId.isEmpty
                        ? 'No hay usuario ligado. Después agrégalo en Equipo con su teléfono.'
                        : 'Le aparece el negocio en su menú.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear')),
          ],
        ),
      ),
    );

    if (decision != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      final ref = await FirebaseFirestore.instance.collection('negocios').add({
        'nombre': nombre,
        'descripcion': descripcion,
        'categoria': categoria,
        'estado': CategoriasNegocio.esBodega(categoria)
            ? ComisionAppUtils.estadoActivo
            : ComisionAppUtils.estadoPausado,
        'fecha_creacion': FieldValue.serverTimestamp(),
        if (telefono.isNotEmpty) 'telefono': telefono,
        if (!CategoriasNegocio.esBodega(categoria)) ...const ComisionAppConfig().aFirestore(),
        if (!CategoriasNegocio.esBodega(categoria)) 'comision_acumulada': 0,
        if (!CategoriasNegocio.esBodega(categoria))
          'comision_periodo_inicio': FieldValue.serverTimestamp(),
      });

      var avisoEquipo = '';
      if (comoDueno && clienteId.isNotEmpty) {
        final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        try {
          await NegocioEquipoService.agregarMiembroPorUid(
            negocioId: ref.id,
            uid: clienteId,
            rol: NegocioEquipoUtils.rolDueno,
            agregadoPorUid: adminUid,
          );
        } catch (_) {
          avisoEquipo = ' No quedó como dueño: agrégalo en Equipo.';
        }
      }

      await doc.reference.update({
        'estado': 'aceptada',
        'negocio_id': ref.id,
        'fecha_respuesta': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              CategoriasNegocio.esBodega(categoria)
                  ? 'Negocio creado.$avisoEquipo'
                  : 'Negocio creado en pausa.$avisoEquipo El dueño lo publica cuando esté listo.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo crear: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _rechazar(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final nombre = (doc.data()['nombre'] ?? 'esta solicitud').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: Text('No se crea el negocio de "$nombre".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await doc.reference.update({
        'estado': 'rechazada',
        'fecha_respuesta': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo rechazar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes de negocios'),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (_ocupado) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Pendientes'),
                    selected: _filtro == 'pendiente',
                    onSelected: (_) => setState(() => _filtro = 'pendiente'),
                  ),
                  ChoiceChip(
                    label: const Text('Todas'),
                    selected: _filtro == 'todas',
                    onSelected: (_) => setState(() => _filtro = 'todas'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('No se pudieron cargar: ${snap.error}'));
                }
                final docs = (snap.data?.docs ?? []).where((d) {
                  final estado = (d.data()['estado'] ?? 'pendiente').toString();
                  if (estado == 'cancelada') return false;
                  if (_filtro == 'pendiente') return estado == 'pendiente';
                  return true;
                }).toList();
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No hay solicitudes en esta lista.', style: TextStyle(color: Colors.grey)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final estado = (data['estado'] ?? 'pendiente').toString();
                    final pendiente = estado == 'pendiente';
                    final color = pendiente
                        ? Colors.orange
                        : (estado == 'aceptada' ? Colors.green : Colors.blueGrey);
                    final etiqueta = pendiente
                        ? 'Pendiente'
                        : (estado == 'aceptada' ? 'Creado' : 'Rechazada');
                    final cuando = _cuando(data['fecha']);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    data['nombre']?.toString() ?? 'Sin nombre',
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    etiqueta,
                                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(data['descripcion']?.toString() ?? '', style: const TextStyle(height: 1.3)),
                            const SizedBox(height: 8),
                            Text(
                              [
                                if ((data['cliente_nombre'] ?? '').toString().trim().isNotEmpty)
                                  data['cliente_nombre'].toString(),
                                if ((data['telefono'] ?? '').toString().trim().isNotEmpty)
                                  data['telefono'].toString(),
                                if (cuando.isNotEmpty) cuando,
                              ].join(' · '),
                              style: const TextStyle(color: Colors.black54, fontSize: 13),
                            ),
                            if (pendiente) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _ocupado ? null : () => _rechazar(doc),
                                      child: const Text('Rechazar'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: _ocupado ? null : () => _crear(doc),
                                      child: const Text('Crear negocio'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
