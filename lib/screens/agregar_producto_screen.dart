import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/utils/mobile_image_utils.dart';
import 'package:angostura_digital/widgets/square_image.dart';
import 'package:angostura_digital/services/negocio_ingrediente_service.dart';
import 'package:angostura_digital/services/negocio_ubicacion_service.dart';
import 'package:angostura_digital/screens/ingredientes_negocio_screen.dart';
import 'package:angostura_digital/screens/ubicaciones_negocio_screen.dart';
import 'package:angostura_digital/screens/escaner_codigo_screen.dart';
import 'package:angostura_digital/utils/categorias_negocio.dart';
import 'package:angostura_digital/utils/opciones_negocio.dart';
import 'package:angostura_digital/utils/precio_producto_utils.dart';
import 'package:angostura_digital/utils/seccion_producto_utils.dart';
import 'package:angostura_digital/widgets/agregar_stock_producto_dialog.dart';
import 'package:angostura_digital/widgets/selector_seccion.dart';

class AgregarProductoScreen extends StatefulWidget {
  final String negocioId;
  final String categoriaNegocio;
  // --- AÑADIMOS ESTO PARA SOPORTAR EDICIÓN ---
  final String? productoId;
  final Map<String, dynamic>? productoData;

  const AgregarProductoScreen({
    super.key, 
    required this.negocioId, 
    required this.categoriaNegocio,
    this.productoId,
    this.productoData,
  });

  @override
  State<AgregarProductoScreen> createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _nombreCtrl;
  late TextEditingController _precioCtrl;
  late TextEditingController _costoCtrl;
  late TextEditingController _descuentoCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _ingredientesCtrl; 
  late TextEditingController _codigoBarrasCtrl; 
  late TextEditingController _gramosCtrl;
  late TextEditingController _materialCtrl;
  late TextEditingController _piezasCtrl; 

  String? _fotoUrlExistente;
  Uint8List? _imagenBytes;

  // Ingredientes seleccionados del catálogo del negocio para este platillo.
  final Set<String> _ingredientesSeleccionados = {};
  List<NegocioIngrediente> _catalogoIngredientes = [];
  bool _cargandoIngredientes = true;
  final ScrollController _scrollCtrl = ScrollController();

  // Inventario por ubicación (solo negocios de productos).
  List<NegocioUbicacion> _catalogoUbicaciones = [];
  final List<_FilaInventario> _filasInventario = [];

  // Si el producto no tiene código de barras (no se pide ni se exige).
  bool _sinCodigo = false;
  bool _destacado = false;
  bool _requiereReceta = false;
  bool _cotizarWhatsapp = false;
  DateTime? _vence;
  String _seccion = '';
  late OpcionesNegocio _opciones;

  bool get _usaIngredientes =>
      NegocioIngredienteService.usaIngredientes(widget.categoriaNegocio);

  bool get _esBodega => CategoriasNegocio.esBodega(widget.categoriaNegocio);

  bool get _esProductos => _opciones.stock && !_usaIngredientes;

  bool get _esFarmacia => CategoriasNegocio.esFarmacia(widget.categoriaNegocio);

  bool get _esImprenta => CategoriasNegocio.esImprenta(widget.categoriaNegocio);

  int get _stockTotal => _filasInventario.fold(
        0,
        (suma, f) => suma + (int.tryParse(f.cantidadCtrl.text.trim()) ?? 0),
      );

