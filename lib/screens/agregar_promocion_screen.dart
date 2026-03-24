import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; 
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:angostura_digital/globals.dart' as globals;

class AgregarPromocionScreen extends StatefulWidget {
  final String negocioId;
  final String nombreNegocio;
  // --- AGREGAMOS ESTO PARA SABER SI VAMOS A EDITAR ---
  final String? promoId; 
  final Map<String, dynamic>? promoData;

  const AgregarPromocionScreen({
    super.key, 
    required this.negocioId, 
    required this.nombreNegocio,
    this.promoId,
    this.promoData,
  });

  @override
  State<AgregarPromocionScreen> createState() => _AgregarPromocionScreenState();
}

class _AgregarPromocionScreenState extends State<AgregarPromocionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _tituloCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _precioNormalCtrl;
  late TextEditingController _precioPromoCtrl; 
  
  DateTime? _fechaFinal; // --- NUEVA VARIABLE PARA LA FECHA ---
  String? _fotoUrlExistente;
  Uint8List? _imagenBytes; 
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Si traemos datos (es decir, estamos EDITANDO), llenamos los campos
    _tituloCtrl = TextEditingController(text: widget.promoData?['titulo'] ?? '');
    _descCtrl = TextEditingController(text: widget.promoData?['descripcion'] ?? '');
    _precioNormalCtrl = TextEditingController(text: widget.promoData?['precio_normal']?.toString() ?? '');
    _precioPromoCtrl = TextEditingController(text: widget.promoData?['precio_promo']?.toString() ?? '');
    _fotoUrlExistente = widget.promoData?['foto_url'];
    
    if (widget.promoData?['fecha_final'] != null) {
      _fechaFinal = (widget.promoData!['fecha_final'] as Timestamp).toDate();
    }
  }

  Future<void> _seleccionarYRecortarImagen(ImageSource source) async {
    final XFile? seleccion = await _picker.pickImage(source: source, imageQuality: 70);
    if (seleccion == null) return;

    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: seleccion.path,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9), 
      compressFormat: ImageCompressFormat.jpg, compressQuality: 50, maxWidth: 800, maxHeight: 800,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Recortar Promo', toolbarColor: Colors.blueAccent, toolbarWidgetColor: Colors.white, initAspectRatio: CropAspectRatioPreset.ratio16x9, lockAspectRatio: true),
        IOSUiSettings(title: 'Recortar Promo', aspectRatioLockEnabled: true),
        WebUiSettings(context: context, presentStyle: WebPresentStyle.dialog),
      ],
    );

    if (croppedFile != null) {
      final bytes = await croppedFile.readAsBytes();
      setState(() { _imagenBytes = bytes; _fotoUrlExistente = null; });
    }
  }

  void _mostrarOpcionesImagen() {
    showModalBottomSheet(context: context, builder: (context) => SafeArea(child: Wrap(children: [ListTile(leading: const Icon(Icons.photo_library), title: const Text('Subir desde Galería'), onTap: () { Navigator.pop(context); _seleccionarYRecortarImagen(ImageSource.gallery); }), if (!kIsWeb) ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Tomar Foto'), onTap: () { Navigator.pop(context); _seleccionarYRecortarImagen(ImageSource.camera); })])));
  }

  Future<void> _guardarPromocion() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imagenBytes == null && _fotoUrlExistente == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega una foto llamativa para tu promoción', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange));
      return;
    }
    if (_fechaFinal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecciona hasta cuándo es válida la oferta', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);

    try {
      String fotoFinal = _fotoUrlExistente ?? '';
      
      if (_imagenBytes != null) {
        final fileName = 'promociones/${widget.negocioId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child(fileName);
        final uploadTask = ref.putData(_imagenBytes!, SettableMetadata(contentType: 'image/jpeg'));
        fotoFinal = await (await uploadTask).ref.getDownloadURL();
      }

      Map<String, dynamic> datosPromo = {
        'negocio_id': widget.negocioId,
        'nombre_negocio': widget.nombreNegocio,
        'titulo': _tituloCtrl.text.trim(),
        'descripcion': _descCtrl.text.trim(),
        'precio_normal': double.tryParse(_precioNormalCtrl.text.trim()) ?? 0.0,
        'precio_promo': double.tryParse(_precioPromoCtrl.text.trim()) ?? 0.0,
        'foto_url': fotoFinal,
        'fecha_final': Timestamp.fromDate(_fechaFinal!), 
      };

      if (widget.promoId == null) {
        datosPromo['fecha_creacion'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('promociones').add(datosPromo);
      } else {
        await FirebaseFirestore.instance.collection('promociones').doc(widget.promoId).update(datosPromo);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Promoción guardada exitosamente! 🚀'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.promoId == null ? 'Lanzar Promoción' : 'Editar Promoción'), backgroundColor: globals.colorFondo, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _mostrarOpcionesImagen,
                child: Container(
                  height: 200, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade400)),
                  child: _imagenBytes != null 
                    ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_imagenBytes!, fit: BoxFit.cover))
                    : _fotoUrlExistente != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(_fotoUrlExistente!, fit: BoxFit.cover))
                      : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.local_offer, size: 50, color: Colors.redAccent), SizedBox(height: 10), Text('Tocar para agregar foto', style: TextStyle(color: Colors.grey))])
                ),
              ),
              const SizedBox(height: 20),
              
              // --- SELECCIONAR FECHA LÍMITE ---
              Card(
                elevation: 0, color: Colors.red.shade50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.red.shade200)),
                child: ListTile(
                  leading: const Icon(Icons.event_busy, color: Colors.redAccent),
                  title: Text(_fechaFinal == null ? '¿Hasta cuándo es válida?' : 'Válida hasta: ${_fechaFinal!.day}/${_fechaFinal!.month}/${_fechaFinal!.year}', style: TextStyle(fontWeight: FontWeight.bold, color: _fechaFinal == null ? Colors.redAccent : Colors.red.shade900)),
                  trailing: const Icon(Icons.edit_calendar, color: Colors.redAccent),
                  onTap: () async {
                    final seleccion = await showDatePicker(context: context, initialDate: _fechaFinal ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (seleccion != null) setState(() => _fechaFinal = seleccion);
                  },
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(controller: _tituloCtrl, decoration: const InputDecoration(labelText: '¿Qué ofreces? (Ej. Combo Hamburguesa)', border: OutlineInputBorder()), validator: (val) => val!.isEmpty ? 'Requerido' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Detalles (Ej. Incluye refresco y papas)', border: OutlineInputBorder())),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _precioNormalCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Precio Normal (\$)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.money_off, color: Colors.grey)), validator: (val) => val!.isEmpty ? 'Requerido' : null)),
                  const SizedBox(width: 15),
                  Expanded(child: TextFormField(controller: _precioPromoCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Precio Oferta (\$)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money, color: Colors.green)), validator: (val) => val!.isEmpty ? 'Requerido' : null)),
                ],
              ),
              const SizedBox(height: 30),
              if (_isLoading) const Center(child: CircularProgressIndicator()) else ElevatedButton.icon(style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.redAccent, foregroundColor: Colors.white), onPressed: _guardarPromocion, icon: const Icon(Icons.campaign), label: Text(widget.promoId == null ? 'Publicar Promoción' : 'Guardar Cambios', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ),
    );
  }
}