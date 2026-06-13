import 'package:flutter/material.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/services/negocio_ingrediente_service.dart';

/// Pantalla donde el negocio administra su catálogo de ingredientes.
///
/// Estos ingredientes luego se asignan a cada platillo al crearlo/editarlo.
class IngredientesNegocioScreen extends StatelessWidget {
  final String negocioId;
  final String nombreNegocio;

  const IngredientesNegocioScreen({
    super.key,
    required this.negocioId,
    required this.nombreNegocio,
  });

  Future<void> _mostrarFormulario(
    BuildContext context, {
    NegocioIngrediente? ingrediente,
  }) async {
    final nombreCtrl = TextEditingController(text: ingrediente?.nombre ?? '');
    final precioCtrl = TextEditingController(
      text: (ingrediente != null && ingrediente.precioExtra > 0)
          ? ingrediente.precioExtra.toStringAsFixed(2)
          : '',
    );
    final esEdicion = ingrediente != null;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esEdicion ? 'Editar ingrediente' : 'Nuevo ingrediente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre (ej. Lechuga, Carne, Queso)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: precioCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Costo extra (opcional)',
                hintText: '0.00',
                prefixText: '\$ ',
                helperText: 'Si el cliente lo agrega como extra. Déjalo vacío si es gratis.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nombre = nombreCtrl.text.trim();
              final precio = double.tryParse(precioCtrl.text.trim()) ?? 0;
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                if (esEdicion) {
                  await NegocioIngredienteService.actualizar(
                    negocioId,
                    ingrediente.id,
                    nombre: nombre,
                    precioExtra: precio,
                  );
                } else {
                  await NegocioIngredienteService.agregar(
                    negocioId,
                    nombre,
                    precioExtra: precio,
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
    );
  }

  Future<void> _confirmarEliminar(
    BuildContext context,
    NegocioIngrediente ingrediente,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar ingrediente'),
        content: Text(
          '¿Quitar "${ingrediente.nombre}" de tu lista? '
          'Los platillos que ya lo tengan no se modifican.',
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
      await NegocioIngredienteService.eliminar(negocioId, ingrediente.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis ingredientes'),
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
              'Registra los ingredientes que usas (carne, lechuga, queso, etc.). '
              'Después, al crear o editar un platillo, podrás elegir cuáles lleva. '
              'Así el cliente sabrá qué incluye y, más adelante, podrá pedir quitar alguno.',
              style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<NegocioIngrediente>>(
              stream: NegocioIngredienteService.stream(negocioId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final ingredientes = snapshot.data ?? [];
                if (ingredientes.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restaurant_menu,
                              size: 70, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'Aún no tienes ingredientes.\nToca "Agregar" para empezar.',
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
                  itemCount: ingredientes.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final ing = ingredientes[index];
                    return Card(
                      elevation: 1,
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.eco, color: Colors.white, size: 20),
                        ),
                        title: Text(
                          ing.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: ing.precioExtra > 0
                            ? Text(
                                'Extra: +\$${ing.precioExtra.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.green),
                              )
                            : const Text('Sin costo extra'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.blueAccent),
                              onPressed: () => _mostrarFormulario(
                                context,
                                ingrediente: ing,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _confirmarEliminar(context, ing),
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
