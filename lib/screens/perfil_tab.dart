import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/services/firebase_service.dart';
import 'package:angostura_digital/widgets/editar_telefono_dialog.dart';

class PerfilTab extends StatelessWidget {
  const PerfilTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Inicia sesión')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').doc(user.uid).snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() as Map<String, dynamic>?;
          final nombre = data?['nombre']?.toString().trim().isNotEmpty == true
              ? data!['nombre'].toString()
              : (user.displayName ?? 'Usuario');
          final telefono = data?['telefono']?.toString().trim().isNotEmpty == true
              ? data!['telefono'].toString()
              : (user.phoneNumber ?? 'Sin teléfono');

          return ListView(
            children: [
              Container(
                color: globals.colorFondo,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _filaEditable(
                      context,
                      icon: Icons.person,
                      etiqueta: 'Nombre',
                      valor: nombre,
                      onEditar: () => _editarNombre(context, nombre),
                    ),
                    const SizedBox(height: 16),
                    _filaEditable(
                      context,
                      icon: Icons.phone,
                      etiqueta: 'Teléfono',
                      valor: telefono,
                      onEditar: () => EditarTelefonoDialog.mostrar(
                        context,
                        telefonoActual: telefono == 'Sin teléfono' ? '' : telefono,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                onTap: () async => AuthService().signOut(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filaEditable(
    BuildContext context, {
    required IconData icon,
    required String etiqueta,
    required String valor,
    required VoidCallback onEditar,
  }) {
    return InkWell(
      onTap: onEditar,
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                Text(
                  valor,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.edit, color: Colors.white70, size: 18),
        ],
      ),
    );
  }

  Future<void> _editarNombre(BuildContext context, String actual) async {
    final ctrl = TextEditingController(text: actual);
    final error = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar nombre'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Nombre'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final e = await AuthService().actualizarNombre(ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx, e);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }
}
