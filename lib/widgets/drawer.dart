import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:angostura_digital/services/firebase_service.dart'; // Asegúrate de importar tu servicio

class DrawerPrincipal extends StatefulWidget {
  const DrawerPrincipal({super.key});

  @override
  State<DrawerPrincipal> createState() => _DrawerPrincipalState();
}

class _DrawerPrincipalState extends State<DrawerPrincipal> {
  // Obtenemos el usuario actual
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            // Mostramos los datos reales, o un texto por defecto si es null
            accountName: Text(user?.displayName ?? 'Invitado'),
            accountEmail: Text(user?.email ?? 'Inicia sesión para continuar'),
            currentAccountPicture: CircleAvatar(
              backgroundImage: user?.photoURL != null 
                  ? NetworkImage(user!.photoURL!) 
                  : null,
              child: user?.photoURL == null ? const Icon(Icons.person) : null,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.campaign),
            title: const Text('Ofertas'),
            onTap: () {
              Navigator.pop(context); // Cierra el drawer
            },
          ),
          ListTile(
            leading: const Icon(Icons.fastfood),
            title: const Text('Restaurantes'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Cerrar Sesión"),
            onTap: () async {
              await AuthService().signOut();
              // Aquí podrías redirigir a una pantalla de Login
              Navigator.pop(context); 
            },
          )
        ],
      ),
    );
  }
}