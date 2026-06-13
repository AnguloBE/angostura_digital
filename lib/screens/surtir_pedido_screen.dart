import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/services/negocio_ubicacion_service.dart';
import 'package:angostura_digital/screens/escaner_codigo_screen.dart';

/// Pantalla para preparar (surtir) un pedido de productos.
///
/// Muestra cada producto con su ubicación. El trabajador escanea el producto
/// y la ubicación para restar del inventario e ir marcando lo que ya echó a
/// la bolsa, viendo cuánto falta.
class SurtirPedidoScreen extends StatefulWidget {
  final String pedidoId;
  final String negocioId;
  final String nombreNegocio;
  final List<Map<String, dynamic>> productos;

  const SurtirPedidoScreen({
    super.key,
    required this.pedidoId,
    required this.negocioId,
    required this.nombreNegocio,
    required this.productos,
  });

  @override
  State<SurtirPedidoScreen> createState() => _SurtirPedidoScreenState();
}

class _SurtirPedidoScreenState extends State<SurtirPedidoScreen> {
  List<NegocioUbicacion> _catalogo = [];
  // Datos del producto (código, ubicaciones) por id de producto.
  final Map<String, Map<String, dynamic>> _datosProducto = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    try {
      _catalogo = await NegocioUbicacionService.obtener(widget.negocioId);
    } catch (_) {}
    await _cargarProductos();
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _cargarProductos() async {
    final ids = widget.productos
        .map((p) => p['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    for (final id in ids) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('productos')
            .doc(id)
            .get();
        if (doc.exists && doc.data() != null) {
          _datosProducto[id] = doc.data()!;
        }
      } catch (_) {}
    }
  }

