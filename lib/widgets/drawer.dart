import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:angostura_digital/services/firebase_service.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/screens/usuarios_screen.dart';
import 'package:angostura_digital/screens/gestionar_negocio_screen.dart';
import 'package:angostura_digital/screens/admin_gestionar_negocios_screen.dart';
import 'package:angostura_digital/screens/admin_historial_ventas_screen.dart';
import 'package:angostura_digital/screens/pedidos_negocio_screen.dart';
import 'package:angostura_digital/services/negocio_equipo_service.dart';
import 'package:angostura_digital/utils/negocio_equipo_utils.dart';
import 'package:angostura_digital/utils/comision_app_utils.dart';
import 'package:angostura_digital/utils/categorias_negocio.dart';
import 'package:angostura_digital/providers/cart_provider.dart';
import 'package:angostura_digital/widgets/auth_gate.dart';
import 'package:angostura_digital/navigation/app_navigator.dart';
import 'package:angostura_digital/widgets/editar_telefono_dialog.dart';

class DrawerPrincipal extends StatefulWidget {
  const DrawerPrincipal({super.key});

  @override
  State<DrawerPrincipal> createState() => _DrawerPrincipalState();
}

class _DrawerPrincipalState extends State<DrawerPrincipal> {
  bool _isCerrandoSesion = false;

  Future<void> _editarNombre(String nombreActual) async {
    final nombreCtrl = TextEditingController(text: nombreActual);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar nombre', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nombreCtrl,
          decoration: const InputDecoration(
            labelText: 'Tu nombre',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final error = await AuthService().actualizarNombre(nombreCtrl.text);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              if (error == null) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nombre actualizado'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _editarTelefono(String telefonoActual) async {
    final ok = await EditarTelefonoDialog.mostrar(
      context,
      telefonoActual: telefonoActual,
    );
    if (ok && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teléfono actualizado'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildPerfilHeader(User user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('usuarios').doc(user.uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final nombre = data?['nombre']?.toString().trim().isNotEmpty == true
            ? data!['nombre'].toString()
            : (user.displayName?.trim().isNotEmpty == true ? user.displayName! : 'Usuario');
        final telefono = data?['telefono']?.toString().trim().isNotEmpty == true
            ? data!['telefono'].toString()
            : (user.phoneNumber?.trim().isNotEmpty == true
                ? user.phoneNumber!
                : 'Sin teléfono');

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 20, 16, 16),
          color: globals.colorFondo,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mi perfil',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _editarNombre(nombre),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Nombre', style: TextStyle(color: Colors.white60, fontSize: 11)),
                            Text(
                              nombre,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _editarTelefono(telefono == 'Sin teléfono' ? '' : telefono),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_outlined, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Teléfono', style: TextStyle(color: Colors.white60, fontSize: 11)),
                            Text(
                              telefono,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- FUNCIÓN PARA CERRAR SESIÓN ---
  Future<void> _cerrarSesion() async {
    setState(() => _isCerrandoSesion = true);
    try {
      Navigator.pop(context);
      await AuthService().signOut();
      if (!mounted) return;
      Provider.of<CartProvider>(context, listen: false).limpiarCarrito();
      appNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isCerrandoSesion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Drawer(
      child: Column(
        children: [
          if (user != null) _buildPerfilHeader(user),

          // LISTA DE OPCIONES DINÁMICAS
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (user != null) ...[
                  StreamBuilder<List<NegocioAcceso>>(
                    stream: NegocioEquipoService.streamMisAccesos(user.uid),
                    builder: (context, accesosSnap) {
                      if (accesosSnap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }

                      if (accesosSnap.hasError) {
                        return ListTile(
                          leading: const Icon(Icons.error_outline, color: Colors.orange),
                          title: const Text('No se pudieron cargar tus negocios'),
                          subtitle: Text(
                            '${accesosSnap.error}',
                            style: const TextStyle(fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }

                      final accesos = accesosSnap.data ?? [];
                      if (accesos.isEmpty) {
                        return const ListTile(
                          leading: Icon(Icons.store_outlined, color: Colors.grey),
                          title: Text('No tienes negocios asignados'),
                          subtitle: Text(
                            'El administrador debe agregarte en Equipo del negocio.',
                            style: TextStyle(fontSize: 12),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('MIS NEGOCIOS'),
                          ...accesos.map((acceso) {
                            final estadoVisual = ComisionAppUtils.estadoVisual(acceso.estado);
                            final esTrabajador = NegocioEquipoUtils.esTrabajador(acceso.rol);
                            final esServicios =
                                CategoriasNegocio.esServicios(acceso.categoria);
                            return ListTile(
                              leading: Icon(
                                esTrabajador
                                    ? (esServicios
                                        ? Icons.event_available
                                        : Icons.receipt_long)
                                    : Icons.storefront,
                                color: esTrabajador ? Colors.blueAccent : Colors.orange,
                              ),
                              title: Text(acceso.nombre),
                              subtitle: Text(
                                esTrabajador
                                    ? 'Trabajador · ${estadoVisual.etiqueta.toUpperCase()}'
                                    : 'Dueño · ${estadoVisual.etiqueta.toUpperCase()}',
                                style: TextStyle(
                                  color: estadoVisual.color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              trailing: Icon(
                                esTrabajador ? Icons.arrow_forward_ios : Icons.settings,
                                color: Colors.blueGrey,
                                size: esTrabajador ? 16 : 24,
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                if (acceso.panelCompleto) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GestionarNegocioScreen(
                                        negocioId: acceso.negocioId,
                                        nombreActual: acceso.nombre,
                                        categoria: acceso.categoria,
                                        estadoActual: acceso.estado,
                                        fotoUrlActual: acceso.fotoUrl,
                                      ),
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PedidosNegocioScreen(
                                        negocioId: acceso.negocioId,
                                        nombreNegocio: acceso.nombre,
                                        categoria: acceso.categoria,
                                      ),
                                    ),
                                  );
                                }
                              },
                            );
                          }),
                        ],
                      );
                    },
                  ),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('usuarios').doc(user.uid).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return const SizedBox.shrink();
                      }
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      final rol = data['rol'] ?? 'cliente';

                      if (rol != 'admin') return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                            leading: const Icon(Icons.store, color: Colors.teal),
                            title: const Text('Gestionar negocios'),
                            subtitle: const Text('Crear, pausar, comisión y eliminar', style: TextStyle(fontSize: 12)),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminGestionarNegociosScreen()));
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.analytics, color: Colors.deepPurple),
                            title: const Text('Actividad en Angostura'),
                            subtitle: const Text('Historial de ventas de toda la plataforma', style: TextStyle(fontSize: 12)),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminHistorialVentasScreen()));
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
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