  @override
  void initState() {
    super.initState();
    _opciones = OpcionesNegocio.porDefecto(widget.categoriaNegocio);
    // Si mandaron datos, llenamos los campos para editar
    _nombreCtrl = TextEditingController(text: widget.productoData?['nombre'] ?? '');
    _precioCtrl = TextEditingController(text: widget.productoData?['precio']?.toString() ?? '');
    _costoCtrl = TextEditingController(text: PrecioProducto.campo(widget.productoData?['costo']));
    _descuentoCtrl = TextEditingController(
      text: PrecioProducto.campo(widget.productoData?['precio_descuento']),
    );
    _descCtrl = TextEditingController(text: widget.productoData?['descripcion'] ?? '');
    _ingredientesCtrl = TextEditingController(text: widget.productoData?['ingredientes'] ?? '');
    _codigoBarrasCtrl = TextEditingController(text: widget.productoData?['codigo_barras'] ?? '');
    _gramosCtrl = TextEditingController(text: widget.productoData?['peso_o_contenido'] ?? '');
    _materialCtrl = TextEditingController(text: widget.productoData?['material'] ?? '');
    _piezasCtrl = TextEditingController(
      text: widget.productoData == null
          ? ''
          : NegocioUbicacionService.stockTotal(widget.productoData!).toString(),
    );
    _cotizarWhatsapp = widget.productoData == null
        ? CategoriasNegocio.esImprenta(widget.categoriaNegocio)
        : widget.productoData?['cotizar_whatsapp'] == true;
    _fotoUrlExistente = widget.productoData?['foto_url'];
    _destacado = widget.productoData?['destacado'] == true;
    _requiereReceta = widget.productoData?['requiere_receta'] == true;
    final venceRaw = widget.productoData?['fecha_vencimiento']?.toString();
    if (venceRaw != null && venceRaw.isNotEmpty) {
      _vence = DateTime.tryParse(venceRaw);
    }
    _seccion = widget.productoData == null
        ? ''
        : seccionProducto(widget.productoData!);

    if (widget.productoData != null) {
      _ingredientesSeleccionados.addAll(
        NegocioIngredienteService.listaIngredientes(widget.productoData!),
      );
      for (final u
          in NegocioUbicacionService.ubicacionesProducto(widget.productoData!)) {
        _filasInventario
            .add(_FilaInventario(lugar: u.lugar, cantidad: u.cantidad));
      }
      // Producto guardado explícitamente como "sin código".
      if (widget.productoData!['sin_codigo'] == true) _sinCodigo = true;
    }

    _cargarCatalogoUbicaciones();
    if (_usaIngredientes) _cargarCatalogoIngredientes();
    _cargarOpciones();
  }

