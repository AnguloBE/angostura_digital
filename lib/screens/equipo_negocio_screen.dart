import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/services/negocio_equipo_service.dart';
import 'package:angostura_digital/utils/negocio_equipo_utils.dart';
import 'package:angostura_digital/widgets/buscador_usuario_dialog.dart';

class EquipoNegocioScreen extends StatefulWidget {
  final String negocioId;
  final String nombreNegocio;

  /// Admin puede agregar dueños, encargados y trabajadores.
  final bool esAdmin;

  const EquipoNegocioScreen({
    super.key,
    required this.negocioId,
    required this.nombreNegocio,
    this.esAdmin = false,
  });

  @override
  State<EquipoNegocioScreen> createState() => _EquipoNegocioScreenState();
}

class _EquipoNegocioScreenState extends State<EquipoNegocioScreen> {
  String? _miRol;

  @override
  void initState() {
    super.initState();
    NegocioEquipoService.migrarPropietarioLegacy(widget.negocioId);
    _cargarMiRol();
  }

  Future<void> _cargarMiRol() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final rol = await NegocioEquipoService.obtenerRolEnNegocio(widget.negocioId, uid);
    if (mounted) setState(() => _miRol = rol);
  }

  bool get _puedeAgregar =>
      widget.esAdmin || NegocioEquipoUtils.accesoGestionEquipo(_miRol);

  Future<String?> _elegirRol(String nombreUsuario) async {
    if (widget.esAdmin) {
      return showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Rol para $nombreUsuario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Dueño'),
                subtitle: const Text('Panel completo', style: TextStyle(fontSize: 12)),
                leading: const Icon(Icons.store, color: Colors.indigo),
                onTap: () => Navigator.pop(ctx, NegocioEquipoUtils.rolDueno),
              ),
              ListTile(
                title: const Text('Encargado'),
                subtitle: Text(
                  NegocioEquipoUtils.descripcionPermisosEncargado(),
                  style: const TextStyle(fontSize: 12),
                ),
                leading: const Icon(Icons.supervisor_account, color: Colors.deepPurple),
                onTap: () => Navigator.pop(ctx, NegocioEquipoUtils.rolEncargado),
              ),
              ListTile(
                title: const Text('Trabajador'),
                subtitle: Text(
                  NegocioEquipoUtils.descripcionPermisosTrabajador(),
                  style: const TextStyle(fontSize: 12),
                ),
                leading: const Icon(Icons.badge_outlined, color: Colors.teal),
                onTap: () => Navigator.pop(ctx, NegocioEquipoUtils.rolTrabajador),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ],
        ),
      );
    }

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rol para $nombreUsuario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Encargado'),
              subtitle: Text(
                NegocioEquipoUtils.descripcionPermisosEncargado(),
                style: const TextStyle(fontSize: 12),
              ),
              leading: const Icon(Icons.supervisor_account, color: Colors.deepPurple),
              onTap: () => Navigator.pop(ctx, NegocioEquipoUtils.rolEncargado),
            ),
            ListTile(
              title: const Text('Trabajador'),
              subtitle: Text(
                NegocioEquipoUtils.descripcionPermisosTrabajador(),
                style: const TextStyle(fontSize: 12),
              ),
              leading: const Icon(Icons.badge_outlined, color: Colors.teal),
              onTap: () => Navigator.pop(ctx, NegocioEquipoUtils.rolTrabajador),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ],
      ),
    );
  }

  Future<void> _agregarMiembro() async {
    if (!_puedeAgregar) return;

    final usuario = await BuscadorUsuarioDialog.mostrar(
      context,
      titulo: widget.esAdmin ? 'Agregar al equipo' : 'Agregar al equipo',
      subtitulo: 'Busca por nombre o últimos dígitos del celular.',
    );
    if (usuario == null || !mounted) return;

    final rolElegido = await _elegirRol(usuario.nombre);
    if (rolElegido == null || !mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      await NegocioEquipoService.agregarMiembroPorUid(
        negocioId: widget.negocioId,
        uid: usuario.uid,
        rol: rolElegido,
        agregadoPorUid: uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${usuario.nombre} agregado como ${NegocioEquipoUtils.etiquetaRol(rolElegido)}.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _quitarMiembro(NegocioMiembro miembro) async {
    if (!NegocioEquipoUtils.puedeQuitarMiembro(
      rolQuienQuita: _miRol,
      rolObjetivo: miembro.rol,
      esAdmin: widget.esAdmin,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Los encargados no pueden quitar al dueño del negocio.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar del equipo'),
        content: Text(
          '¿Quitar a ${miembro.nombre.isNotEmpty ? miembro.nombre : miembro.telefono} '
          '(${NegocioEquipoUtils.etiquetaRol(miembro.rol)})?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    try {
      await NegocioEquipoService.quitarMiembro(negocioId: widget.negocioId, uid: miembro.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Miembro removido.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Equipo · ${widget.nombreNegocio}', style: const TextStyle(fontSize: 17)),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: _puedeAgregar
          ? FloatingActionButton.extended(
              onPressed: _agregarMiembro,
              icon: const Icon(Icons.person_search),
              label: const Text('Buscar y agregar'),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: Colors.indigo.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dueños',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Text(
                  'Acceso total al panel y al equipo.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Encargados',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  NegocioEquipoUtils.descripcionPermisosEncargado(),
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Trabajadores',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  NegocioEquipoUtils.descripcionPermisosTrabajador(),
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<NegocioMiembro>>(
              stream: NegocioEquipoService.streamEquipo(widget.negocioId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final miembros = snap.data ?? [];
                if (miembros.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.groups_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'Sin dueños ni trabajadores asignados.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _puedeAgregar
                                ? 'Usa «Buscar y agregar» para asignar encargados o trabajadores.'
                                : 'Sin permisos para gestionar el equipo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final duenos = miembros.where((m) => NegocioEquipoUtils.esDueno(m.rol)).toList();
                final encargados =
                    miembros.where((m) => NegocioEquipoUtils.esEncargado(m.rol)).toList();
                final trabajadores =
                    miembros.where((m) => NegocioEquipoUtils.esTrabajador(m.rol)).toList();

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (duenos.isNotEmpty) ...[
                      _seccionTitulo('Dueños (${duenos.length})'),
                      ...duenos.map((m) => _tileMiembro(m)),
                    ],
                    if (encargados.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _seccionTitulo('Encargados (${encargados.length})'),
                      ...encargados.map((m) => _tileMiembro(m)),
                    ],
                    if (trabajadores.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _seccionTitulo('Trabajadores (${trabajadores.length})'),
                      ...trabajadores.map((m) => _tileMiembro(m)),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionTitulo(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54)),
      );

  Widget _tileMiembro(NegocioMiembro m) {
    final esDueno = NegocioEquipoUtils.esDueno(m.rol);
    final esEncargado = NegocioEquipoUtils.esEncargado(m.rol);
    final puedeQuitar = NegocioEquipoUtils.puedeQuitarMiembro(
      rolQuienQuita: _miRol,
      rolObjetivo: m.rol,
      esAdmin: widget.esAdmin,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: esDueno
              ? Colors.indigo.shade100
              : (esEncargado ? Colors.deepPurple.shade100 : Colors.teal.shade100),
          child: Icon(
            esDueno
                ? Icons.storefront
                : (esEncargado ? Icons.supervisor_account : Icons.badge_outlined),
            color: esDueno ? Colors.indigo : (esEncargado ? Colors.deepPurple : Colors.teal),
          ),
        ),
        title: Text(m.nombre.isNotEmpty ? m.nombre : 'Usuario'),
        subtitle: Text('${NegocioEquipoUtils.etiquetaRol(m.rol)} · ${m.telefono.isNotEmpty ? m.telefono : m.uid}'),
        trailing: puedeQuitar
            ? IconButton(
                icon: const Icon(Icons.person_remove_outlined, color: Colors.redAccent),
                tooltip: 'Quitar',
                onPressed: () => _quitarMiembro(m),
              )
            : null,
      ),
    );
  }
}
