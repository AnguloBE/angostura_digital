import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:angostura_digital/globals.dart' as globals;

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  String _searchQuery = "";

  // Función para abrir la ventana de edición
  void _editarUsuario(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    TextEditingController nombreController = TextEditingController(text: data['nombre'] ?? '');
    String rolSeleccionado = data['rol'] ?? 'cliente';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Editar Usuario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: rolSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Rol del usuario',
                  border: OutlineInputBorder(),
                ),
                items: ['admin', 'vendedor', 'cliente'].map((rol) {
                  return DropdownMenuItem(
                    value: rol,
                    child: Text(rol.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    rolSeleccionado = val!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final nuevoNombre = nombreController.text.trim();
                if (nuevoNombre.isNotEmpty) {
                  // Actualizamos el documento en Firestore
                  await FirebaseFirestore.instance.collection('usuarios').doc(doc.id).update({
                    'nombre': nuevoNombre,
                    'rol': rolSeleccionado,
                  });
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext); // Cerramos el diálogo
                  }
                }
              },
              child: const Text('Guardar Cambios'),
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
        title: const Text('Gestión de Usuarios'),
        centerTitle: true,
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white, // Para que la flecha de regreso y el texto sean blancos
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre o teléfono...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          
          // Lista de usuarios en tiempo real
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No hay usuarios registrados.'));
                }

                // Filtramos la lista localmente basándonos en el buscador
                final usuarios = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                  final telefono = (data['telefono'] ?? '').toString().toLowerCase();
                  return nombre.contains(_searchQuery) || telefono.contains(_searchQuery);
                }).toList();

                if (usuarios.isEmpty) {
                  return const Center(child: Text('No se encontraron coincidencias.'));
                }

                return ListView.builder(
                  itemCount: usuarios.length,
                  itemBuilder: (context, index) {
                    final doc = usuarios[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isAdmin = data['rol'] == 'admin';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isAdmin ? Colors.blueAccent : Colors.grey.shade300,
                          child: Icon(
                            isAdmin ? Icons.admin_panel_settings : Icons.person,
                            color: isAdmin ? Colors.white : Colors.black54,
                          ),
                        ),
                        title: Text(
                          data['nombre'] ?? 'Sin nombre',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${data['telefono']} \nRol: ${data['rol']}'),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blueGrey),
                          onPressed: () => _editarUsuario(doc),
                          tooltip: 'Editar usuario',
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