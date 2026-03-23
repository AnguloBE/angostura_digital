import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:angostura_digital/globals.dart' as globals;

class AdminZonasScreen extends StatelessWidget {
  const AdminZonasScreen({super.key});

  // Mostrar un cuadrito para escribir la nueva zona
  void _mostrarDialogoAgregar(BuildContext context) {
    final TextEditingController zonaCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar Nueva Zona'),
        content: TextField(
          controller: zonaCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre de la zona',
            hintText: 'Ej. Alhuey',
            border: OutlineInputBorder()
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            onPressed: () async {
              if (zonaCtrl.text.trim().isNotEmpty) {
                // Guardamos la nueva zona en Firebase
                await FirebaseFirestore.instance.collection('zonas').add({
                  'nombre': zonaCtrl.text.trim(),
                  'fecha_creacion': FieldValue.serverTimestamp(),
                });
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar'),
          )
        ],
      ),
    );
  }

  // Eliminar zona
  Future<void> _eliminarZona(BuildContext context, String zonaId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Zona'),
        content: const Text('¿Estás seguro? Los negocios ya no podrán seleccionarla.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Eliminar', style: TextStyle(color: Colors.white))
          )
        ],
      ),
    );

    if (confirmar == true) {
      await FirebaseFirestore.instance.collection('zonas').doc(zonaId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar Zonas', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Zona'),
        onPressed: () => _mostrarDialogoAgregar(context),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('zonas').orderBy('nombre').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final zonas = snapshot.data?.docs ?? [];

          if (zonas.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  const Text('No has agregado zonas de entrega.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: zonas.length,
            itemBuilder: (context, index) {
              final doc = zonas[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.location_city, color: Colors.blueAccent),
                  title: Text(data['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _eliminarZona(context, doc.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}