  Future<void> _refrescarProducto(String id) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('productos')
          .doc(id)
          .get();
      if (doc.exists && doc.data() != null && mounted) {
        setState(() => _datosProducto[id] = doc.data()!);
      }
    } catch (_) {}
  }

  int _cantidadLinea(Map<String, dynamic> item) =>
      (item['cantidad'] as num?)?.toInt() ?? 1;

  // ----------------- Flujo de surtido -----------------

  Future<void> _agregarABolsa(
    int index,
    Map<String, dynamic> item,
    int yaSurtido,
  ) async {
    final restante = _cantidadLinea(item) - yaSurtido;
    if (restante <= 0) return;

    final prodId = item['id']?.toString() ?? '';
    final prodData = _datosProducto[prodId];
    final codigoProducto =
        (prodData?['codigo_barras'] ?? '').toString().trim();

    // Paso 1: identificar el producto (escanear si tiene código).
    if (codigoProducto.isNotEmpty) {
      final escaneado = await EscanerCodigoScreen.escanear(
        context,
        titulo: 'Escanear: ${item['nombre'] ?? 'producto'}',
      );
      if (escaneado == null) return;
      if (escaneado.trim() != codigoProducto) {
        final continuar = await _confirmar(
          titulo: 'El código no coincide',
          mensaje:
              'Escaneaste "$escaneado" pero este producto tiene el código "$codigoProducto". '
              '¿Aun así lo agregas?',
          textoOk: 'Sí, agregar',
        );
        if (continuar != true) return;
      }
    }

    if (!mounted) return;
    await _dialogoUbicacionYCantidad(index, item, prodId, prodData, restante);
  }

  Future<void> _dialogoUbicacionYCantidad(
    int index,
    Map<String, dynamic> item,
    String prodId,
    Map<String, dynamic>? prodData,
    int restante,
  ) async {
    final ubicaciones = prodData == null
        ? <StockUbicacion>[]
        : NegocioUbicacionService.ubicacionesProducto(prodData);

    String? lugarSel = ubicaciones.isNotEmpty ? ubicaciones.first.lugar : null;
    final pedidas = _cantidadLinea(item);
    final yaSurtido = pedidas - restante;
    final cantidadCtrl = TextEditingController(text: restante.toString());

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          return AlertDialog(
            title: const Text('Agregar a la bolsa'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item['nombre']?.toString() ?? 'Producto',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Pidieron: $pedidas',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Ya en la bolsa: $yaSurtido',
                          style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Faltan $restante por surtir',
                      style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600)),
                  const Divider(height: 20),
                  if (ubicaciones.isEmpty)
                    Text(
                      'Este producto no tiene ubicación ni stock registrado. '
                      'Puedes marcarlo como echado de todas formas.',
                      style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: lugarSel,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Tomar de la ubicación',
                              border: OutlineInputBorder(),
                            ),
                            items: ubicaciones
                                .map((u) => DropdownMenuItem(
                                      value: u.lugar,
                                      child: Text('${u.lugar} (${u.cantidad})'),
                                    ))
                                .toList(),
                            onChanged: (v) => setDialog(() => lugarSel = v),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: Colors.indigo),
                          tooltip: 'Escanear etiqueta de ubicación',
                          onPressed: () async {
                            final cod = await EscanerCodigoScreen.escanear(
                              ctx,
                              titulo: 'Escanear ubicación',
                            );
                            if (cod == null || !ctx.mounted) return;
                            final encontrada =
                                NegocioUbicacionService.emparejarPorCodigo(
                              _catalogo,
                              cod,
                            );
                            final nombre = encontrada?.nombre ?? cod.trim();
                            final coincide = ubicaciones.any((u) =>
                                u.lugar.toLowerCase() == nombre.toLowerCase());
                            if (coincide) {
                              setDialog(() => lugarSel = ubicaciones
                                  .firstWhere((u) =>
                                      u.lugar.toLowerCase() ==
                                      nombre.toLowerCase())
                                  .lugar);
                            } else {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'La ubicación "$nombre" no es de este producto.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: cantidadCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Piezas a echar',
                      border: OutlineInputBorder(),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  var cantidad = int.tryParse(cantidadCtrl.text.trim()) ?? 0;
                  if (cantidad <= 0) return;
                  if (cantidad > restante) cantidad = restante;
                  Navigator.pop(ctx);
                  await _confirmarSurtido(
                    index: index,
                    prodId: prodId,
                    prodData: prodData,
                    lugar: lugarSel,
                    cantidad: cantidad,
                    yaSurtido: _cantidadLinea(item) - restante,
                  );
                },
                child: const Text('Echar a la bolsa'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmarSurtido({
    required int index,
    required String prodId,
    required Map<String, dynamic>? prodData,
    required String? lugar,
    required int cantidad,
    required int yaSurtido,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    // Restar del inventario en esa ubicación (si aplica).
    if (prodData != null && lugar != null && lugar.isNotEmpty && prodId.isNotEmpty) {
      final actuales = NegocioUbicacionService.ubicacionesProducto(prodData);
      final nuevas = [...actuales];
      final idx = nuevas
          .indexWhere((u) => u.lugar.toLowerCase() == lugar.toLowerCase());
      if (idx >= 0) {
        final restanteStock = nuevas[idx].cantidad - cantidad;
        nuevas[idx] = nuevas[idx]
            .copyWith(cantidad: restanteStock < 0 ? 0 : restanteStock);
        if (restanteStock < 0) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                  'Había menos piezas de las indicadas; el stock quedó en 0.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      try {
        await FirebaseFirestore.instance
            .collection('productos')
            .doc(prodId)
            .update({
          'ubicaciones': nuevas.map((u) => u.toMap()).toList(),
          'stock_total': NegocioUbicacionService.sumarCantidades(nuevas),
        });
      } catch (_) {}
      await _refrescarProducto(prodId);
    }

    // Marcar lo surtido en el pedido.
    try {
      await FirebaseFirestore.instance
          .collection('pedidos')
          .doc(widget.pedidoId)
          .update({'surtido_lineas.$index': yaSurtido + cantidad});
    } catch (_) {}
  }

  Future<void> _quitarDeLaBolsa(int index, int yaSurtido) async {
    if (yaSurtido <= 0) return;
    await FirebaseFirestore.instance
        .collection('pedidos')
        .doc(widget.pedidoId)
        .update({'surtido_lineas.$index': yaSurtido - 1});
  }

  Future<bool?> _confirmar({
    required String titulo,
    required String mensaje,
    String textoOk = 'Aceptar',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(textoOk),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Surtir pedido'),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pedidos')
                  .doc(widget.pedidoId)
                  .snapshots(),
              builder: (context, snap) {
                final data = snap.data?.data() as Map<String, dynamic>?;
                final surtido = (data?['surtido_lineas'] as Map?) ?? {};

                int totalUnidades = 0;
                int totalSurtido = 0;
                for (var i = 0; i < widget.productos.length; i++) {
                  final cant = _cantidadLinea(widget.productos[i]);
                  totalUnidades += cant;
                  final s = (surtido['$i'] as num?)?.toInt() ?? 0;
                  totalSurtido += s > cant ? cant : s;
                }
                final progreso =
                    totalUnidades == 0 ? 0.0 : totalSurtido / totalUnidades;
                final completo = totalSurtido >= totalUnidades;

                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: completo ? Colors.green.shade50 : Colors.blue.shade50,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            completo
                                ? '¡Pedido completo! 🎉'
                                : 'Surtidos: $totalSurtido de $totalUnidades',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: completo
                                  ? Colors.green.shade800
                                  : Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progreso,
                              minHeight: 10,
                              backgroundColor: Colors.grey.shade300,
                              color: completo ? Colors.green : Colors.blueAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: widget.productos.length,
                        itemBuilder: (context, i) {
                          final item = widget.productos[i];
                          final cantidad = _cantidadLinea(item);
                          final yaSurtido =
                              (surtido['$i'] as num?)?.toInt() ?? 0;
                          final hecho = yaSurtido >= cantidad;
                          final prodId = item['id']?.toString() ?? '';
                          final prodData = _datosProducto[prodId];
                          final ubicTexto = prodData == null
                              ? null
                              : NegocioUbicacionService.textoUbicaciones(prodData);

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            color: hecho ? Colors.green.shade50 : null,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        hecho
                                            ? Icons.check_circle
                                            : Icons.shopping_bag_outlined,
                                        color: hecho
                                            ? Colors.green
                                            : Colors.blueGrey,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item['nombre']?.toString() ?? 'Producto',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            decoration: hecho
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: hecho
                                              ? Colors.green
                                              : Colors.blueAccent,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '$yaSurtido / $cantidad',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.place,
                                          size: 18, color: Colors.indigo),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          ubicTexto ?? 'Sin ubicación registrada',
                                          style: const TextStyle(
                                            color: Colors.indigo,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      if (yaSurtido > 0)
                                        TextButton.icon(
                                          onPressed: () =>
                                              _quitarDeLaBolsa(i, yaSurtido),
                                          icon: const Icon(Icons.undo, size: 18),
                                          label: const Text('Quitar 1'),
                                        ),
                                      const Spacer(),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: hecho
                                              ? Colors.grey
                                              : Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: hecho
                                            ? null
                                            : () => _agregarABolsa(
                                                i, item, yaSurtido),
                                        icon: const Icon(Icons.add_shopping_cart,
                                            size: 18),
                                        label: const Text('Agregar a la bolsa'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
