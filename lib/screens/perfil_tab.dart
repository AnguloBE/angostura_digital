import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/services/firebase_service.dart'; // Para el logout

class PerfilTab extends StatelessWidget {
  const PerfilTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          Container(
            color: globals.colorFondo,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 60, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.displayName ?? 'Usuario',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  user?.phoneNumber ?? user?.email ?? 'Sin contacto',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.location_on, color: Colors.blueAccent),
            title: const Text('Mis Direcciones'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.payment, color: Colors.green),
            title: const Text('Métodos de Pago'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help_outline, color: Colors.orange),
            title: const Text('Soporte y Ayuda'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () async {
              // Lógica para cerrar sesión
            },
          ),
        ],
      ),
    );
  }
}