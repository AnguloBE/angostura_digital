import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/utils/mobile_image_utils.dart';
import 'package:angostura_digital/widgets/square_image.dart';
import 'package:angostura_digital/services/negocio_ingrediente_service.dart';
import 'package:angostura_digital/services/negocio_ubicacion_service.dart';
import 'package:angostura_digital/screens/ingredientes_negocio_screen.dart';
import 'package:angostura_digital/screens/ubicaciones_negocio_screen.dart';
import 'package:angostura_digital/screens/escaner_codigo_screen.dart';
import 'package:angostura_digital/utils/categorias_negocio.dart';

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
  late TextEditingController _descCtrl;
  late TextEditingController _ingredientesCtrl; 
  late TextEditingController _codigoBarrasCtrl; 
  late TextEditingController _gramosCtrl; 

  String? _fotoUrlExistente;
  Uint8List? _imagenBytes;

  // Ingredientes seleccionados del catálogo del negocio para este platillo.
  final Set<String> _ingredientesSeleccionados = {};

  // Inventario por ubicación (solo negocios de productos).
  List<NegocioUbicacion> _catalogoUbicaciones = [];
  final List<_FilaInventario> _filasInventario = [];

  // Si el producto no tiene código de barras (no se pide ni se exige).
  bool _sinCodigo = false;

  bool get _usaIngredientes =>
      NegocioIngredienteService.usaIngredientes(widget.categoriaNegocio);

  bool get _esProductos =>
      CategoriasNegocio.esProductos(widget.categoriaNegocio) &&
      !_usaIngredientes;

  int get _stockTotal => _filasInventario.fold(
        0,
        (suma, f) => suma + (int.tryParse(f.cantidadCtrl.text.trim()) ?? 0),
      );

  @override
  void initState() {
    super.initState();
    // Si mandaron datos, llenamos los campos para editar
    _nombreCtrl = TextEditingController(text: widget.productoData?['nombre'] ?? '');
    _precioCtrl = TextEditingController(text: widget.productoData?['precio']?.toString() ?? '');
    _descCtrl = TextEditingController(text: widget.productoData?['descripcion'] ?? '');
    _ingredientesCtrl = TextEditingController(text: widget.productoData?['ingredientes'] ?? '');
    _codigoBarrasCtrl = TextEditingController(text: widget.productoData?['codigo_barras'] ?? '');
    _gramosCtrl = TextEditingController(text: widget.productoData?['peso_o_contenido'] ?? '');
    _fotoUrlExistente = widget.productoData?['foto_url'];

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
  }

  @override
  void dispose() {
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
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo ingrediente'),
        content: TextField(
          controller: nombreCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre (ej. Tomate)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nombreCtrl.text.trim()),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (nuevo == null || nuevo.isEmpty) return;
    try {
      await NegocioIngredienteService.agregar(widget.negocioId, nuevo);
      if (mounted) setState(() => _ingredientesSeleccionados.add(nuevo));
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

  Future<void> _seleccionarYRecortarImagen(ImageSource source) async {
    final bytes = await MobileImageUtils.pickCropAndReadBytes(
      context: context,
      source: source,
      cropTitle: 'Recortar producto',
    );
    if (bytes == null) return;
    setState(() {
      _imagenBytes = bytes;
      _fotoUrlExistente = null;
    });
  }

  void _mostrarOpcionesImagen() {
    MobileImageUtils.showImageSourcePicker(
      context,
      onSelected: _seleccionarYRecortarImagen,
    );
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
        final ubicaciones = _filasInventario
            .where((f) =>
                (f.lugar ?? '').isNotEmpty &&
                (int.tryParse(f.cantidadCtrl.text.trim()) ?? 0) > 0)
            .map((f) => StockUbicacion(
                  lugar: f.lugar!,
                  cantidad: int.tryParse(f.cantidadCtrl.text.trim()) ?? 0,
                ))
            .toList();
        datosExtras = {
          'codigo_barras': _sinCodigo ? '' : _codigoBarrasCtrl.text.trim(),
          'sin_codigo': _sinCodigo,
          'peso_o_contenido': _gramosCtrl.text.trim(),
          'controla_inventario': true,
          'ubicaciones': ubicaciones.map((u) => u.toMap()).toList(),
          'stock_total': NegocioUbicacionService.sumarCantidades(ubicaciones),
        };
      }

      Map<String, dynamic> datosProducto = {
        'negocio_id': widget.negocioId,
        'nombre': _nombreCtrl.text.trim(),
        'precio': double.tryParse(_precioCtrl.text.trim()) ?? 0.0,
        'descripcion': _descCtrl.text.trim(),
        'foto_url': fotoFinal,
        'categoria_negocio': widget.categoriaNegocio,
        ...datosExtras,
      };

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
    final data = doc.data();
    final nombre = (data['nombre'] ?? 'Producto').toString();
    final ubicacionesTexto =
        NegocioUbicacionService.textoUbicaciones(data) ?? 'Sin ubicación registrada';
    final stock = NegocioUbicacionService.stockTotal(data);

    final cantidadCtrl = TextEditingController(text: '1');
    final ubicActuales = NegocioUbicacionService.ubicacionesProducto(data);
    String? lugarSel = ubicActuales.isNotEmpty ? ubicActuales.first.lugar : null;

    final nombresCatalogo = <String>{
      ..._catalogoUbicaciones.map((e) => e.nombre),
      ...NegocioUbicacionService.ubicacionesProducto(data).map((u) => u.lugar),
    }.toList()
      ..sort();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('⚠️ Este producto ya existe'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text('En existencia: $stock pza(s)',
                    style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 4),
                Text('Ubicación: $ubicacionesTexto',
                    style: const TextStyle(color: Colors.indigo)),
                const Divider(height: 24),
                const Text('¿Cuántas piezas vas a agregar y en qué ubicación?',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue:
                      nombresCatalogo.contains(lugarSel) ? lugarSel : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Ubicación',
                    border: OutlineInputBorder(),
                  ),
                  items: nombresCatalogo
                      .map((n) =>
                          DropdownMenuItem(value: n, child: Text(n)))
                      .toList(),
                  onChanged: (v) => setDialog(() => lugarSel = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cantidadCtrl,
                  keyboardType: TextInputType.number,
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final cantidad = int.tryParse(cantidadCtrl.text.trim()) ?? 0;
                if (lugarSel == null || lugarSel!.isEmpty || cantidad <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Elige ubicación y una cantidad válida.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                await _agregarStockAProducto(doc, lugarSel!, cantidad);
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                        'Se agregaron $cantidad pza(s) a "$nombre" en $lugarSel.'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('Agregar al inventario'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _agregarStockAProducto(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String lugar,
    int cantidad,
  ) async {
    final data = doc.data();
    final actuales = NegocioUbicacionService.ubicacionesProducto(data);
    final nuevas = [...actuales];
    final idx = nuevas
        .indexWhere((u) => u.lugar.toLowerCase() == lugar.toLowerCase());
    if (idx >= 0) {
      nuevas[idx] = nuevas[idx].copyWith(cantidad: nuevas[idx].cantidad + cantidad);
    } else {
      nuevas.add(StockUbicacion(lugar: lugar, cantidad: cantidad));
    }
    await doc.reference.update({
      'ubicaciones': nuevas.map((u) => u.toMap()).toList(),
      'stock_total': NegocioUbicacionService.sumarCantidades(nuevas),
    });
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
        decoration: const InputDecoration(
          labelText: 'Presentación / medida (opcional)',
          hintText: 'Ej. 600 ml, 1 L, paquete',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.straighten),
        ),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Inventario y ubicaciones',
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
            label: const Text('Administrar'),
          ),
        ],
      ),
      const Text(
        'Indica en qué repisa(s) está y cuántas piezas hay en cada una. '
        'Un mismo producto puede estar en varias ubicaciones.',
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
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          'Total en inventario: $_stockTotal pza(s)',
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IngredientesNegocioScreen(
                    negocioId: widget.negocioId,
                    nombreNegocio: _nombreCtrl.text,
                  ),
                ),
              );
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
      StreamBuilder<List<NegocioIngrediente>>(
        stream: NegocioIngredienteService.stream(widget.negocioId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final catalogo = snapshot.data ?? [];

          // Conservamos ingredientes ya guardados aunque ya no estén en el catálogo.
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
                        setState(() {
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
                        setState(() {
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
        },
      ),
      const SizedBox(height: 8),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.productoId == null ? 'Agregar Producto' : 'Editar Producto'), backgroundColor: globals.colorFondo, foregroundColor: Colors.white),
      body: SingleChildScrollView(
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
                  emptyChild: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                      SizedBox(height: 10),
                      Text('Tocar para agregar foto', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre del producto', border: OutlineInputBorder()), validator: (val) => val!.isEmpty ? 'Requerido' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _precioCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Precio (\$)', border: OutlineInputBorder()), validator: (val) => val!.isEmpty ? 'Requerido' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Descripción corta', border: OutlineInputBorder())),
              const SizedBox(height: 20),
              
              if (_usaIngredientes) ..._seccionIngredientes(),
              if (_esProductos) ..._seccionInventario(),

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