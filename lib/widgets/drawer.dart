import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:angostura_digital/services/firebase_service.dart'; 
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/screens/usuarios_screen.dart'; 
import 'package:angostura_digital/screens/crear_negocio_screen.dart'; 
import 'package:angostura_digital/screens/gestionar_negocio_screen.dart';
import 'package:angostura_digital/screens/revision_negocios_screen.dart'; 
import 'package:angostura_digital/screens/admin_zonas_screen.dart';
import 'package:angostura_digital/screens/login_screen.dart'; // Para redirigir al salir

class DrawerPrincipal extends StatefulWidget {
  const DrawerPrincipal({super.key});

  @override
  State<DrawerPrincipal> createState() => _DrawerPrincipalState();
}

class _DrawerPrincipalState extends State<DrawerPrincipal> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isCerrandoSesion = false;

  // --- FUNCIÓN PARA EDITAR EL NOMBRE ---
  Future<void> _editarNombre() async {
    if (user == null) return;

    final TextEditingController nombreCtrl = TextEditingController(text: user!.displayName);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: nombreCtrl,
            decoration: const InputDecoration(
              labelText: 'Tu Nombre',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              onPressed: () async {
                final nuevoNombre = nombreCtrl.text.trim();
                if (nuevoNombre.isNotEmpty) {
                  // Actualizamos en Firebase Auth
                  await user!.updateDisplayName(nuevoNombre);
                  
                  // Actualizamos en Firestore
                  await FirebaseFirestore.instance.collection('usuarios').doc(user!.uid).set({
                    'nombre': nuevoNombre,
                  }, SetOptions(merge: true));

                  // Refrescamos la UI del Drawer
                  setState(() {});
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Perfil actualizado con éxito'), backgroundColor: Colors.green)
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  // --- FUNCIÓN PARA CERRAR SESIÓN ---
  Future<void> _cerrarSesion() async {
    setState(() => _isCerrandoSesion = true);
    try {
      await AuthService().signOut();
      if (mounted) {
        // Cierra el Drawer y manda al usuario al Login borrando el historial de navegación
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()), 
          (route) => false
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCerrandoSesion = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e'), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // HEADER INTERACTIVO (Tocar para editar perfil)
          InkWell(
            onTap: _editarNombre,
            child: UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: globals.colorFondo),
              accountName: Row(
                children: [
                  Text(user?.displayName ?? 'Usuario', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(width: 8),
                  const Icon(Icons.edit, color: Colors.white70, size: 16),
                ],
              ),
              accountEmail: Text(user?.phoneNumber ?? user?.email ?? 'Sin contacto'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.grey),
              ),
              margin: EdgeInsets.zero, // Quita el margen inferior por defecto para pegarlo a la lista
            ),
          ),

          // LISTA DE OPCIONES DINÁMICAS
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
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
                              _buildSectionTitle('MIS NEGOCIOS'),
                              
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('negocios')
                                    .where('propietario_uid', isEqualTo: user!.uid)
                                    .snapshots(),
                                builder: (context, negociosSnap) {
                                  if (negociosSnap.connectionState == ConnectionState.waiting) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    );
                                  }

                                  final negocios = negociosSnap.data?.docs ?? [];

                                  if (negocios.isEmpty) {
                                    return const ListTile(
                                      leading: Icon(Icons.store_outlined, color: Colors.grey),
                                      title: Text('No tienes negocios', style: TextStyle(color: Colors.grey)),
                                    );
                                  }

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
                                          Navigator.pop(context); 
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

                              ListTile(
                                leading: const Icon(Icons.add_business, color: Colors.green),
                                title: const Text('Registrar nuevo negocio'),
                                onTap: () {
                                  Navigator.pop(context); 
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CrearNegocioScreen()));
                                },
                              ),
                            ],

                            // --- ZONA ADMIN ---
                            if (rol == 'admin') ...[
                              const Divider(),
                              _buildSectionTitle('ADMINISTRACIÓN GENERAL'),
                              ListTile(
                                leading: const Icon(Icons.people, color: Colors.blueAccent),
                                title: const Text('Gestión de Usuarios'),
                                onTap: () {
                                  Navigator.pop(context); 
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UsuariosScreen()));
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.fact_check, color: Colors.orange),
                                title: const Text('Revisar Negocios'),
                                onTap: () {
                                  Navigator.pop(context); 
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RevisionNegociosScreen()));
                                },
                              ),
                              
                              const SizedBox(height: 10),
                              
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.blue.shade100),
                                ),
                                child: ListTile(
                                  leading: const Icon(Icons.map, color: Colors.blueAccent),
                                  title: Text('Zonas de Entrega', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                                  subtitle: const Text('Configurar pueblos (Angostura, Alhuey...)', style: TextStyle(fontSize: 12)),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blueAccent),
                                  onTap: () {
                                    Navigator.pop(context); 
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminZonasScreen()));
                                  },
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        );
                      }
                      return const SizedBox.shrink(); 
                    },
                  ),
              ],
            ),
          ),
          
          // BOTTOM - LOGOUT
          const Divider(height: 1), 
          ListTile(
            leading: _isCerrandoSesion 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2))
              : const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: _isCerrandoSesion ? null : _cerrarSesion,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }
}