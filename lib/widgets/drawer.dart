import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:angostura_digital/services/firebase_service.dart'; 
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/screens/usuarios_screen.dart'; 
import 'package:angostura_digital/screens/crear_negocio_screen.dart'; 
import 'package:angostura_digital/screens/gestionar_negocio_screen.dart';
import 'package:angostura_digital/screens/revision_negocios_screen.dart'; 
// ¡AQUÍ IMPORTAMOS LA NUEVA PANTALLA DE ZONAS!
import 'package:angostura_digital/screens/admin_zonas_screen.dart';

class DrawerPrincipal extends StatelessWidget {
  const DrawerPrincipal({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: Column(
        children: [
          // HEADER SIMPLIFICADO
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: globals.colorFondo),
            accountName: Text(user?.displayName ?? 'Usuario', style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(user?.phoneNumber ?? user?.email ?? 'Sin contacto'),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.grey),
            ),
          ),

          // LISTA DE OPCIONES DINÁMICAS
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (user != null)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('usuarios').doc(user.uid).snapshots(),
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
                              
                              // AQUÍ RECUPERAMOS TUS NEGOCIOS
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('negocios')
                                    .where('propietario_uid', isEqualTo: user.uid)
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
                              
                              // --- ACCESO PERRÓN A ZONAS ---
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
                              // -----------------------------
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
          const Divider(), 
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              await AuthService().signOut(); // Asegúrate de que este método exista
            },
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