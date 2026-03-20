import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:angostura_digital/services/firebase_service.dart'; 
import 'package:angostura_digital/globals.dart' as globals;
// Asegúrate de importar la pantalla que acabamos de crear:
import 'package:angostura_digital/screens/usuarios_screen.dart'; 
import 'package:angostura_digital/screens/crear_negocio_screen.dart'; // Ajusta la ruta si es necesario
import 'package:angostura_digital/screens/gestionar_negocio_screen.dart';
import 'package:angostura_digital/screens/revision_negocios_screen.dart'; // Ajusta la ruta si es necesario


class DrawerPrincipal extends StatefulWidget {
  const DrawerPrincipal({super.key});

  @override
  State<DrawerPrincipal> createState() => _DrawerPrincipalState();
}

class _DrawerPrincipalState extends State<DrawerPrincipal> {
  User? get user => FirebaseAuth.instance.currentUser;

  Future<void> _editarNombre() async {
    if (user == null) return;
    
    TextEditingController nameController = TextEditingController(
      text: user!.displayName ?? '',
    );

    await showDialog(
      context: context,
      builder: (dialogContext) { 
        return AlertDialog(
          title: const Text('Editar nombre'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: 'Ingresa tu nombre o apodo',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
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
                final nuevoNombre = nameController.text.trim();
                if (nuevoNombre.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                  }

                  await user!.updateDisplayName(nuevoNombre);
                  
                  await FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(user!.uid)
                      .update({'nombre': nuevoNombre});
                      
                  await user!.reload();
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: globals.colorFondo,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        user?.displayName ?? 'Usuario sin nombre',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis, 
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white, size: 24),
                      onPressed: _editarNombre,
                      tooltip: 'Editar nombre de usuario',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user?.phoneNumber ?? user?.email ?? 'Sin información de contacto',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.campaign),
            title: const Text('Ofertas'),
            onTap: () {
              Navigator.pop(context); 
            },
          ),
          ListTile(
            leading: const Icon(Icons.fastfood),
            title: const Text('Restaurantes'),
            onTap: () {},
          ),
          
          // --- AQUÍ EMPIEZA LA MAGIA DE LOS ROLES ---
          if (user != null)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('usuarios').doc(user!.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final rol = data['rol'] ?? 'cliente';
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- ZONA VENDEDOR ---
                      if (rol == 'admin' || rol == 'vendedor') ...[
                        const Divider(),
                        const Padding(
                          padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
                          child: Text(
                            'MIS NEGOCIOS',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        // Consultamos la colección 'negocios' buscando los de este usuario
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('negocios')
                              .where('propietario_uid', isEqualTo: user!.uid) // Filtro clave
                              .snapshots(),
                          builder: (context, negociosSnap) {
                            if (negociosSnap.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            }

                            final negocios = negociosSnap.data?.docs ?? [];

                            // Si no tiene negocios registrados
                            if (negocios.isEmpty) {
                              return const ListTile(
                                leading: Icon(Icons.store_outlined, color: Colors.grey),
                                title: Text('No tienes negocios', style: TextStyle(color: Colors.grey)),
                              );
                            }

                            // Si tiene negocios, los listamos todos
                            return Column(
                              children: negocios.map((doc) {
                                final negocio = doc.data() as Map<String, dynamic>;
                                return ListTile(
                                  leading: const Icon(Icons.storefront, color: Colors.orange),
                                  title: Text(negocio['nombre'] ?? 'Sin nombre'),
                                  subtitle: Text(negocio['estado']?.toString().toUpperCase() ?? 'DESCONOCIDO', 
                                    style: TextStyle(
                                      color: negocio['estado'] == 'aprobado' ? Colors.green 
                                           : (negocio['estado'] == 'rechazado' ? Colors.red : Colors.orange),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11
                                    )
                                  ),
                                  trailing: const Icon(Icons.settings, color: Colors.blueGrey), 
                                  onTap: () {
                                    Navigator.pop(context); // Cerramos el menú lateral
                                    
                                    // Abrimos el Panel de Gestión del Negocio
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => GestionarNegocioScreen(
                                          negocioId: doc.id,
                                          nombreActual: negocio['nombre'] ?? '',
                                          categoria: negocio['categoria'] ?? 'Otro',
                                          estadoActual: negocio['estado'] ?? 'pendiente',
                                          fotoUrlActual: negocio['foto_url'],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            );
                          },
                        ),

                        // Botón para que el vendedor registre un local nuevo
                        ListTile(
                          leading: const Icon(Icons.add_business, color: Colors.green),
                          title: const Text('Agregar nuevo negocio'),
                          onTap: () {
                            Navigator.pop(context); // Cierra el Drawer
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CrearNegocioScreen()),
                            );
                          },
                        ),
                      ],

                      // --- ZONA ADMINISTRACIÓN (Solo tú) ---
                      if (rol == 'admin') ...[
                        const Divider(),
                        const Padding(
                          padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
                          child: Text(
                            'ADMINISTRACIÓN GENERAL',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.people, color: Colors.blueAccent),
                          title: const Text('Gestión de Usuarios'),
                          onTap: () {
                            Navigator.pop(context); 
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const UsuariosScreen()),
                            );
                          },
                        ),
                        // ---- NUEVO BOTÓN ----
                        ListTile(
                          leading: const Icon(Icons.fact_check, color: Colors.orange),
                          title: const Text('Revisar Negocios'),
                          onTap: () {
                            Navigator.pop(context); 
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const RevisionNegociosScreen()),
                            );
                          },
                        ),
                      ],
                    ],
                  );
                }
                return const SizedBox.shrink(); 
              },
            ),
          // --- FIN DE LA ZONA RESTRINGIDA ---

          const Divider(), 
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              await AuthService().signOut();
            },
          )
        ],
      ),
    );
  }
}