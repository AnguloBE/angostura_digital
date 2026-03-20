import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; 
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:angostura_digital/globals.dart' as globals;

class AgregarProductoScreen extends StatefulWidget {
  final String negocioId;
  final String categoriaNegocio;

  const AgregarProductoScreen({
    super.key, 
    required this.negocioId, 
    required this.categoriaNegocio,
  });

  @override
  State<AgregarProductoScreen> createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _precioCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _ingredientesCtrl = TextEditingController(); 
  final TextEditingController _codigoBarrasCtrl = TextEditingController(); 
  final TextEditingController _gramosCtrl = TextEditingController(); 
  final TextEditingController _tallasCtrl = TextEditingController(); 
  final TextEditingController _coloresCtrl = TextEditingController(); 

  Uint8List? _imagenBytes; 
  final ImagePicker _picker = ImagePicker();

  // --- FUNCIÓN MAESTRA DE SELECCIÓN, RECORTE Y COMPRESIÓN ---
  Future<void> _seleccionarYRecortarImagen(ImageSource source) async {
    // 1. Elegir la foto original
    final XFile? seleccion = await _picker.pickImage(
      source: source,
      imageQuality: 70, 
    );
    
    if (seleccion == null) return;

    // 2. Configurar el recortador
    final cropper = ImageCropper();
    
    // 3. Abrir la interfaz de recorte y aplicar la compresión final
    CroppedFile? croppedFile = await cropper.cropImage(
      sourcePath: seleccion.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // OBLIGAR A CUADRADO 1:1
      compressFormat: ImageCompressFormat.jpg, // Forzamos JPG para menor peso
      compressQuality: 50, // Reduce el peso de la imagen a la mitad
      maxWidth: 600, // Límite de tamaño para no saturar Storage
      maxHeight: 600,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recortar Producto',
          toolbarColor: Colors.blueAccent,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Recortar (1:1)',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
        // Configuración para COMPUTADORA (Web) corregida
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog, 
        ),
      ],
    );

    if (croppedFile != null) {
      final bytes = await croppedFile.readAsBytes();
      setState(() {
        _imagenBytes = bytes;
      });
    }
  }

  void _mostrarOpcionesImagen() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Subir desde Galería / Archivos'),
              onTap: () {
                Navigator.pop(context);
                _seleccionarYRecortarImagen(ImageSource.gallery);
              },
            ),
            if (!kIsWeb) // Ocultamos la cámara si están en PC (Web)
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tomar Foto con Cámara'),
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarYRecortarImagen(ImageSource.camera);
                },
              ),
          ],
        ),
      ),
    );
  }

  // --- GUARDAR EN FIRESTORE Y STORAGE ---
  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imagenBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, agrega una foto del producto')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String fileName = 'productos/${widget.negocioId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = FirebaseStorage.instance.ref().child(fileName);
      
      final UploadTask uploadTask = ref.putData(_imagenBytes!, SettableMetadata(contentType: 'image/jpeg'));
      final TaskSnapshot snapshot = await uploadTask;
      final String fotoUrl = await snapshot.ref.getDownloadURL();

      Map<String, dynamic> datosExtras = {};
      if (widget.categoriaNegocio == 'Restaurante / Comida') {
        datosExtras = {'ingredientes': _ingredientesCtrl.text.trim()};
      } else if (widget.categoriaNegocio == 'Abarrotes y Supermercados') {
        datosExtras = {'codigo_barras': _codigoBarrasCtrl.text.trim(), 'peso_o_contenido': _gramosCtrl.text.trim()};
      } else if (widget.categoriaNegocio == 'Ropa y Accesorios') {
        datosExtras = {'tallas_disponibles': _tallasCtrl.text.trim(), 'colores': _coloresCtrl.text.trim()};
      }

      await FirebaseFirestore.instance.collection('productos').add({
        'negocio_id': widget.negocioId,
        'nombre': _nombreCtrl.text.trim(),
        'precio': double.tryParse(_precioCtrl.text.trim()) ?? 0.0,
        'descripcion': _descCtrl.text.trim(),
        'foto_url': fotoUrl,
        'categoria_negocio': widget.categoriaNegocio,
        'fecha_creacion': FieldValue.serverTimestamp(),
        ...datosExtras,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Producto agregado con éxito!'), backgroundColor: Colors.green));
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
      appBar: AppBar(title: const Text('Agregar Producto'), backgroundColor: globals.colorFondo, foregroundColor: Colors.white),
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
                  height: 250, 
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade400)),
                  child: _imagenBytes == null
                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.add_a_photo, size: 50, color: Colors.grey), SizedBox(height: 10), Text('Tocar para agregar foto', style: TextStyle(color: Colors.grey))])
                      : ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_imagenBytes!, fit: BoxFit.cover)), 
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre del producto', border: OutlineInputBorder()), validator: (val) => val!.isEmpty ? 'Requerido' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _precioCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Precio (\$)', border: OutlineInputBorder()), validator: (val) => val!.isEmpty ? 'Requerido' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Descripción corta', border: OutlineInputBorder())),
              const SizedBox(height: 20),
              
              // Campos dinámicos
              if (widget.categoriaNegocio == 'Restaurante / Comida') ...[ const Divider(), TextFormField(controller: _ingredientesCtrl, decoration: const InputDecoration(labelText: 'Ingredientes (opcional)', border: OutlineInputBorder()))],
              if (widget.categoriaNegocio == 'Abarrotes y Supermercados') ...[ const Divider(), TextFormField(controller: _codigoBarrasCtrl, decoration: const InputDecoration(labelText: 'Código barras (opcional)', border: OutlineInputBorder())), const SizedBox(height: 10), TextFormField(controller: _gramosCtrl, decoration: const InputDecoration(labelText: 'Contenido neto (ej. 500g)', border: OutlineInputBorder()))],
              if (widget.categoriaNegocio == 'Ropa y Accesorios') ...[ const Divider(), TextFormField(controller: _tallasCtrl, decoration: const InputDecoration(labelText: 'Tallas disponibles', border: OutlineInputBorder())), const SizedBox(height: 10), TextFormField(controller: _coloresCtrl, decoration: const InputDecoration(labelText: 'Colores disponibles', border: OutlineInputBorder()))],

              const SizedBox(height: 30),
              if (_isLoading) const Center(child: CircularProgressIndicator()) else ElevatedButton(style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white), onPressed: _guardarProducto, child: const Text('Subir Producto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}