import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:angostura_digital/providers/cart_provider.dart';
import 'package:angostura_digital/screens/carrito_screen.dart'; 
import 'package:angostura_digital/globals.dart' as globals;
import 'package:url_launcher/url_launcher.dart';
import 'package:angostura_digital/widgets/square_image.dart';
import 'package:angostura_digital/utils/tiempo_estimado_utils.dart';
import 'package:angostura_digital/utils/producto_pedido_utils.dart';
import 'package:angostura_digital/services/negocio_ingrediente_service.dart';
import 'package:angostura_digital/services/negocio_ubicacion_service.dart';
import 'package:angostura_digital/utils/comision_app_utils.dart';
import 'package:angostura_digital/utils/categorias_negocio.dart';
import 'package:angostura_digital/widgets/reservar_cita_sheet.dart';

class MenuNegocioScreen extends StatefulWidget {
  final String negocioId;
  final String nombreNegocio;
  final String? fotoUrl;

  /// Trabajador/dueño tomando pedido en el local (sin envío ni datos del cliente en app).
  final bool modoTrabajador;
  final String? categoriaNegocio;

  const MenuNegocioScreen({
    super.key, 
    required this.negocioId, 
    required this.nombreNegocio,
    this.fotoUrl,
    this.modoTrabajador = false,
    this.categoriaNegocio,
  });

  @override
  State<MenuNegocioScreen> createState() => _MenuNegocioScreenState();
}

class _MenuNegocioScreenState extends State<MenuNegocioScreen> {
  final TextEditingController _busquedaCtrl = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  bool _coincideBusqueda(Map<String, dynamic> data, String q) {
    if (q.isEmpty) return true;
    final nombre = (data['nombre'] ?? '').toString().toLowerCase();
    final desc = (data['descripcion'] ?? '').toString().toLowerCase();
    final codigo = (data['codigo_barras'] ?? '').toString().toLowerCase();
    final ing = NegocioIngredienteService.textoIngredientes(data)?.toLowerCase() ?? '';
    return nombre.contains(q) ||
        desc.contains(q) ||
        codigo.contains(q) ||
        ing.contains(q);
  }

