import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/services/negocio_clientes_descuento_service.dart';
import 'package:angostura_digital/services/negocio_equipo_service.dart';
import 'package:angostura_digital/utils/negocio_equipo_utils.dart';
import 'package:angostura_digital/widgets/buscador_usuario_dialog.dart';

/// Quién paga el precio con descuento en este negocio.
class ClientesDescuentoScreen extends StatefulWidget {
  final String negocioId;
  final String nombreNegocio;

  const ClientesDescuentoScreen({
    super.key,
    required this.negocioId,
    required this.nombreNegocio,
  });

  @override
  State<ClientesDescuentoScreen> createState() => _ClientesDescuentoScreenState();
}

class _ClientesDescuentoScreenState extends State<ClientesDescuentoScreen> {
  bool _puedeGestionar = false;

  @override
  void initState() {
    super.initState();
    _cargarPermiso();
  }

  Future<void> _cargarPermiso() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    final esAdmin = user.data()?['rol'] == 'admin';
    final rol = await NegocioEquipoService.obtenerRolEnNegocio(widget.negocioId, uid);
    if (!mounted) return;
    setState(() {
      _puedeGestionar = esAdmin || NegocioEquipoUtils.accesoGestionEquipo(rol);
    });
  }

  Future<void> _agregar() async {
    if (!_puedeGestionar) return;
    final usuario = await BuscadorUsuarioDialog.mostrar(
      context,
      titulo: 'Cliente con descuento',
      subtitulo: 'Busca por nombre o últimos dígitos del celular. Va a ver el precio con descuento.',
    );
    if (usuario == null || !mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      await NegocioClientesDescuentoService.agregar(
        negocioId: widget.negocioId,
        nombreNegocio: widget.nombreNegocio,
        uid: usuario.uid,
        agregadoPorUid: uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${usuario.nombre} ahora paga el precio con descuento.'),
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

  Future<void> _quitar(ClienteDescuento cliente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar descuento'),
        content: Text(
          '¿${cliente.nombre.isNotEmpty ? cliente.nombre : 'Este usuario'} '
          'vuelve a pagar el precio de venta?',
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
      await NegocioClientesDescuentoService.quitar(
        negocioId: widget.negocioId,
        uid: cliente.uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listo. Ahora paga el precio de venta.'), backgroundColor: Colors.green),
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
        title: Text('Descuento · ${widget.nombreNegocio}', style: const TextStyle(fontSize: 17)),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: _puedeGestionar
          ? FloatingActionButton.extended(
              onPressed: _agregar,
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
            color: Colors.teal.shade50,
            child: const Text(
              'Estas personas pagan el precio con descuento de tus productos y servicios. '
              'Un cliente normal sigue viendo el precio de venta. '
              'No entran al panel del negocio.',
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ClienteDescuento>>(
              stream: NegocioClientesDescuentoService.streamClientes(widget.negocioId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final lista = snap.data ?? [];
                if (lista.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.loyalty_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'Nadie tiene precio con descuento.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _puedeGestionar
                                ? 'Agrega técnicos, mayoristas u otros clientes especiales.'
                                : 'Sin permisos para cambiar esta lista.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  itemCount: lista.length,
                  itemBuilder: (context, i) {
                    final c = lista[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade100,
                          child: const Icon(Icons.loyalty_outlined, color: Colors.teal),
                        ),
                        title: Text(c.nombre.isNotEmpty ? c.nombre : 'Usuario'),
                        subtitle: Text(
                          c.telefono.isNotEmpty ? c.telefono : 'Cliente con descuento',
                        ),
                        trailing: _puedeGestionar
                            ? IconButton(
                                icon: const Icon(Icons.person_remove_outlined, color: Colors.redAccent),
                                tooltip: 'Quitar',
                                onPressed: () => _quitar(c),
                              )
                            : null,
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
