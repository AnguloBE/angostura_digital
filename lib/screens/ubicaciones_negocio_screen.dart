import 'package:flutter/material.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/services/negocio_ubicacion_service.dart';
import 'package:angostura_digital/screens/escaner_codigo_screen.dart';

/// Pantalla donde el negocio administra sus ubicaciones (repisas/zonas).
///
/// Estas ubicaciones luego se asignan a cada producto para saber dónde está
/// acomodado y en qué cantidad.
class UbicacionesNegocioScreen extends StatelessWidget {
  final String negocioId;
  final String nombreNegocio;

  const UbicacionesNegocioScreen({
    super.key,
    required this.negocioId,
    required this.nombreNegocio,
  });

  Future<void> _mostrarFormulario(
    BuildContext context, {
    NegocioUbicacion? ubicacion,
  }) async {
    final nombreCtrl = TextEditingController(text: ubicacion?.nombre ?? '');
    final codigoCtrl = TextEditingController(text: ubicacion?.codigo ?? '');
    final esEdicion = ubicacion != null;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(esEdicion ? 'Editar ubicación' : 'Nueva ubicación'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Nombre (ej. Repisa A2, Mostrador, Bodega)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codigoCtrl,
                  decoration: InputDecoration(
                    labelText: 'Código de etiqueta (opcional)',
                    helperText: 'Si imprimes etiquetas para escanear la repisa.',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.indigo),
                      tooltip: 'Escanear etiqueta',
                      onPressed: () async {
                        final codigo = await EscanerCodigoScreen.escanear(
                          ctx,
                          titulo: 'Escanear etiqueta de ubicación',
                        );
                        if (codigo != null && codigo.isNotEmpty) {
                          setDialog(() => codigoCtrl.text = codigo);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nombre = nombreCtrl.text.trim();
                final codigo = codigoCtrl.text.trim();
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                try {
                  if (esEdicion) {
                    await NegocioUbicacionService.actualizar(
                      negocioId,
                      ubicacion.id,
                      nombre,
                      codigo: codigo,
                    );
                  } else {
                    await NegocioUbicacionService.agregar(
                      negocioId,
                      nombre,
                      codigo: codigo,
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: Text(esEdicion ? 'Guardar' : 'Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarEliminar(
    BuildContext context,
    NegocioUbicacion ubicacion,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar ubicación'),
        content: Text(
          '¿Quitar "${ubicacion.nombre}"? '
          'Los productos que ya la tengan asignada no se modifican.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await NegocioUbicacionService.eliminar(negocioId, ubicacion.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicaciones / Repisas'),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
        onPressed: () => _mostrarFormulario(context),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.blue.shade50,
            padding: const EdgeInsets.all(14),
            child: Text(
              'Registra dónde acomodas tus productos (repisas, mostrador, bodega, etc.). '
              'Al dar de alta o surtir un producto eliges la ubicación y la cantidad. '
              'Así cualquier trabajador sabrá dónde encontrarlo, aunque esté en varias repisas.',
              style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<NegocioUbicacion>>(
              stream: NegocioUbicacionService.stream(negocioId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final ubicaciones = snapshot.data ?? [];
                if (ubicaciones.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shelves,
                              size: 70, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'Aún no tienes ubicaciones.\nToca "Agregar" para empezar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(
                      left: 12, right: 12, top: 12, bottom: 90),
                  itemCount: ubicaciones.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final ubi = ubicaciones[index];
                    return Card(
                      elevation: 1,
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.indigo,
                          child: Icon(Icons.place, color: Colors.white, size: 20),
                        ),
                        title: Text(
                          ubi.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: ubi.codigo.isNotEmpty
                            ? Text('Etiqueta: ${ubi.codigo}',
                                style: const TextStyle(fontSize: 12))
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.blueAccent),
                              onPressed: () => _mostrarFormulario(
                                context,
                                ubicacion: ubi,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmarEliminar(context, ubi),
                            ),
                          ],
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
