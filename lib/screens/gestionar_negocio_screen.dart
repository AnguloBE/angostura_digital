import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/screens/agregar_producto_screen.dart';

class GestionarNegocioScreen extends StatefulWidget {
  final String negocioId;
  final String nombreActual;
  final String categoria;
  final String estadoActual;
  final String? fotoUrlActual;

  const GestionarNegocioScreen({
    super.key,
    required this.negocioId,
    required this.nombreActual,
    required this.categoria,
    required this.estadoActual,
    this.fotoUrlActual,
  });

  @override
  State<GestionarNegocioScreen> createState() => _GestionarNegocioScreenState();
}

class _GestionarNegocioScreenState extends State<GestionarNegocioScreen> {
  late TextEditingController _nombreCtrl;
  bool _isLoading = false;
  Uint8List? _nuevaImagenBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.nombreActual);
  }

  // --- SUBIR FOTO DEL NEGOCIO ---
  Future<void> _cambiarFoto() async {
    if (widget.estadoActual == 'rechazado') return; // Bloqueado si está rechazado

    final XFile? seleccion = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 800);
    if (seleccion != null) {
      final bytes = await seleccion.readAsBytes();
      setState(() {
        _nuevaImagenBytes = bytes;
        _isLoading = true;
      });

      try {
        final String fileName = 'negocios/${widget.negocioId}.jpg';
        final Reference ref = FirebaseStorage.instance.ref().child(fileName);
        final UploadTask uploadTask = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        final TaskSnapshot snapshot = await uploadTask;
        final String fotoUrl = await snapshot.ref.getDownloadURL();

        await FirebaseFirestore.instance.collection('negocios').doc(widget.negocioId).update({'foto_url': fotoUrl});
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto actualizada')));
      } catch (e) {
        print("Error subiendo foto: $e");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- GUARDAR NOMBRE ---
  Future<void> _guardarNombre() async {
    if (_nombreCtrl.text.trim().isEmpty || widget.estadoActual == 'rechazado') return;
    setState(() => _isLoading = true);
    await FirebaseFirestore.instance.collection('negocios').doc(widget.negocioId).update({
      'nombre': _nombreCtrl.text.trim(),
    });
    setState(() => _isLoading = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nombre actualizado')));
  }

  // --- ELIMINAR NEGOCIO ---
  Future<void> _eliminarNegocio() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Negocio'),
        content: const Text('¿Estás seguro? Se borrará el negocio y no aparecerá más en la app. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Eliminar', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );

    if (confirmar == true) {
      // 1. Borramos el negocio
      await FirebaseFirestore.instance.collection('negocios').doc(widget.negocioId).delete();
      
      // 2. Opcional: Borrar los productos de este negocio para no dejar basura
      final productos = await FirebaseFirestore.instance.collection('productos').where('negocio_id', isEqualTo: widget.negocioId).get();
      for (var doc in productos.docs) {
        await doc.reference.delete();
      }

      if (mounted) {
        Navigator.pop(context); // Regresamos al drawer
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Negocio eliminado'), backgroundColor: Colors.red));
      }
    }
  }

  // --- ELIMINAR UN PRODUCTO ---
  Future<void> _eliminarProducto(String productoId) async {
    await FirebaseFirestore.instance.collection('productos').doc(productoId).delete();
  }

  @override
  Widget build(BuildContext context) {
    final bool isRechazado = widget.estadoActual == 'rechazado';
    final bool isPendiente = widget.estadoActual == 'pendiente';
    final bool isAprobado = widget.estadoActual == 'aprobado';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Negocio'),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onPressed: _eliminarNegocio,
            tooltip: 'Eliminar negocio',
          )
        ],
      ),
      body: Column(
        children: [
          // --- ESTADO DEL NEGOCIO ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: isRechazado ? Colors.red.shade100 : (isPendiente ? Colors.orange.shade100 : Colors.green.shade100),
            child: Text(
              isRechazado ? '🚨 NEGOCIO RECHAZADO: No puedes hacer modificaciones.' :
              (isPendiente ? '⏳ EN REVISIÓN: No puedes agregar productos hasta ser aprobado.' :
              '✅ APROBADO: Tu negocio es visible en la app.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isRechazado ? Colors.red.shade800 : (isPendiente ? Colors.orange.shade800 : Colors.green.shade800),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECCIÓN PERFIL DEL NEGOCIO ---
                  Row(
                    children: [
                      GestureDetector(
                        onTap: isRechazado ? null : _cambiarFoto,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage: _nuevaImagenBytes != null 
                                  ? MemoryImage(_nuevaImagenBytes!) 
                                  : (widget.fotoUrlActual != null ? NetworkImage(widget.fotoUrlActual!) : null) as ImageProvider?,
                              child: (_nuevaImagenBytes == null && widget.fotoUrlActual == null) 
                                  ? const Icon(Icons.store, size: 40, color: Colors.grey) : null,
                            ),
                            if (!isRechazado)
                              const CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.blueAccent,
                                child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _nombreCtrl,
                          enabled: !isRechazado,
                          decoration: const InputDecoration(labelText: 'Nombre del Negocio'),
                        ),
                      ),
                      if (!isRechazado)
                        IconButton(
                          icon: _isLoading ? const CircularProgressIndicator() : const Icon(Icons.save, color: Colors.green),
                          onPressed: _guardarNombre,
                        )
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),

                  // --- SECCIÓN PRODUCTOS ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Catálogo / Productos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (isAprobado) // SOLO SE MUESTRA SI ESTÁ APROBADO
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Agregar'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AgregarProductoScreen(
                                  negocioId: widget.negocioId,
                                  categoriaNegocio: widget.categoria,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // --- LISTA DE PRODUCTOS ---
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('productos')
                        .where('negocio_id', isEqualTo: widget.negocioId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      
                      final productos = snapshot.data?.docs ?? [];
                      
                      if (productos.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Center(child: Text('No hay productos registrados aún.', style: TextStyle(color: Colors.grey))),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: productos.length,
                        itemBuilder: (context, index) {
                          final doc = productos[index];
                          final prod = doc.data() as Map<String, dynamic>;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: prod['foto_url'] != null 
                                ? Image.network(prod['foto_url'], width: 50, height: 50, fit: BoxFit.cover) 
                                : const Icon(Icons.image_not_supported),
                              title: Text(prod['nombre'] ?? 'Sin nombre'),
                              subtitle: Text('\$${prod['precio']}'),
                              trailing: isRechazado ? null : IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _eliminarProducto(doc.id),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}