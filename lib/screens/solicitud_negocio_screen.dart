import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/widgets/editar_telefono_dialog.dart';

/// Formulario de "quiero poner mi negocio aquí".
/// Guarda nombre, descripción y el teléfono de quien ya inició sesión.
class SolicitudNegocioScreen extends StatefulWidget {
  const SolicitudNegocioScreen({super.key});

  @override
  State<SolicitudNegocioScreen> createState() => _SolicitudNegocioScreenState();
}

class _SolicitudNegocioScreenState extends State<SolicitudNegocioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _mias;
  bool _perfilListo = false;
  bool _enviando = false;
  String _telefono = '';
  String _nombreCliente = '';

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _mias = FirebaseFirestore.instance
        .collection('solicitudes_negocio')
        .where('cliente_id', isEqualTo: uid)
        .snapshots();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _perfilListo = true);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      final data = doc.data();
      if (!mounted) return;
      setState(() {
        _telefono = (data?['telefono'] ?? user.phoneNumber ?? '').toString().trim();
        _nombreCliente = (data?['nombre'] ?? user.displayName ?? '').toString().trim();
        _perfilListo = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _telefono = FirebaseAuth.instance.currentUser?.phoneNumber?.trim() ?? '';
        _perfilListo = true;
      });
    }
  }

  Future<void> _pedirTelefono() async {
    final ok = await EditarTelefonoDialog.mostrar(context);
    if (ok) await _cargarPerfil();
  }

  Future<void> _enviar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      _aviso('Entra con tu teléfono para enviar la solicitud.', Colors.orange);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_telefono.isEmpty) {
      _aviso('Necesitamos tu número para ubicar la solicitud.', Colors.orange);
      return;
    }

    setState(() => _enviando = true);
    try {
      final previas = await FirebaseFirestore.instance
          .collection('solicitudes_negocio')
          .where('cliente_id', isEqualTo: user.uid)
          .get();
      final ya = previas.docs.any((d) => (d.data()['estado'] ?? 'pendiente') == 'pendiente');
      if (ya) {
        if (mounted) _aviso('Ya tienes una solicitud en revisión.', Colors.orange);
        return;
      }

      await FirebaseFirestore.instance.collection('solicitudes_negocio').add({
        'nombre': _nombreCtrl.text.trim(),
        'descripcion': _descCtrl.text.trim(),
        'cliente_id': user.uid,
        'cliente_nombre': _nombreCliente,
        'telefono': _telefono,
        'estado': 'pendiente',
        'fecha': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _aviso('Solicitud enviada. La revisamos pronto.', Colors.green);
      }
    } catch (e) {
      if (mounted) _aviso('No se pudo enviar: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _cancelar(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar solicitud'),
        content: const Text('Si la cancelas, puedes enviar otra después.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar solicitud'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance.collection('solicitudes_negocio').doc(id).update({
        'estado': 'cancelada',
        'fecha_respuesta': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) _aviso('No se pudo cancelar: $e', Colors.red);
    }
  }

  void _aviso(String texto, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiero poner mi negocio'),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      body: user == null || user.isAnonymous
          ? const Center(child: Text('Entra con tu teléfono para continuar.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _mias,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                QueryDocumentSnapshot<Map<String, dynamic>>? pendiente;
                var huboRechazo = false;
                for (final doc in docs) {
                  final estado = (doc.data()['estado'] ?? 'pendiente').toString();
                  if (estado == 'pendiente') pendiente = doc;
                  if (estado == 'rechazada') huboRechazo = true;
                }
                if (pendiente != null) return _yaEnviada(pendiente);
                return _formulario(huboRechazo);
              },
            ),
    );
  }

  Widget _yaEnviada(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 64, color: Colors.teal),
        const SizedBox(height: 12),
        const Text(
          'Ya recibimos tu solicitud',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'La revisamos y, si procede, damos de alta el negocio. No es inmediato.',
          style: TextStyle(height: 1.35, color: Colors.black87),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['nombre']?.toString() ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(data['descripcion']?.toString() ?? '', style: const TextStyle(height: 1.3)),
                const SizedBox(height: 10),
                Text('Número: ${data['telefono'] ?? _telefono}', style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _cancelar(doc.id),
          child: const Text('Cancelar esta solicitud'),
        ),
      ],
    );
  }

  Widget _formulario(bool huboRechazo) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Deja el nombre del negocio y qué es. Lo revisamos con tu número y, si encaja, lo creamos.',
          style: TextStyle(height: 1.35),
        ),
        if (huboRechazo) ...[
          const SizedBox(height: 10),
          Text(
            'La solicitud anterior no procedió. Puedes enviar otra.',
            style: TextStyle(color: Colors.orange.shade800, height: 1.3),
          ),
        ],
        const SizedBox(height: 16),
        if (!_perfilListo)
          const LinearProgressIndicator()
        else if (_telefono.isEmpty)
          Card(
            color: Colors.orange.shade50,
            child: ListTile(
              leading: const Icon(Icons.phone_android, color: Colors.orange),
              title: const Text('Falta tu número'),
              subtitle: const Text('Entra con tu teléfono para ligar la solicitud.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pedirTelefono,
            ),
          )
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.phone_outlined, color: Colors.teal),
            title: Text(_telefono, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Con este número te ubicamos. No hace falta escribirlo.'),
          ),
        const SizedBox(height: 8),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre del negocio',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe el nombre' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Qué es',
                  hintText: 'Por ejemplo: taquería, farmacia, estética…',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Cuéntanos qué es' : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: (_enviando || !_perfilListo) ? null : (_telefono.isEmpty ? _pedirTelefono : _enviar),
          icon: _enviando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(_telefono.isEmpty ? Icons.phone_android : Icons.send),
          label: Text(
            _telefono.isEmpty ? 'Agregar mi teléfono' : 'Enviar solicitud',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
