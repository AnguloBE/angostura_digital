import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/screens/escaner_codigo_screen.dart';
import 'package:angostura_digital/services/negocio_ubicacion_service.dart';
import 'package:angostura_digital/services/producto_stock_service.dart';
import 'package:angostura_digital/widgets/agregar_stock_producto_dialog.dart';
import 'package:angostura_digital/widgets/square_image.dart';

/// Entrada rápida para sumar stock a productos ya registrados.
class AgregarMercanciaScreen extends StatefulWidget {
  final String negocioId;
  final String nombreNegocio;

  const AgregarMercanciaScreen({
    super.key,
    required this.negocioId,
    required this.nombreNegocio,
  });

  @override
  State<AgregarMercanciaScreen> createState() => _AgregarMercanciaScreenState();
}

class _AgregarMercanciaScreenState extends State<AgregarMercanciaScreen> {
  final _codigoCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();

  bool _cargando = true;
  bool _buscandoCodigo = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _productos = [];
  List<NegocioUbicacion> _ubicaciones = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final productos =
          await ProductoStockService.listarProductosTienda(widget.negocioId);
      final ubicaciones = await NegocioUbicacionService.obtener(widget.negocioId);
      if (mounted) {
        setState(() {
          _productos = productos;
          _ubicaciones = ubicaciones;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudieron cargar productos: $e')),
        );
      }
    }
  }

  Future<void> _abrirStock(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    String? mensajeExito,
  }) async {
    final ok = await AgregarStockProductoDialog.mostrar(
      context,
      negocioId: widget.negocioId,
      productoDoc: doc,
      catalogoUbicaciones: _ubicaciones,
    );
    if (!mounted) return;
    if (ok) {
      await _cargarDatos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mensajeExito ??
                'Stock actualizado: ${doc.data()['nombre'] ?? 'producto'}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _escanearCodigo() async {
    final codigo = await EscanerCodigoScreen.escanear(
      context,
      titulo: 'Escanear producto',
    );
    if (codigo == null || codigo.isEmpty || !mounted) return;
    _codigoCtrl.text = codigo;
    await _buscarPorCodigo(codigo);
  }

  Future<void> _buscarPorCodigo([String? codigoManual]) async {
    final codigo = (codigoManual ?? _codigoCtrl.text).trim();
    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe o escanea un código.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _buscandoCodigo = true);
    try {
      final doc = await ProductoStockService.buscarPorCodigo(widget.negocioId, codigo);
      if (!mounted) return;
      if (doc == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No hay producto con el código «$codigo». Regístralo primero.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      await _abrirStock(doc);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al buscar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _buscandoCodigo = false);
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _resultadosNombre {
    return ProductoStockService.filtrarPorNombre(_productos, _nombreCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final resultados = _resultadosNombre;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar mercancía'),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.nombreNegocio,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Busca un producto ya registrado y suma piezas al inventario.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                _seccionTitulo(Icons.qr_code_scanner, 'Código de barras'),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text(
                      'Escanear con cámara',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _escanearCodigo,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codigoCtrl,
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          labelText: 'Código escrito a mano',
                          hintText: 'Ej. 7501234567890',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.pin),
                        ),
                        onSubmitted: (_) => _buscarPorCodigo(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buscandoCodigo
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton.filled(
                            onPressed: () => _buscarPorCodigo(),
                            icon: const Icon(Icons.search),
                            tooltip: 'Buscar por código',
                          ),
                  ],
                ),
                const SizedBox(height: 24),
                _seccionTitulo(Icons.inventory_2_outlined, 'Buscar por nombre'),
                const SizedBox(height: 6),
                Text(
                  'Útil si el producto no tiene código (ej. capacitores, piezas sueltas).',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nombreCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Nombre del producto',
                    hintText: 'Ej. capacitor 470 35v',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _nombreCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _nombreCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                if (_nombreCtrl.text.trim().isEmpty)
                  Text(
                    'Escribe al menos una palabra para ver coincidencias.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  )
                else if (resultados.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Sin coincidencias para «${_nombreCtrl.text.trim()}».',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  )
                else
                  ...resultados.take(25).map(_tileProducto),
                if (resultados.length > 25)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Mostrando 25 de ${resultados.length}. Sé más específico.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _seccionTitulo(IconData icono, String texto) {
    return Row(
      children: [
        Icon(icono, color: Colors.teal.shade700, size: 22),
        const SizedBox(width: 8),
        Text(
          texto,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _tileProducto(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final nombre = (data['nombre'] ?? 'Sin nombre').toString();
    final stock = NegocioUbicacionService.stockTotal(data);
    final foto = data['foto_url']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: SquareImage(
          imageUrl: foto,
          size: 48,
          borderRadius: BorderRadius.circular(8),
          placeholder: Container(
            color: Colors.grey.shade200,
            child: const Icon(Icons.inventory_2, color: Colors.grey),
          ),
        ),
        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Stock actual: $stock pza(s)'),
        trailing: const Icon(Icons.add_circle_outline, color: Colors.green),
        onTap: () => _abrirStock(doc),
      ),
    );
  }
}
