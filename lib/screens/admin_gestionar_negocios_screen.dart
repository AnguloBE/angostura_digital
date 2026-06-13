import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/utils/comision_app_utils.dart';
import 'package:angostura_digital/services/negocio_comision_service.dart';
import 'package:angostura_digital/screens/equipo_negocio_screen.dart';
import 'package:angostura_digital/screens/gestionar_negocio_screen.dart';
import 'package:angostura_digital/utils/categorias_negocio.dart';

class AdminGestionarNegociosScreen extends StatefulWidget {
  const AdminGestionarNegociosScreen({super.key});

  @override
  State<AdminGestionarNegociosScreen> createState() => _AdminGestionarNegociosScreenState();
}

class _AdminGestionarNegociosScreenState extends State<AdminGestionarNegociosScreen> {
  String _filtro = 'todos';
  final TextEditingController _busquedaCtrl = TextEditingController();

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _mostrarFormularioNegocio({String? docId, Map<String, dynamic>? data}) async {
    final esEdicion = docId != null;
    final nombreCtrl = TextEditingController(text: data?['nombre'] ?? '');
    final descCtrl = TextEditingController(text: data?['descripcion'] ?? '');
    var categoria = CategoriasNegocio.normalizar(data?['categoria']);

    final categorias = CategoriasNegocio.lista;

    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(esEdicion ? 'Editar negocio' : 'Nuevo negocio'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: categoria,
                  decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                  items: categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDialog(() => categoria = v!),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
                ),
                if (!esEdicion)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Después de crear el negocio, usa «Equipo» para agregar dueños y trabajadores.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (nombreCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (guardado != true || !mounted) return;

    try {
      final payload = <String, dynamic>{
        'nombre': nombreCtrl.text.trim(),
        'descripcion': descCtrl.text.trim(),
        'categoria': categoria,
      };

      if (esEdicion) {
        await FirebaseFirestore.instance.collection('negocios').doc(docId).update(payload);
      } else {
        await FirebaseFirestore.instance.collection('negocios').add({
          ...payload,
          'estado': ComisionAppUtils.estadoActivo,
          'fecha_creacion': FieldValue.serverTimestamp(),
          ...const ComisionAppConfig().aFirestore(),
          'comision_acumulada': 0,
          'comision_periodo_inicio': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(esEdicion ? 'Negocio actualizado' : 'Negocio creado'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _registrarPagoComision(String negocioId, String nombre, double saldoActual) async {
    final montoCtrl = TextEditingController(
      text: saldoActual > 0 ? saldoActual.toStringAsFixed(2) : '',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Registrar pago · $nombre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo del periodo: \$${saldoActual.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Indica cuánto pagó el negocio. Se descontará del saldo y quedará registrado con la fecha de hoy.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Monto pagado (\$)',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Registrar pago'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final monto = double.tryParse(montoCtrl.text.trim().replaceAll(',', '.'));
    if (monto == null || monto <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido mayor a cero.'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (monto > saldoActual && saldoActual > 0) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Monto mayor al saldo'),
          content: Text(
            'El saldo es \$${saldoActual.toStringAsFixed(2)} y vas a registrar \$${monto.toStringAsFixed(2)}. '
            'El saldo quedará en \$0.00. ¿Continuar?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, registrar')),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    }

    try {
      await NegocioComisionService.registrarPago(negocioId: negocioId, monto: monto);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pago de \$${monto.toStringAsFixed(2)} registrado.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar el pago: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _configurarComision(String docId, Map<String, dynamic> data) async {
    final config = ComisionAppConfig.desdeMap(data);
    final pctCtrl = TextEditingController(text: config.porcentaje.toStringAsFixed(0));
    final maxCtrl = TextEditingController(text: config.maximoPorPedido.toStringAsFixed(0));
    var pagadaPor = config.pagadaPor;
    var periodo = config.periodo;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Uso de la app'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Comisión por pedido (ej. 10% con tope de \$10). Siempre se suma al saldo del periodo que el negocio te paga.\n\n'
                  '· Negocio absorbe: el cliente no ve cargo extra.\n'
                  '· Cliente paga extra: el cliente lo paga en el pedido y el negocio también te lo liquida al cierre del periodo.',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pctCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Porcentaje (%)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: maxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Máximo por pedido (\$)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('¿Cómo se cobra al cliente?', style: TextStyle(fontWeight: FontWeight.bold)),
                RadioGroup<String>(
                  groupValue: pagadaPor,
                  onChanged: (v) {
                    if (v != null) setDialog(() => pagadaPor = v);
                  },
                  child: Column(
                    children: const [
                      RadioListTile<String>(
                        title: Text('Negocio absorbe (sin cargo extra)'),
                        subtitle: Text('Se acumula en su saldo del periodo', style: TextStyle(fontSize: 12)),
                        value: 'negocio',
                      ),
                      RadioListTile<String>(
                        title: Text('Cliente paga extra en el pedido'),
                        subtitle: Text('El negocio cobra ese extra y también se acumula en su saldo', style: TextStyle(fontSize: 12)),
                        value: 'cliente',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: periodo,
                  decoration: const InputDecoration(labelText: 'Cobro del periodo', border: OutlineInputBorder()),
                  items: ComisionAppUtils.periodos
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(ComisionAppUtils.etiquetaPeriodo(p)),
                          ))
                      .toList(),
                  onChanged: (v) => setDialog(() => periodo = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final nueva = ComisionAppConfig(
      porcentaje: double.tryParse(pctCtrl.text.trim()) ?? 10,
      maximoPorPedido: double.tryParse(maxCtrl.text.trim()) ?? 10,
      pagadaPor: pagadaPor,
      periodo: periodo,
    );

    await FirebaseFirestore.instance.collection('negocios').doc(docId).update(nueva.aFirestore());
  }

  Future<void> _cambiarEstado(String docId, String estado) async {
    await FirebaseFirestore.instance.collection('negocios').doc(docId).update({'estado': estado});
  }

  Future<void> _eliminarNegocio(String docId, String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar negocio'),
        content: Text('¿Eliminar "$nombre" y sus datos? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection('negocios').doc(docId).delete();
    }
  }

  bool _pasaFiltro(String estado) {
    if (_filtro == 'todos') return true;
    if (_filtro == 'activo') return ComisionAppUtils.esActivo(estado);
    if (_filtro == 'pausado') return ComisionAppUtils.esPausado(estado);
    return true;
  }

  bool _pasaBusqueda(String nombre) {
    final q = _busquedaCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return nombre.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar negocios'),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormularioNegocio(),
        icon: const Icon(Icons.add_business),
        label: const Text('Nuevo negocio'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _busquedaCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre del negocio...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busquedaCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _busquedaCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _chipFiltro('todos', 'Todos'),
                _chipFiltro('activo', 'Activos'),
                _chipFiltro('pausado', 'Pausados'),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('negocios').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = (snapshot.data?.docs ?? []).where((d) {
                  final data = d.data() as Map;
                  final estado = data['estado']?.toString();
                  final nombre = (data['nombre'] ?? '').toString();
                  return _pasaFiltro(estado ?? '') && _pasaBusqueda(nombre);
                }).toList()
                  ..sort((a, b) {
                    final na = ((a.data() as Map)['nombre'] ?? '').toString().toLowerCase();
                    final nb = ((b.data() as Map)['nombre'] ?? '').toString().toLowerCase();
                    return na.compareTo(nb);
                  });

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      _busquedaCtrl.text.trim().isNotEmpty
                          ? 'No hay negocios con ese nombre.'
                          : 'No hay negocios en este filtro.',
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                  itemCount: docs.length,
                  itemBuilder: (context, index) => _tarjetaNegocio(docs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipFiltro(String id, String label) {
    final sel = _filtro == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => setState(() => _filtro = id),
      ),
    );
  }

  Widget _tarjetaNegocio(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final estado = data['estado']?.toString();
    final visual = ComisionAppUtils.estadoVisual(estado);
    final config = ComisionAppConfig.desdeMap(data);
    final acumulada = ComisionAppUtils.leerAcumulada(data['comision_acumulada']);
    final ultimoPagoTexto = ComisionAppUtils.textoUltimoPago(data);
    final nombre = data['nombre'] ?? 'Sin nombre';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: visual.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(visual.etiqueta, style: TextStyle(color: visual.color, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            Text(data['categoria'] ?? '', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saldo del periodo (${ComisionAppUtils.etiquetaPeriodo(config.periodo)}): \$${acumulada.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo.shade900),
                  ),
                  Text(
                    ComisionAppUtils.resumenComision(config),
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  Text(
                    'A pagar a la app en este periodo',
                    style: TextStyle(fontSize: 11, color: Colors.indigo.shade700),
                  ),
                  if (ultimoPagoTexto != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      ultimoPagoTexto,
                      style: TextStyle(fontSize: 12, color: Colors.teal.shade800, fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (ComisionAppUtils.esActivo(estado))
                  _btn('Pausar', Colors.deepPurple, () => _cambiarEstado(doc.id, ComisionAppUtils.estadoPausado)),
                if (ComisionAppUtils.esPausado(estado))
                  _btn('Activar', Colors.green, () => _cambiarEstado(doc.id, ComisionAppUtils.estadoActivo)),
                _btn('Comisión', Colors.indigo, () => _configurarComision(doc.id, data)),
                _btn('Equipo', Colors.deepOrange, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EquipoNegocioScreen(
                        negocioId: doc.id,
                        nombreNegocio: nombre,
                        esAdmin: true,
                      ),
                    ),
                  );
                }),
                _btn('Registrar pago', Colors.teal, () => _registrarPagoComision(doc.id, nombre, acumulada)),
                _btn('Editar', Colors.blueGrey, () => _mostrarFormularioNegocio(docId: doc.id, data: data)),
                _btn('Panel', Colors.blueAccent, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GestionarNegocioScreen(
                        negocioId: doc.id,
                        nombreActual: nombre,
                        categoria: data['categoria'] ?? '',
                        estadoActual: estado ?? ComisionAppUtils.estadoActivo,
                        fotoUrlActual: data['foto_url'],
                      ),
                    ),
                  );
                }),
                _btn('Eliminar', Colors.redAccent, () => _eliminarNegocio(doc.id, nombre)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color)),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
