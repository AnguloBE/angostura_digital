import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/utils/mobile_image_utils.dart';
import 'package:angostura_digital/widgets/square_image.dart';

/// Alta/edición de un servicio (cita con calendario o solicitud a domicilio).
class AgregarServicioScreen extends StatefulWidget {
  final String negocioId;
  final String? servicioId;
  final Map<String, dynamic>? servicioData;

  const AgregarServicioScreen({
    super.key,
    required this.negocioId,
    this.servicioId,
    this.servicioData,
  });

  @override
  State<AgregarServicioScreen> createState() => _AgregarServicioScreenState();
}

class _AgregarServicioScreenState extends State<AgregarServicioScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _nombreCtrl;
  late TextEditingController _precioCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _duracionCtrl;

  String? _fotoUrlExistente;
  Uint8List? _imagenBytes;

  /// 'cita' = con calendario; 'solicitud' = el negocio contacta después.
  String _tipoServicio = 'cita';

  @override
  void initState() {
    super.initState();
    final d = widget.servicioData;
    _nombreCtrl = TextEditingController(text: d?['nombre'] ?? '');
    _precioCtrl = TextEditingController(text: d?['precio']?.toString() ?? '');
    _descCtrl = TextEditingController(text: d?['descripcion'] ?? '');
    _duracionCtrl = TextEditingController(
      text: (d?['duracion_minutos'] ?? 30).toString(),
    );
    _fotoUrlExistente = d?['foto_url'];
    _tipoServicio = d?['tipo_servicio']?.toString() ?? 'cita';
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _descCtrl.dispose();
    _duracionCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFoto(ImageSource source) async {
    final bytes = await MobileImageUtils.pickCropAndReadBytes(
      context: context,
      source: source,
      cropTitle: 'Foto del servicio',
    );
    if (bytes != null) setState(() => _imagenBytes = bytes);
  }

  Future<String?> _subirFoto() async {
    if (_imagenBytes == null) return _fotoUrlExistente;
    final ref = FirebaseStorage.instance.ref().child(
      'servicios/${widget.negocioId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await ref.putData(_imagenBytes!, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final foto = await _subirFoto();
      final duracion = int.tryParse(_duracionCtrl.text.trim()) ?? 30;

      final datos = <String, dynamic>{
        'negocio_id': widget.negocioId,
        'nombre': _nombreCtrl.text.trim(),
        'precio': double.tryParse(_precioCtrl.text.trim()) ?? 0,
        'descripcion': _descCtrl.text.trim(),
        'foto_url': foto ?? '',
        'es_servicio': true,
        'tipo_servicio': _tipoServicio,
        'duracion_minutos': _tipoServicio == 'cita' ? duracion : 0,
        'categoria_negocio': 'Servicios',
      };

      if (widget.servicioId == null) {
        datos['fecha_creacion'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('productos').add(datos);
      } else {
        await FirebaseFirestore.instance
            .collection('productos')
            .doc(widget.servicioId)
            .update(datos);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servicio guardado'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.servicioId == null ? 'Agregar servicio' : 'Editar servicio'),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GestureDetector(
              onTap: () => MobileImageUtils.showImageSourcePicker(
                context,
                onSelected: _elegirFoto,
              ),
              child: SquarePhotoPicker(
                imageUrl: _fotoUrlExistente,
                imageBytes: _imagenBytes,
                emptyChild: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Tocar para foto', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del servicio',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Escribe el nombre' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _precioCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Precio (\$)',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
              validator: (v) =>
                  (double.tryParse((v ?? '').trim()) ?? 0) <= 0
                      ? 'Precio inválido'
                      : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tipo de servicio',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: const Text('Con cita (calendario)'),
              subtitle: const Text(
                'Ej. corte de pelo, uñas, maquillaje. El cliente elige día y hora.',
              ),
              value: 'cita',
              groupValue: _tipoServicio,
              onChanged: (v) => setState(() => _tipoServicio = v!),
            ),
            RadioListTile<String>(
              title: const Text('Solicitud a domicilio'),
              subtitle: const Text(
                'Ej. aire acondicionado, plomería. Sin calendario; tú contactas al cliente.',
              ),
              value: 'solicitud',
              groupValue: _tipoServicio,
              onChanged: (v) => setState(() => _tipoServicio = v!),
            ),
            if (_tipoServicio == 'cita') ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _duracionCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duración de la cita (minutos)',
                  hintText: 'Ej. 30, 45, 60',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isLoading ? null : _guardar,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.servicioId == null ? 'Guardar servicio' : 'Actualizar',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