  Future<void> _cargarOpciones() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('negocios')
          .doc(widget.negocioId)
          .get();
      if (!mounted) return;
      setState(() {
        _opciones = OpcionesNegocio.desde(widget.categoriaNegocio, doc.data());
      });
      if (_opciones.stock) _cargarCatalogoUbicaciones();
    } catch (_) {}
  }

  void _preservarScroll(VoidCallback actualizar) {
    final offset = _scrollCtrl.hasClients ? _scrollCtrl.offset : 0.0;
    setState(actualizar);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(offset.clamp(0.0, _scrollCtrl.position.maxScrollExtent));
      }
    });
  }

  Future<void> _cargarCatalogoIngredientes() async {
    try {
      final cat = await NegocioIngredienteService.obtener(widget.negocioId);
      if (mounted) {
        setState(() {
          _catalogoIngredientes = cat;
          _cargandoIngredientes = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoIngredientes = false);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _materialCtrl.dispose();
    _piezasCtrl.dispose();
    _costoCtrl.dispose();
    _descuentoCtrl.dispose();
    for (final f in _filasInventario) {
      f.cantidadCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarCatalogoUbicaciones() async {
    if (!_esProductos) return;
    try {
      final cat = await NegocioUbicacionService.obtener(widget.negocioId);
      if (mounted) setState(() => _catalogoUbicaciones = cat);
    } catch (_) {}
  }

  void _generarCodigoInterno() {
    final codigo = 'INT-${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _codigoBarrasCtrl.text = codigo;
      _sinCodigo = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Código interno generado: $codigo. '
            'Imprime una etiqueta con este código para escanearlo.'),
        backgroundColor: Colors.indigo,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _agregarIngredienteRapido() async {
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController();

    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo ingrediente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre (ej. Tomate, Queso extra)',
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
                helperText: 'Si el cliente lo pide como extra. Déjalo vacío si es gratis.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (nombreCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (guardado != true) return;

    final nuevo = nombreCtrl.text.trim();
    final precioExtra = double.tryParse(precioCtrl.text.trim()) ?? 0;
    if (nuevo.isEmpty) return;

    try {
      await NegocioIngredienteService.agregar(
        widget.negocioId,
        nuevo,
        precioExtra: precioExtra,
      );
      if (mounted) {
        _preservarScroll(() {
          _ingredientesSeleccionados.add(nuevo);
          if (!_catalogoIngredientes.any((e) => e.nombre == nuevo)) {
            _catalogoIngredientes = [
              ..._catalogoIngredientes,
              NegocioIngrediente(id: '', nombre: nuevo, precioExtra: precioExtra),
            ]..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _mostrarOpcionesImagen() async {
    final bytes = await MobileImageUtils.elegirYRecortar(
      context: context,
      cropTitle: 'Recortar producto',
    );
    if (bytes == null || !mounted) return;
    setState(() {
      _imagenBytes = bytes;
      _fotoUrlExistente = null;
    });
  }

  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imagenBytes == null && _fotoUrlExistente == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, agrega una foto del producto', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);

    try {
      String fotoFinal = _fotoUrlExistente ?? '';

      // Si subió una foto nueva, la guardamos
      if (_imagenBytes != null) {
        final String fileName = 'productos/${widget.negocioId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final Reference ref = FirebaseStorage.instance.ref().child(fileName);
        final UploadTask uploadTask = ref.putData(_imagenBytes!, SettableMetadata(contentType: 'image/jpeg'));
        fotoFinal = await (await uploadTask).ref.getDownloadURL();
      }

      Map<String, dynamic> datosExtras = {};
      if (_usaIngredientes) {
        datosExtras = {
          'ingredientes': _ingredientesCtrl.text.trim(),
          'ingredientes_lista': _ingredientesSeleccionados.toList(),
        };
      } else if (_esProductos) {
        final List<StockUbicacion> ubicaciones;
        if (_opciones.repisas) {
          ubicaciones = _filasInventario
              .where((f) =>
                  (f.lugar ?? '').isNotEmpty &&
                  (int.tryParse(f.cantidadCtrl.text.trim()) ?? 0) > 0)
              .map((f) => StockUbicacion(
                    lugar: f.lugar!,
                    cantidad: int.tryParse(f.cantidadCtrl.text.trim()) ?? 0,
                  ))
              .toList();
        } else {
          final n = int.tryParse(_piezasCtrl.text.trim()) ?? 0;
          ubicaciones = [StockUbicacion(lugar: 'General', cantidad: n)];
        }
        datosExtras = {
          'codigo_barras': _sinCodigo ? '' : _codigoBarrasCtrl.text.trim(),
          'sin_codigo': _sinCodigo,
          'peso_o_contenido': _gramosCtrl.text.trim(),
          'controla_inventario': true,
          'ubicaciones': ubicaciones.map((u) => u.toMap()).toList(),
          'stock_total': NegocioUbicacionService.sumarCantidades(ubicaciones),
        };
      } else if (_gramosCtrl.text.trim().isNotEmpty) {
        datosExtras = {
          'peso_o_contenido': _gramosCtrl.text.trim(),
          'controla_inventario': false,
        };
      }

      Map<String, dynamic> datosProducto = {
        'negocio_id': widget.negocioId,
        'nombre': _nombreCtrl.text.trim(),
        'precio': _esBodega ? 0.0 : (double.tryParse(_precioCtrl.text.trim()) ?? 0.0),
        ..._preciosEspeciales(),
        'descripcion': _descCtrl.text.trim(),
        'foto_url': fotoFinal,
        'destacado': _destacado,
        'seccion': _seccion.trim(),
        'categoria_negocio': widget.categoriaNegocio,
        ...datosExtras,
      };

      if (_esImprenta) {
        datosProducto['material'] = _materialCtrl.text.trim();
        datosProducto['cotizar_whatsapp'] = _cotizarWhatsapp;
        if (_cotizarWhatsapp && (datosProducto['precio'] as num) == 0) {
          datosProducto['precio'] = double.tryParse(_precioCtrl.text.trim()) ?? 0.0;
        }
      }

      if (_esFarmacia) {
        datosProducto['requiere_receta'] = _requiereReceta;
        if (_vence != null) {
          final d = _vence!;
          datosProducto['fecha_vencimiento'] =
              '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        } else if (widget.productoId != null) {
          datosProducto['fecha_vencimiento'] = FieldValue.delete();
        }
      }

      if (widget.productoId == null) {
        // CREAR NUEVO
        datosProducto['fecha_creacion'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('productos').add(datosProducto);
      } else {
        // ACTUALIZAR EXISTENTE
        await FirebaseFirestore.instance.collection('productos').doc(widget.productoId).update(datosProducto);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Producto guardado con éxito!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- Escaneo de código de barras ----------------

  Future<void> _escanearCodigo() async {
    final codigo = await EscanerCodigoScreen.escanear(
      context,
      titulo: 'Escanear producto',
    );
    if (codigo == null || codigo.isEmpty || !mounted) return;
    setState(() => _codigoBarrasCtrl.text = codigo);
    await _revisarCodigoExistente(codigo);
  }

  /// Busca si ya existe un producto con ese código en el mismo negocio.
  Future<void> _revisarCodigoExistente(String codigo) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('productos')
          .where('negocio_id', isEqualTo: widget.negocioId)
          .where('codigo_barras', isEqualTo: codigo)
          .get();

      final docs = snap.docs
          .where((d) => d.id != widget.productoId)
          .toList();

      if (!mounted) return;
      if (docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Código nuevo. Continúa registrando el producto.'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      await _mostrarDialogoProductoExistente(docs.first);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo verificar el código: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _mostrarDialogoProductoExistente(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final ok = await AgregarStockProductoDialog.mostrar(
      context,
      negocioId: widget.negocioId,
      productoDoc: doc,
      catalogoUbicaciones: _catalogoUbicaciones,
    );
    if (!mounted || !ok) return;
    Navigator.pop(context);
  }

  // ---------------- Sección de inventario / ubicaciones ----------------

  Future<void> _agregarUbicacionRapida() async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva ubicación'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Ej. Repisa A2, Bodega',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty) return;
    try {
      await NegocioUbicacionService.agregar(widget.negocioId, nombre);
    } catch (_) {}
    await _cargarCatalogoUbicaciones();
  }

  List<Widget> _seccionInventario() {
    final nombres = <String>{..._catalogoUbicaciones.map((e) => e.nombre)};
    for (final f in _filasInventario) {
      if (f.lugar != null && f.lugar!.isNotEmpty) nombres.add(f.lugar!);
    }
    final items = nombres.toList()..sort();

    return [
      const Divider(),
      const Text(
        'Código de barras',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Este producto no tiene código de barras'),
        subtitle: const Text(
          'Si lo activas, no se pedirá código. Igual puedes generar uno interno '
          'para imprimir etiqueta y escanearlo.',
          style: TextStyle(fontSize: 12),
        ),
        value: _sinCodigo,
        onChanged: (v) => setState(() => _sinCodigo = v),
      ),
      if (!_sinCodigo) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _codigoBarrasCtrl,
                textInputAction: TextInputAction.search,
                validator: (val) {
                  if (_sinCodigo) return null;
                  if ((val ?? '').trim().isEmpty) {
                    return 'Escanéalo, escríbelo o genera uno interno';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Código / número de parte',
                  hintText: 'Escanéalo o escríbelo',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.qr_code),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.indigo),
                    tooltip: 'Buscar este código',
                    onPressed: () {
                      final codigo = _codigoBarrasCtrl.text.trim();
                      if (codigo.isNotEmpty) _revisarCodigoExistente(codigo);
                    },
                  ),
                ),
                onFieldSubmitted: (val) {
                  final codigo = val.trim();
                  if (codigo.isNotEmpty) _revisarCodigoExistente(codigo);
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                onPressed: _escanearCodigo,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Escanear'),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _generarCodigoInterno,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Generar código interno'),
          ),
        ),
      ],
      const SizedBox(height: 8),
      TextFormField(
        controller: _gramosCtrl,
        decoration: InputDecoration(
          labelText: _esImprenta ? 'Medida (opcional)' : 'Presentación / medida (opcional)',
          hintText: _esImprenta ? 'Ej. 2 x 1 m, carta, talla M' : 'Ej. 600 ml, 1 L, paquete',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.straighten),
        ),
      ),
      const SizedBox(height: 20),
      if (!_opciones.repisas)
        TextFormField(
          controller: _piezasCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Piezas en existencia',
            hintText: 'Cuántas hay, sin anotar la repisa',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
        )
      else ...[
      Row(
        children: [
          const Expanded(
            child: Text(
              'Dónde está y cuántas piezas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UbicacionesNegocioScreen(
                    negocioId: widget.negocioId,
                    nombreNegocio: _nombreCtrl.text,
                  ),
                ),
              ).then((_) => _cargarCatalogoUbicaciones());
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Repisas'),
          ),
        ],
      ),
      const Text(
        'Indica en qué repisa está y cuántas piezas hay. '
        'Si este local no usa repisas, el administrador puede apagarlas.',
        style: TextStyle(fontSize: 13, color: Colors.grey),
      ),
      const SizedBox(height: 10),
      ..._filasInventario.asMap().entries.map((entry) {
        final i = entry.key;
        final fila = entry.value;
        final valor = items.contains(fila.lugar) ? fila.lugar : null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: valor,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Ubicación',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: items
                      .map((n) =>
                          DropdownMenuItem(value: n, child: Text(n)))
                      .toList(),
                  onChanged: (v) => setState(() => fila.lugar = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: fila.cantidadCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'Piezas',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent),
                onPressed: () => setState(() {
                  fila.cantidadCtrl.dispose();
                  _filasInventario.removeAt(i);
                }),
              ),
            ],
          ),
        );
      }),
      Row(
        children: [
          TextButton.icon(
            onPressed: () => setState(
                () => _filasInventario.add(_FilaInventario(cantidad: 1))),
            icon: const Icon(Icons.add),
            label: const Text('Agregar ubicación'),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: _agregarUbicacionRapida,
            icon: const Icon(Icons.add_location_alt, size: 18),
            label: const Text('Nueva repisa'),
          ),
        ],
      ),
      ],
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          _opciones.repisas
              ? 'Total en inventario: $_stockTotal pza(s)'
              : 'Existencia: ${int.tryParse(_piezasCtrl.text.trim()) ?? 0} pza(s)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _seccionIngredientes() {
    return [
      const Divider(),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Ingredientes del platillo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IngredientesNegocioScreen(
                    negocioId: widget.negocioId,
                    nombreNegocio: _nombreCtrl.text,
                  ),
                ),
              );
              if (mounted) _cargarCatalogoIngredientes();
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Administrar'),
          ),
        ],
      ),
      const Text(
        'Marca los que lleva. Así el cliente sabrá qué incluye y podrá pedir quitar alguno.',
        style: TextStyle(fontSize: 13, color: Colors.grey),
      ),
      const SizedBox(height: 10),
      if (_cargandoIngredientes)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator()),
        )
      else ...[
        Builder(builder: (context) {
          final catalogo = _catalogoIngredientes;
          final nombresCatalogo = catalogo.map((e) => e.nombre).toSet();
          final extras = _ingredientesSeleccionados
              .where((e) => !nombresCatalogo.contains(e))
              .toList();

          if (catalogo.isEmpty && extras.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aún no tienes ingredientes registrados.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Agrégalos para poder asignarlos a tus platillos.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _agregarIngredienteRapido,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar ingrediente'),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ...catalogo.map((ing) {
                    final seleccionado =
                        _ingredientesSeleccionados.contains(ing.nombre);
                    return FilterChip(
                      label: Text(ing.nombre),
                      selected: seleccionado,
                      selectedColor: Colors.green.shade100,
                      checkmarkColor: Colors.green.shade800,
                      onSelected: (val) {
                        _preservarScroll(() {
                          if (val) {
                            _ingredientesSeleccionados.add(ing.nombre);
                          } else {
                            _ingredientesSeleccionados.remove(ing.nombre);
                          }
                        });
                      },
                    );
                  }),
                  ...extras.map((nombre) {
                    return FilterChip(
                      label: Text(nombre),
                      selected: true,
                      selectedColor: Colors.green.shade100,
                      checkmarkColor: Colors.green.shade800,
                      onSelected: (val) {
                        _preservarScroll(() {
                          if (!val) _ingredientesSeleccionados.remove(nombre);
                        });
                      },
                    );
                  }),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo'),
                    onPressed: _agregarIngredienteRapido,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ingredientesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Otras notas de ingredientes (opcional)',
                  hintText: 'Ej. salsa especial de la casa',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          );
        }),
      ],
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _seccionImprenta() {
    return [
      const Divider(),
      const Text(
        'Trabajo de imprenta',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      const SizedBox(height: 4),
      const Text(
        'Secciones útiles: Lonas, Stickers, Uniformes, Gorras, Bordados.',
        style: TextStyle(fontSize: 13, color: Colors.grey),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _materialCtrl,
        decoration: const InputDecoration(
          labelText: 'Material (opcional)',
          hintText: 'Ej. lona, vinil, algodón, bordado',
          border: OutlineInputBorder(),
        ),
      ),
      if (!_opciones.stock) ...[
        const SizedBox(height: 12),
        TextFormField(
          controller: _gramosCtrl,
          decoration: const InputDecoration(
            labelText: 'Medida (opcional)',
            hintText: 'Ej. 2 x 1 m, carta, talla M',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.straighten),
          ),
        ),
      ],
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Se cotiza por WhatsApp'),
        subtitle: const Text('El cliente puede escribir para un diseño o una medida distinta'),
        value: _cotizarWhatsapp,
        activeThumbColor: Colors.green.shade700,
        secondary: Icon(Icons.chat, color: Colors.green.shade700),
        onChanged: (v) => setState(() => _cotizarWhatsapp = v),
      ),
    ];
  }

  String _fechaLegible(DateTime d) => '${d.day}/${d.month}/${d.year}';

  List<Widget> _seccionFarmacia() {
    final vence = _vence;
    final vencido = vence != null &&
        DateTime(vence.year, vence.month, vence.day)
            .isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
    return [
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Requiere receta'),
        subtitle: const Text('El cliente y el mostrador ven el aviso antes de despachar'),
        value: _requiereReceta,
        activeThumbColor: Colors.teal.shade700,
        secondary: Icon(Icons.assignment_outlined, color: Colors.teal.shade700),
        onChanged: (v) => setState(() => _requiereReceta = v),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          Icons.event_busy,
          color: vencido ? Colors.red.shade700 : Colors.teal.shade700,
        ),
        title: Text(vence == null ? 'Sin fecha de vencimiento' : 'Vence el ${_fechaLegible(vence)}'),
        subtitle: Text(
          vencido ? 'Esta fecha ya pasó' : 'Opcional. Sirve para no despachar lotes vencidos.',
          style: TextStyle(color: vencido ? Colors.red.shade700 : null),
        ),
        trailing: vence == null
            ? null
            : IconButton(
                tooltip: 'Quitar fecha',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _vence = null),
              ),
        onTap: () async {
          final hoy = DateTime.now();
          final elegida = await showDatePicker(
            context: context,
            initialDate: vence ?? hoy,
            firstDate: DateTime(hoy.year - 1),
            lastDate: DateTime(hoy.year + 8),
            helpText: 'Fecha de vencimiento',
          );
          if (elegida != null) setState(() => _vence = elegida);
        },
      ),
    ];
  }

  Map<String, dynamic> _preciosEspeciales() {
    if (_esBodega || !_opciones.clientesDescuento) return const {};
    final datos = <String, dynamic>{};
    final costo = double.tryParse(_costoCtrl.text.trim());
    final desc = double.tryParse(_descuentoCtrl.text.trim());
    if (costo != null && costo > 0) {
      datos['costo'] = costo;
    } else if (widget.productoId != null) {
      datos['costo'] = FieldValue.delete();
    }
    if (desc != null && desc > 0) {
      datos['precio_descuento'] = desc;
    } else if (widget.productoId != null) {
      datos['precio_descuento'] = FieldValue.delete();
    }
    return datos;
  }

  String? _validarMontoOpcional(String? val, {required bool esDescuento}) {
    final t = (val ?? '').trim();
    if (t.isEmpty) return null;
    final n = double.tryParse(t);
    if (n == null || n < 0) return 'Monto inválido';
    if (esDescuento && n <= 0) return 'Escribe el precio o déjalo vacío';
    if (esDescuento) {
      final venta = double.tryParse(_precioCtrl.text.trim()) ?? 0;
      if (venta > 0 && n > venta) return 'Debe ser menor o igual al de venta';
    }
    return null;
  }

  List<Widget> _camposPrecio() {
    if (_esBodega) return const [];
    if (!_opciones.clientesDescuento) {
      return [
        const SizedBox(height: 12),
        TextFormField(
          controller: _precioCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _cotizarWhatsapp ? 'Precio (\$) — 0 si solo se cotiza' : 'Precio (\$)',
            border: const OutlineInputBorder(),
          ),
          validator: (val) {
            if ((val ?? '').trim().isEmpty) {
              return _cotizarWhatsapp ? null : 'Requerido';
            }
            return null;
          },
        ),
      ];
    }

    return [
      const SizedBox(height: 12),
      TextFormField(
        controller: _costoCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Costo (\$)',
          helperText: 'Lo que te cuesta. El cliente no lo ve.',
          border: OutlineInputBorder(),
        ),
        validator: (val) => _validarMontoOpcional(val, esDescuento: false),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _precioCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: _cotizarWhatsapp
              ? 'Precio de venta (\$) — 0 si solo se cotiza'
              : 'Precio de venta (\$)',
          helperText: 'Lo que paga un cliente normal.',
          border: const OutlineInputBorder(),
        ),
        validator: (val) {
          if ((val ?? '').trim().isEmpty) {
            return _cotizarWhatsapp ? null : 'Requerido';
          }
          return null;
        },
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _descuentoCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Precio con descuento (\$)',
          helperText: 'Lo que paga un cliente con descuento. Vacío si no aplica.',
          border: OutlineInputBorder(),
        ),
        validator: (val) => _validarMontoOpcional(val, esDescuento: true),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.productoId == null ? 'Agregar Producto' : 'Editar Producto'), backgroundColor: globals.colorFondo, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _mostrarOpcionesImagen,
                child: SquarePhotoPicker(
                  imageBytes: _imagenBytes,
                  imageUrl: _fotoUrlExistente,
                  emptyChild: const FotoVacia(),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre del producto', border: OutlineInputBorder()), validator: (val) => val!.isEmpty ? 'Requerido' : null),
              ..._camposPrecio(),
              const SizedBox(height: 12),
              TextFormField(controller: _descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Descripción corta', border: OutlineInputBorder())),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Destacar en el menú'),
                subtitle: const Text('Aparece primero en el catálogo y menú del local'),
                value: _destacado,
                activeThumbColor: Colors.amber.shade800,
                secondary: Icon(Icons.star_rounded, color: Colors.amber.shade700),
                onChanged: (v) => setState(() => _destacado = v),
              ),
              const SizedBox(height: 8),
              SelectorSeccion(
                negocioId: widget.negocioId,
                valorInicial: _seccion,
                onChanged: (v) => _seccion = v,
              ),
              const SizedBox(height: 12),
              
              if (_usaIngredientes) ..._seccionIngredientes(),
              if (_esProductos) ..._seccionInventario(),
              if (_esImprenta) ..._seccionImprenta(),
              if (_esFarmacia) ..._seccionFarmacia(),

              const SizedBox(height: 30),
              if (_isLoading) const Center(child: CircularProgressIndicator()) 
              else ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white), 
                onPressed: _guardarProducto, 
                child: Text(widget.productoId == null ? 'Subir Producto' : 'Guardar Cambios', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila editable de inventario: una ubicación y su cantidad.
class _FilaInventario {
  String? lugar;
  final TextEditingController cantidadCtrl;

  _FilaInventario({this.lugar, int cantidad = 1})
      : cantidadCtrl = TextEditingController(text: cantidad.toString());
}