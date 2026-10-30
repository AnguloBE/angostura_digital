import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:angostura_digital/services/negocio_ubicacion_service.dart';
import 'package:angostura_digital/services/producto_stock_service.dart';

/// Diálogo para sumar piezas a un producto ya registrado.
class AgregarStockProductoDialog {
  AgregarStockProductoDialog._();

  /// Retorna `true` si se agregó stock.
  static Future<bool> mostrar(
    BuildContext context, {
    required String negocioId,
    required QueryDocumentSnapshot<Map<String, dynamic>> productoDoc,
    List<NegocioUbicacion>? catalogoUbicaciones,
  }) async {
    if (!context.mounted) return false;

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AgregarStockProductoDialogContent(
        negocioId: negocioId,
        productoDoc: productoDoc,
        catalogoUbicaciones: catalogoUbicaciones,
      ),
    );

    return resultado == true;
  }
}

class _AgregarStockProductoDialogContent extends StatefulWidget {
  final String negocioId;
  final QueryDocumentSnapshot<Map<String, dynamic>> productoDoc;
  final List<NegocioUbicacion>? catalogoUbicaciones;

  const _AgregarStockProductoDialogContent({
    required this.negocioId,
    required this.productoDoc,
    this.catalogoUbicaciones,
  });

  @override
  State<_AgregarStockProductoDialogContent> createState() =>
      _AgregarStockProductoDialogContentState();
}

class _AgregarStockProductoDialogContentState
    extends State<_AgregarStockProductoDialogContent> {
  final _cantidadCtrl = TextEditingController(text: '1');

  List<NegocioUbicacion> _catalogo = [];
  List<String> _nombresCatalogo = [];
  String? _lugarSel;
  bool _cargando = true;
  bool _guardando = false;

  Map<String, dynamic> get _data => widget.productoDoc.data();

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    final ubicActuales = NegocioUbicacionService.ubicacionesProducto(_data);
    _catalogo = widget.catalogoUbicaciones ??
        await NegocioUbicacionService.obtener(widget.negocioId);

    _nombresCatalogo = <String>{
      ..._catalogo.map((e) => e.nombre),
      ...ubicActuales.map((u) => u.lugar),
    }.toList()
      ..sort();

    _lugarSel = ubicActuales.isNotEmpty
        ? ubicActuales.first.lugar
        : (_nombresCatalogo.isNotEmpty ? _nombresCatalogo.first : null);

    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _guardar() async {
    final cantidad = int.tryParse(_cantidadCtrl.text.trim()) ?? 0;
    final lugar = _lugarSel;
    if (lugar == null || lugar.isEmpty || cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elige ubicación y una cantidad válida.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      await ProductoStockService.agregarStock(
        productoRef: widget.productoDoc.reference,
        productoData: _data,
        lugar: lugar,
        cantidad: cantidad,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = (_data['nombre'] ?? 'Producto').toString();
    final ubicacionesTexto =
        NegocioUbicacionService.textoUbicaciones(_data) ?? 'Sin ubicación registrada';
    final stock = NegocioUbicacionService.stockTotal(_data);

    return AlertDialog(
      title: const Text('Agregar al inventario'),
      content: _cargando
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'En existencia: $stock pza(s)',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ubicación actual: $ubicacionesTexto',
                    style: const TextStyle(color: Colors.indigo),
                  ),
                  const Divider(height: 24),
                  const Text(
                    '¿Cuántas piezas agregas y en qué ubicación?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (_nombresCatalogo.isEmpty)
                    const Text(
                      'Primero registra ubicaciones (repisas, bodega) en tu negocio.',
                      style: TextStyle(color: Colors.orange, fontSize: 13),
                    )
                  else
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Ubicación',
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _nombresCatalogo.contains(_lugarSel)
                              ? _lugarSel
                              : _nombresCatalogo.first,
                          isExpanded: true,
                          items: _nombresCatalogo
                              .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                              .toList(),
                          onChanged: (v) => setState(() => _lugarSel = v),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cantidadCtrl,
                    keyboardType: TextInputType.number,
                    enabled: !_guardando,
                    decoration: const InputDecoration(
                      labelText: 'Piezas a agregar',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: _cargando || _guardando || _nombresCatalogo.isEmpty ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Agregar'),
        ),
      ],
    );
  }
}
