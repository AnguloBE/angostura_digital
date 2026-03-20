import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:angostura_digital/globals.dart' as globals;

class RevisionNegociosScreen extends StatelessWidget {
  const RevisionNegociosScreen({super.key});

  // Función para cambiar el estado del negocio en Firebase
  Future<void> _cambiarEstado(BuildContext context, String docId, String nuevoEstado) async {
    try {
      await FirebaseFirestore.instance.collection('negocios').doc(docId).update({
        'estado': nuevoEstado,
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nuevoEstado == 'aprobado' 
                ? '¡Negocio aprobado y publicado!' 
                : 'Negocio rechazado.'),
            backgroundColor: nuevoEstado == 'aprobado' ? Colors.green : Colors.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Cuadro de confirmación para no rechazar por accidente
  Future<void> _confirmarRechazo(BuildContext context, String docId, String nombreNegocio) async {
    return showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('¿Rechazar negocio?'),
          content: Text('¿Estás seguro de que deseas rechazar "$nombreNegocio"? No aparecerá en la app.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(dialogContext); // Cierra el diálogo
                _cambiarEstado(context, docId, 'rechazado');
              },
              child: const Text('Sí, rechazar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisión de Negocios'),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // El filtro maestro: Solo traemos los pendientes
        stream: FirebaseFirestore.instance
            .collection('negocios')
            .where('estado', isEqualTo: 'pendiente')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                  SizedBox(height: 16),
                  Text('¡Todo al día!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('No hay negocios pendientes de revisión.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final pendientes = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: pendientes.length,
            itemBuilder: (context, index) {
              final doc = pendientes[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.store, color: Colors.blueGrey, size: 30),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              data['nombre'] ?? 'Sin nombre',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Pendiente', style: TextStyle(color: Colors.deepOrange, fontSize: 12)),
                          )
                        ],
                      ),
                      const Divider(),
                      Text('Categoría: ${data['categoria']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('Descripción:', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                      Text(data['descripcion'] ?? 'Sin descripción'),
                      const SizedBox(height: 16),
                      
                      // Botones de acción
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                              icon: const Icon(Icons.close),
                              label: const Text('Rechazar'),
                              onPressed: () => _confirmarRechazo(context, doc.id, data['nombre'] ?? ''),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              icon: const Icon(Icons.check),
                              label: const Text('Aprobar'),
                              onPressed: () => _cambiarEstado(context, doc.id, 'aprobado'),
                            ),
                          ),
                        ],
                      )
                    ],
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