  String? _verificarHorario(Map<String, dynamic>? horario) {
    if (horario == null) return null; 
    final now = DateTime.now();
    final dayStr = now.weekday.toString();
    final todayData = horario[dayStr];
    final minNow = now.hour * 60 + now.minute;

    if (todayData != null && todayData['activo'] == true) {
      final minAbre = int.parse(todayData['abre'].split(':')[0]) * 60 + int.parse(todayData['abre'].split(':')[1]);
      final minCierra = int.parse(todayData['cierra'].split(':')[0]) * 60 + int.parse(todayData['cierra'].split(':')[1]);
      bool isOpen = false;
      if (minCierra > minAbre) isOpen = minNow >= minAbre && minNow < minCierra;
      else isOpen = minNow >= minAbre || minNow < minCierra;
      if (isOpen) return null; 
    }

    for (int i = 0; i <= 7; i++) {
      int checkDay = now.weekday + i;
      if (checkDay > 7) checkDay -= 7;
      final checkData = horario[checkDay.toString()];
      if (checkData != null && checkData['activo'] == true) {
        final minAbre = int.parse(checkData['abre'].split(':')[0]) * 60 + int.parse(checkData['abre'].split(':')[1]);
        String horaBonita = _formatearHora(checkData['abre']);
        if (i == 0) {
          if (minNow < minAbre) return 'Abre hoy $horaBonita'; 
        } else if (i == 1) { return 'Abre mañana $horaBonita';
        } else {
          final dias = ['', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
          return 'Abre el ${dias[checkDay]} $horaBonita';
        }
      }
    }
    return 'Cerrado temporalmente';
  }

  String _formatearHora(String hhmm) {
    final partes = hhmm.split(':');
    int h = int.parse(partes[0]);
    final m = partes[1];
    final ampm = h >= 12 ? 'PM' : 'AM';
    if (h > 12) h -= 12;
    if (h == 0) h = 12;
    return '$h:$m $ampm';
  }

  String _textoUltimoTiempoEstimado(Map<String, dynamic> dataNegocio) {
    return textoUltimoTiempoNegocio(dataNegocio) ?? '';
  }

  Future<void> _abrirMapaGoogle(GeoPoint geo, BuildContext context) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${geo.latitude},${geo.longitude}');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir la app de Mapas')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al abrir el mapa')));
    }
  }

  Widget _infoChip(String texto) { return Padding(padding: const EdgeInsets.only(bottom: 4.0), child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)), child: Text(texto, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500)))); }

  Widget _badgeStock(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.modoTrabajador
              ? CategoriasNegocio.etiquetaVentaEnLocalLargo(widget.categoriaNegocio)
              : widget.nombreNegocio,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      
      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cart, _) {
          if (cart.items.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.shopping_cart),
            label: Text(
              widget.modoTrabajador
                  ? 'Confirmar (\$${cart.total.toStringAsFixed(2)})'
                  : 'Ver Carrito ( \$${cart.total.toStringAsFixed(2)} )',
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CarritoScreen(modoMostrador: widget.modoTrabajador),
                ),
              );
            },
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('negocios').doc(widget.negocioId).snapshots(),
        builder: (context, snapshotNegocio) {
          if (!snapshotNegocio.hasData || !snapshotNegocio.data!.exists) return const Center(child: CircularProgressIndicator());
          
          final dataNegocio = snapshotNegocio.data!.data() as Map<String, dynamic>;
          final estadoNegocio = dataNegocio['estado']?.toString() ?? '';
          if (!widget.modoTrabajador && !ComisionAppUtils.visibleParaClientes(estadoNegocio)) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pause_circle_outline, size: 72, color: Colors.deepPurple.shade300),
                    const SizedBox(height: 16),
                    Text(
                      estadoNegocio == 'pausado'
                          ? 'Este local está pausado temporalmente.'
                          : 'Este local no está disponible en la app.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );
          }
          String? estadoCierre = widget.modoTrabajador
              ? null
              : _verificarHorario(dataNegocio['horario'] as Map<String, dynamic>?);
          bool isAbierto = widget.modoTrabajador || estadoCierre == null;
          final esServiciosNeg =
              CategoriasNegocio.esServicios(dataNegocio['categoria']);
          
          String ubicacion = dataNegocio['ubicacion'] ?? '';
          GeoPoint? ubicacionGeo = dataNegocio['ubicacion_geo'];

          String mensajeTiempo = ''; Color colorTiempo = Colors.grey;
          if (!isAbierto) { mensajeTiempo = '🔴 $estadoCierre'; colorTiempo = Colors.red; } 
          else { mensajeTiempo = '🟢 ABIERTO AHORA • Listos para tu pedido'; colorTiempo = Colors.green; }

          return Column(
            children: [
              if (widget.modoTrabajador)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.indigo.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.point_of_sale, color: Colors.indigo.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Modo mostrador · ${widget.nombreNegocio}',
                          style: TextStyle(
                            color: Colors.indigo.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: !isAbierto ? Colors.red.shade50 : Colors.green.shade50, border: Border(bottom: BorderSide(color: Colors.grey.shade300)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]),
                  child: Row(children: [Icon(!isAbierto ? Icons.lock_clock : Icons.store_mall_directory, color: colorTiempo, size: 20), const SizedBox(width: 8), Expanded(child: Text(mensajeTiempo.toUpperCase(), style: TextStyle(color: colorTiempo, fontWeight: FontWeight.bold, fontSize: 13)))]),
                ),
              
              if (!widget.modoTrabajador && (ubicacion.isNotEmpty || ubicacionGeo != null))
                Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ubicacion.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4), 
                          child: Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.red.shade400, size: 18), 
                              const SizedBox(width: 6), 
                              Expanded(child: Text(ubicacion, style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 14))),
                              
                              // --- BOTÓN DE MAPA AL LADO DEL NOMBRE DE UBICACIÓN ---
                              if (ubicacionGeo != null)
                                TextButton.icon(
                                  icon: const Icon(Icons.map, size: 16, color: Colors.blueAccent),
                                  label: const Text('Ver mapa', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                  onPressed: () => _abrirMapaGoogle(ubicacionGeo, context),
                                )
                            ]
                          )
                        ),
                      if (_textoUltimoTiempoEstimado(dataNegocio).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.timer_outlined, color: Colors.blue.shade700, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _textoUltimoTiempoEstimado(dataNegocio),
                                style: TextStyle(color: Colors.blue.shade900, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.modoTrabajador
                        ? 'Productos'
                        : (CategoriasNegocio.esServicios(dataNegocio['categoria'])
                            ? 'Servicios'
                            : 'Catálogo'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _busquedaCtrl,
                  autofocus: widget.modoTrabajador,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: esServiciosNeg
                        ? 'Buscar servicio...'
                        : 'Buscar platillo, producto o código...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _busqueda.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _busquedaCtrl.clear();
                              setState(() => _busqueda = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
                ),
              ),
              
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('productos').where('negocio_id', isEqualTo: widget.negocioId).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    final todos = snapshot.data?.docs ?? [];
                    final productos = todos.where((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final esServ = d['es_servicio'] == true;
                      return esServiciosNeg ? esServ : !esServ;
                    }).toList();
                    if (productos.isEmpty) {
                      return Center(
                        child: Text(
                          esServiciosNeg
                              ? 'Aún no hay servicios publicados.'
                              : 'Este local aún no ha subido productos.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    final visibles = _busqueda.isEmpty
                        ? productos
                        : productos.where((doc) {
                            final d = doc.data() as Map<String, dynamic>;
                            return _coincideBusqueda(d, _busqueda);
                          }).toList();

                    if (visibles.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'Sin resultados para «$_busqueda»',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  _busquedaCtrl.clear();
                                  setState(() => _busqueda = '');
                                },
                                icon: const Icon(Icons.clear),
                                label: const Text('Limpiar búsqueda'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      key: PageStorageKey<String>('menu_scroll_${widget.negocioId}'),
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                      child: Center(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            double maxW = constraints.maxWidth; if (maxW.isInfinite || maxW <= 0) maxW = MediaQuery.of(context).size.width - 32;
                            int crossAxisCount = (maxW / 180).ceil(); if (crossAxisCount < 2) crossAxisCount = 2; 
                            final double spacing = 12; final double totalSpacing = spacing * (crossAxisCount - 1); final double itemWidth = (maxW - totalSpacing) / crossAxisCount;

                            return Wrap(
                              spacing: spacing, runSpacing: spacing,
                              children: visibles.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                String? prodFoto = data['foto_url'];

                                List<Widget> extraWidgets = [];
                                final esServicio = data['es_servicio'] == true;
                                final tipoServ =
                                    data['tipo_servicio']?.toString() ?? 'cita';

                                if (esServicio) {
                                  extraWidgets.add(_infoChip(
                                    tipoServ == 'cita'
                                        ? '📅 Con cita (elige hora)'
                                        : '🏠 Solicitud a domicilio',
                                  ));
                                  final dur = (data['duracion_minutos'] as num?)?.toInt();
                                  if (tipoServ == 'cita' && dur != null && dur > 0) {
                                    extraWidgets.add(_infoChip('$dur min'));
                                  }
                                } else {
                                  final textoIngredientes =
                                      NegocioIngredienteService.textoIngredientes(data);
                                  if (textoIngredientes != null) {
                                    extraWidgets.add(
                                        _infoChip('Ingredientes: $textoIngredientes'));
                                  }
                                  if (data['peso_o_contenido'] != null &&
                                      data['peso_o_contenido'].toString().isNotEmpty) {
                                    extraWidgets.add(
                                        _infoChip('Cont: ${data['peso_o_contenido']}'));
                                  }
                                }

                                final controlaInventario =
                                    !esServicio && data['controla_inventario'] == true;
                                final stock = NegocioUbicacionService.stockTotal(data);
                                final agotado = controlaInventario && stock <= 0;
                                final pocas =
                                    controlaInventario && stock > 0 && stock <= 5;

                                return SizedBox(
                                  width: itemWidth > 0 ? itemWidth : 150,
                                  child: Card(
                                    elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, 
                                      children: [
                                        SquareImage(
                                          imageUrl: prodFoto,
                                          color: !isAbierto ? Colors.black.withOpacity(0.5) : null,
                                          colorBlendMode: !isAbierto ? BlendMode.saturation : null,
                                          placeholder: Container(color: Colors.grey.shade200, child: const Icon(Icons.fastfood, color: Colors.grey, size: 50)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(data['nombre'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.15, color: !isAbierto ? Colors.grey : Colors.black87)),
                                              const SizedBox(height: 6), Text('\$${data['precio']}', style: TextStyle(color: !isAbierto ? Colors.grey : Colors.green, fontWeight: FontWeight.bold, fontSize: 17)),
                                              if (data['descripcion'] != null && data['descripcion'].toString().isNotEmpty) ...[const SizedBox(height: 6), Text(data['descripcion'], style: TextStyle(fontSize: 13, color: Colors.grey.shade800))],
                                              if (extraWidgets.isNotEmpty) ...[const SizedBox(height: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: extraWidgets)],
                                              if (agotado) ...[const SizedBox(height: 8), _badgeStock('Agotado', Colors.red)],
                                              if (pocas) ...[const SizedBox(height: 8), _badgeStock('¡Solo quedan $stock!', Colors.orange.shade800)],
                                              const SizedBox(height: 12),
                                              
                                              if (isAbierto && !agotado)
                                                Align(
                                                  alignment: Alignment.bottomRight,
                                                  child: GestureDetector(
                                                    onTap: () => _agregarItem(
                                                      context,
                                                      negocioId: widget.negocioId,
                                                      docId: doc.id,
                                                      data: data,
                                                      foto: prodFoto,
                                                      dataNegocio: dataNegocio,
                                                      controlaInventario: controlaInventario,
                                                      stock: stock,
                                                    ),
                                                    child: Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: esServicio
                                                            ? Colors.deepPurple
                                                            : Colors.blueAccent,
                                                        borderRadius:
                                                            BorderRadius.circular(10),
                                                      ),
                                                      child: Icon(
                                                        esServicio
                                                            ? (tipoServ == 'cita'
                                                                ? Icons.event
                                                                : Icons.send)
                                                            : Icons.add,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  static Future<void> _agregarItem(
    BuildContext context, {
    required String negocioId,
    required String docId,
    required Map<String, dynamic> data,
    required String? foto,
    required Map<String, dynamic> dataNegocio,
    required bool controlaInventario,
    required int stock,
  }) async {
    final cart = context.read<CartProvider>();
    final esServicio = data['es_servicio'] == true;

    if (!esServicio) {
      if (controlaInventario && cart.cantidadEnCarrito(docId) >= stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Solo hay $stock disponible(s) de ${data['nombre']}.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final exito = cart.agregarProducto(
        negocioId,
        docId,
        data['nombre'] ?? '',
        (data['precio'] ?? 0).toDouble(),
        foto,
        detalles: ProductoPedidoUtils.detallesDesdeFirestore(data),
        ingredientesBase: NegocioIngredienteService.listaIngredientes(data),
        stockDisponible: controlaInventario ? stock : null,
      );
      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${data['nombre']} agregado 🛒',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            duration: const Duration(milliseconds: 800),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _mostrarAlertaCarrito(context, cart, negocioId, docId, data, foto);
      }
      return;
    }

    final tipo = data['tipo_servicio']?.toString() ?? 'cita';
    final duracion = (data['duracion_minutos'] as num?)?.toInt() ?? 30;

    if (tipo == 'cita') {
      final reservada = await ReservarCitaSheet.mostrar(
        context,
        negocioId: negocioId,
        servicioId: docId,
        servicioNombre: data['nombre']?.toString() ?? 'Servicio',
        precio: (data['precio'] ?? 0).toDouble(),
        fotoUrl: foto,
        duracionMinutos: duracion,
        datosNegocio: dataNegocio,
      );
      if (!context.mounted || !reservada) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cita reservada. El negocio la confirmará pronto. Revísala en Pedidos.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      final exito = cart.agregarServicio(
        negocioId,
        docId,
        data['nombre'] ?? '',
        (data['precio'] ?? 0).toDouble(),
        foto,
        tipoServicio: 'solicitud',
      );
      if (!context.mounted) return;
      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${data['nombre']} agregado. Indica tu ubicación en el carrito.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _mostrarAlertaCarritoServicio(context, cart, negocioId, docId, data, foto,
            tipoServicio: 'solicitud');
      }
    }
  }

  static void _mostrarAlertaCarritoServicio(
    BuildContext context,
    CartProvider cart,
    String negocioId,
    String servicioId,
    Map<String, dynamic> data,
    String? foto, {
    required String tipoServicio,
    DateTime? citaInicio,
    int duracionMinutos = 30,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Carrito de otro negocio'),
        content: const Text(
          'Solo puedes pedir de un negocio a la vez. ¿Vaciar el carrito y continuar aquí?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              cart.limpiarCarrito();
              if (tipoServicio == 'cita' && citaInicio != null) {
                cart.agregarServicio(
                  negocioId,
                  servicioId,
                  data['nombre'] ?? '',
                  (data['precio'] ?? 0).toDouble(),
                  foto,
                  tipoServicio: 'cita',
                  citaInicio: citaInicio,
                  duracionMinutos: duracionMinutos,
                );
              } else {
                cart.agregarServicio(
                  negocioId,
                  servicioId,
                  data['nombre'] ?? '',
                  (data['precio'] ?? 0).toDouble(),
                  foto,
                  tipoServicio: 'solicitud',
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Sí, vaciar y agregar'),
          ),
        ],
      ),
    );
  }

  static void _mostrarAlertaCarrito(
    BuildContext context,
    CartProvider cart,
    String negocioId,
    String prodId,
    Map<String, dynamic> data,
    String? foto,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Carrito Ocupado', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Tu carrito tiene productos de otro negocio. Solo puedes pedir de un local a la vez.\n\n'
          '¿Vaciar el carrito y agregar aquí?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              cart.limpiarCarrito();
              cart.agregarProducto(
                negocioId,
                prodId,
                data['nombre'] ?? '',
                (data['precio'] ?? 0).toDouble(),
                foto,
                detalles: ProductoPedidoUtils.detallesDesdeFirestore(data),
                ingredientesBase: NegocioIngredienteService.listaIngredientes(data),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Carrito vaciado. Producto agregado.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Sí, vaciar y agregar'),
          ),
        ],
      ),
    );
  }
}