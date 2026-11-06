import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/screens/agregar_promocion_screen.dart';
import 'package:angostura_digital/utils/dias_semana.dart';
import 'package:angostura_digital/utils/mobile_image_utils.dart';
import 'package:angostura_digital/widgets/selector_dias_semana.dart';
import 'package:angostura_digital/widgets/square_image.dart';

class AdminAnunciosScreen extends StatefulWidget {
  const AdminAnunciosScreen({super.key});

  @override
  State<AdminAnunciosScreen> createState() => _AdminAnunciosScreenState();
}

class _AdminAnunciosScreenState extends State<AdminAnunciosScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anuncios'),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Anuncios'),
            Tab(text: 'Promociones'),
          ],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabs,
        builder: (context, _) {
          if (_tabs.index != 0) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            backgroundColor: globals.colorFondo,
            foregroundColor: Colors.white,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const _EditorAnuncioScreen()));
            },
            icon: const Icon(Icons.add),
            label: const Text('Nuevo anuncio'),
          );
        },
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _ListaAnuncios(),
          _ListaPromosDestacables(),
        ],
      ),
    );
  }
}

class _ListaAnuncios extends StatelessWidget {
  const _ListaAnuncios();

  Future<void> _borrar(BuildContext context, String id, String titulo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar anuncio'),
        content: Text('Se deja de mostrar "$titulo".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance.collection('anuncios').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('anuncios').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs.toList() ?? [];
        docs.sort((a, b) {
          final da = a.data()['destacado'] == true;
          final db = b.data()['destacado'] == true;
          if (da != db) return da ? -1 : 1;
          return _fecha(b.data()).compareTo(_fecha(a.data()));
        });
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Todavía no hay anuncios. Los que publiques salen en Inicio, junto con las promociones.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, height: 1.35),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final titulo = (data['titulo'] ?? 'Sin título').toString();
            final destacado = data['destacado'] == true;
            final visible = DiasSemana.vigente(data, ocultarInactivos: true);
            final estado = data['activo'] == false
                ? 'Pausado'
                : (visible ? (destacado ? 'Destacado' : 'Visible') : 'Hoy no se muestra');
            final foto = (data['foto_url'] ?? '').toString();
            return Card(
              child: ListTile(
                leading: foto.isEmpty
                    ? const CircleAvatar(child: Icon(Icons.campaign))
                    : SquareImage(imageUrl: foto, size: 52, borderRadius: BorderRadius.circular(8)),
                title: Text(titulo, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '$estado · ${DiasSemana.vigencia(data, sinFecha: 'Sin fecha de fin')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: destacado ? 'Quitar destacado' : 'Destacar',
                      icon: Icon(
                        destacado ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber.shade800,
                      ),
                      onPressed: () => doc.reference.update({'destacado': !destacado}),
                    ),
                    IconButton(
                      tooltip: 'Quitar',
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _borrar(context, doc.id, titulo),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _EditorAnuncioScreen(anuncioId: doc.id, data: data),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _ListaPromosDestacables extends StatelessWidget {
  const _ListaPromosDestacables();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'La estrella pone la promoción primero en Inicio. En editar eliges los días, por ejemplo de lunes a miércoles, y se repite sola.',
            style: TextStyle(color: Colors.black54, height: 1.3),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('promociones')
                .orderBy('fecha_creacion', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs.toList() ?? [];
              docs.sort((a, b) {
                final da = a.data()['destacado'] == true;
                final db = b.data()['destacado'] == true;
                if (da != db) return da ? -1 : 1;
                return _fecha(b.data()).compareTo(_fecha(a.data()));
              });
              if (docs.isEmpty) {
                return const Center(child: Text('No hay promociones.', style: TextStyle(color: Colors.grey)));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final destacado = data['destacado'] == true;
                  final visible = DiasSemana.vigente(data);
                  final titulo = (data['titulo'] ?? 'Promoción').toString();
                  return Card(
                    child: ListTile(
                      title: Text(titulo, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${visible ? 'Se muestra' : 'Ahora no se muestra'} · ${data['nombre_negocio'] ?? 'Negocio'}\n${DiasSemana.vigencia(data)}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: destacado ? 'Quitar destacado' : 'Destacar',
                        icon: Icon(
                          destacado ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber.shade800,
                        ),
                        onPressed: () => doc.reference.update({'destacado': !destacado}),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AgregarPromocionScreen(
                              negocioId: (data['negocio_id'] ?? '').toString(),
                              nombreNegocio: (data['nombre_negocio'] ?? 'Negocio').toString(),
                              promoId: doc.id,
                              promoData: data,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

DateTime _fecha(Map<String, dynamic> data) {
  final f = data['fecha_creacion'];
  if (f is Timestamp) return f.toDate();
  return DateTime.fromMillisecondsSinceEpoch(0);
}

class _EditorAnuncioScreen extends StatefulWidget {
  const _EditorAnuncioScreen({this.anuncioId, this.data});

  final String? anuncioId;
  final Map<String, dynamic>? data;

  @override
  State<_EditorAnuncioScreen> createState() => _EditorAnuncioScreenState();
}

class _EditorAnuncioScreenState extends State<_EditorAnuncioScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descCtrl;
  bool _destacado = false;
  bool _activo = true;
  Set<int> _dias = {};
  DateTime? _fechaFinal;
  String? _fotoUrl;
  Uint8List? _imagenBytes;
  bool _fotoQuitada = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final data = widget.data;
    _tituloCtrl = TextEditingController(text: data?['titulo']?.toString() ?? '');
    _descCtrl = TextEditingController(text: data?['descripcion']?.toString() ?? '');
    _destacado = data?['destacado'] == true;
    _activo = data?['activo'] != false;
    _dias = DiasSemana.leer(data?['dias_semana']).toSet();
    _fotoUrl = data?['foto_url']?.toString();
    final fin = data?['fecha_final'];
    if (fin is Timestamp) _fechaFinal = fin.toDate();
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFoto() async {
    final bytes = await MobileImageUtils.elegirYRecortar(
      context: context,
      cropTitle: 'Recortar anuncio',
    );
    if (bytes == null || !mounted) return;
    setState(() {
      _imagenBytes = bytes;
      _fotoQuitada = false;
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      var foto = _fotoQuitada ? '' : (_fotoUrl ?? '');
      if (_imagenBytes != null) {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
        final fileName = 'anuncios/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child(fileName);
        final upload = ref.putData(_imagenBytes!, SettableMetadata(contentType: 'image/jpeg'));
        foto = await (await upload).ref.getDownloadURL();
      }

      final datos = <String, dynamic>{
        'titulo': _tituloCtrl.text.trim(),
        'descripcion': _descCtrl.text.trim(),
        'foto_url': foto,
        'destacado': _destacado,
        'activo': _activo,
        'dias_semana': DiasSemana.leer(_dias),
        'tipo': 'anuncio',
      };
      if (_fechaFinal != null) {
        datos['fecha_final'] = Timestamp.fromDate(_fechaFinal!);
      } else if (widget.anuncioId != null) {
        datos['fecha_final'] = FieldValue.delete();
      }

      final col = FirebaseFirestore.instance.collection('anuncios');
      if (widget.anuncioId == null) {
        datos['fecha_creacion'] = FieldValue.serverTimestamp();
        datos['creado_por'] = FirebaseAuth.instance.currentUser?.uid ?? '';
        await col.add(datos);
      } else {
        await col.doc(widget.anuncioId).update(datos);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anuncio guardado'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vista = DiasSemana.vigencia(
      {
        'dias_semana': DiasSemana.leer(_dias),
        if (_fechaFinal != null) 'fecha_final': Timestamp.fromDate(_fechaFinal!),
      },
      sinFecha: 'Visible hasta que lo pauses',
    );
    final hayFoto = _imagenBytes != null || ((_fotoUrl ?? '').isNotEmpty && !_fotoQuitada);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.anuncioId == null ? 'Nuevo anuncio' : 'Editar anuncio'),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (hayFoto) ...[
            GestureDetector(
              onTap: _elegirFoto,
              child: SquarePhotoPicker(
                imageBytes: _imagenBytes,
                imageUrl: _fotoQuitada ? null : _fotoUrl,
                emptyChild: const FotoVacia(icono: Icons.campaign, color: Colors.blueGrey),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() {
                  _imagenBytes = null;
                  _fotoUrl = null;
                  _fotoQuitada = true;
                }),
                child: const Text('Quitar foto'),
              ),
            ),
          ] else
            OutlinedButton.icon(
              onPressed: _elegirFoto,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Agregar foto (opcional)'),
            ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _tituloCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe un título' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Texto del anuncio',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Destacado'),
            subtitle: const Text('Sale primero en Inicio, después del aviso de cuenta'),
            value: _destacado,
            activeThumbColor: Colors.amber.shade800,
            secondary: Icon(Icons.star_rounded, color: Colors.amber.shade700),
            onChanged: (v) => setState(() => _destacado = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Visible'),
            subtitle: const Text('Si lo pausas, deja de verse en Inicio'),
            value: _activo,
            secondary: const Icon(Icons.visibility_outlined),
            onChanged: (v) => setState(() => _activo = v),
          ),
          const SizedBox(height: 8),
          SelectorDiasSemana(
            seleccion: _dias,
            onChanged: (v) => setState(() => _dias = v),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: Colors.blueGrey.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.blueGrey.shade200),
            ),
            child: ListTile(
              leading: const Icon(Icons.event, color: Colors.blueGrey),
              title: Text(
                _fechaFinal == null
                    ? 'Fecha límite (opcional)'
                    : 'Visible hasta ${_fechaFinal!.day}/${_fechaFinal!.month}/${_fechaFinal!.year}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _fechaFinal == null
                    ? 'Sin fecha, sigue hasta que lo pauses.'
                    : 'Deja de mostrarse al día siguiente.',
              ),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final seleccion = await elegirFechaLimite(context, _fechaFinal);
                if (seleccion != null) setState(() => _fechaFinal = seleccion);
              },
            ),
          ),
          if (_fechaFinal != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _fechaFinal = null),
                child: const Text('Quitar fecha límite'),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            _activo ? 'En Inicio: $vista' : 'Pausado: no se muestra. $vista',
            style: TextStyle(color: Colors.grey.shade700, height: 1.3),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: globals.colorFondo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.campaign),
            label: Text(
              widget.anuncioId == null ? 'Publicar anuncio' : 'Guardar cambios',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
