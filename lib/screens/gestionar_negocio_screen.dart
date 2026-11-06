import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/utils/mobile_image_utils.dart';
import 'package:angostura_digital/widgets/square_image.dart';

// --- IMPORTACIONES DE TUS PANTALLAS ---
import 'package:angostura_digital/screens/agregar_producto_screen.dart';
import 'package:angostura_digital/screens/agregar_mercancia_screen.dart';
import 'package:angostura_digital/screens/agregar_cita_whatsapp_screen.dart';
import 'package:angostura_digital/screens/agregar_servicio_screen.dart';
import 'package:angostura_digital/screens/pedidos_negocio_screen.dart';
import 'package:angostura_digital/screens/menu_negocio_screen.dart';
import 'package:angostura_digital/providers/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:angostura_digital/screens/historial_pedidos_negocio_screen.dart';
import 'package:angostura_digital/screens/configurar_envios_screen.dart'; 
import 'package:angostura_digital/screens/mapa_ubicacion_screen.dart';
import 'package:angostura_digital/screens/agregar_promocion_screen.dart';
import 'package:angostura_digital/screens/equipo_negocio_screen.dart';
import 'package:angostura_digital/screens/clientes_descuento_screen.dart';
import 'package:angostura_digital/screens/ingredientes_negocio_screen.dart';
import 'package:angostura_digital/screens/ubicaciones_negocio_screen.dart';
import 'package:angostura_digital/screens/horario_citas_negocio_screen.dart';
import 'package:angostura_digital/services/negocio_ingrediente_service.dart';
import 'package:angostura_digital/services/negocio_ubicacion_service.dart';
import 'package:angostura_digital/utils/categorias_negocio.dart';
import 'package:angostura_digital/utils/opciones_negocio.dart';
import 'package:angostura_digital/utils/encargo_utils.dart';
import 'package:angostura_digital/widgets/aviso_pedidos_negocio.dart';
import 'package:angostura_digital/utils/orden_productos_utils.dart';
import 'package:angostura_digital/utils/producto_busqueda_utils.dart';
import 'package:angostura_digital/utils/cuadricula_ancho.dart';
import 'package:angostura_digital/utils/seccion_producto_utils.dart';
import 'package:angostura_digital/widgets/filtro_secciones.dart';
import 'package:angostura_digital/utils/comision_app_utils.dart';
import 'package:angostura_digital/utils/producto_pedido_utils.dart';
import 'package:angostura_digital/widgets/precio_visible.dart';
import 'package:angostura_digital/services/negocio_equipo_service.dart';
import 'package:angostura_digital/services/notificaciones_service.dart';

class GestionarNegocioScreen extends StatefulWidget {
  final String negocioId;
  final String nombreActual;
  final String categoria;
  final String estadoActual;
  final String? fotoUrlActual;

  const GestionarNegocioScreen({
    super.key,
    required this.negocioId,
    required this.nombreActual,
    required this.categoria,
    required this.estadoActual,
    this.fotoUrlActual,
  });

  @override
  State<GestionarNegocioScreen> createState() => _GestionarNegocioScreenState();
}

class _GestionarNegocioScreenState extends State<GestionarNegocioScreen> {
  late TextEditingController _nombreCtrl;
  late TextEditingController _ubicacionCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _telefonoCtrl;
  final TextEditingController _busquedaCatalogoCtrl = TextEditingController();
  String _busquedaCatalogo = '';
  String _seccionCatalogo = '';
  int _topeCatalogo = 24;
  GeoPoint? _ubicacionGeo; 
  bool _isLoading = false;
  bool _datosCargados = false;
  bool _publicando = false;
  late String _estado;
  late OpcionesNegocio _opciones;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _opcionesSub; 

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.nombreActual);
    _ubicacionCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _telefonoCtrl = TextEditingController();
    _opciones = OpcionesNegocio.porDefecto(widget.categoria);
    _estado = widget.estadoActual;
    _opcionesSub = FirebaseFirestore.instance
        .collection('negocios')
        .doc(widget.negocioId)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      final data = doc.data();
      final estado = data?['estado']?.toString();
      setState(() {
        _opciones = OpcionesNegocio.desde(widget.categoria, data);
        if (estado != null && estado.isNotEmpty) _estado = estado;
      });
    });
    NegocioEquipoService.migrarPropietarioLegacy(widget.negocioId);
    NotificacionesService.refrescarToken();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _ubicacionCtrl.dispose();
    _descCtrl.dispose();
    _telefonoCtrl.dispose();
    _busquedaCatalogoCtrl.dispose();
    _opcionesSub?.cancel();
    super.dispose();
  }

  Future<void> _cambiarVisibilidadPublica(bool publico) async {
    setState(() => _publicando = true);
    try {
      await NegocioEquipoService.cambiarVisibilidadPublica(widget.negocioId, publico);
      if (!mounted) return;
      setState(() => _estado = publico ? ComisionAppUtils.estadoActivo : ComisionAppUtils.estadoPausado);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(publico
              ? 'Negocio público. Ya lo ven los clientes.'
              : 'Negocio en pausa. Los clientes no lo ven.'),
          backgroundColor: publico ? Colors.green : Colors.deepPurple,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar la visibilidad: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _publicando = false);
    }
  }

  bool _coincideBusquedaCatalogo(Map<String, dynamic> data, String q) =>
      coincideBusquedaProducto(data, q);

  void _abrirDetalleProducto(
    String productoId,
    Map<String, dynamic> prod, {
    required bool puedeEditar,
  }) {
    ProductoPedidoUtils.mostrarDetalleCatalogo(
      context,
      productoId: productoId,
      data: prod,
      categoriaNegocio: widget.categoria,
      onEditar: puedeEditar
          ? () {
              if (prod['es_servicio'] == true) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AgregarServicioScreen(
                      negocioId: widget.negocioId,
                      servicioId: productoId,
                      servicioData: prod,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AgregarProductoScreen(
                      negocioId: widget.negocioId,
                      categoriaNegocio: widget.categoria,
                      productoId: productoId,
                      productoData: prod,
                    ),
                  ),
                );
              }
            }
          : null,
      onEliminar: puedeEditar ? () => _eliminarProducto(productoId) : null,
    );
  }

  // --- 1. FUNCIÓN PARA CAMBIAR EL LOGO ---
  Future<void> _cambiarImagen() async {
    final bytes = await MobileImageUtils.elegirYRecortar(
      context: context,
      cropTitle: 'Recortar logo',
      galleryLabel: 'Elegir logo de la galería',
      cameraLabel: 'Tomar foto del logo',
      imageQuality: 80,
    );
    if (bytes == null || !mounted) return;

    try {
      setState(() => _isLoading = true);
      final nombreArchivo =
          '${widget.negocioId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref =
          FirebaseStorage.instance.ref().child('negocios/$nombreArchivo');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final String urlSubida = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('negocios')
          .doc(widget.negocioId)
          .update({'foto_url': urlSubida});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. FUNCIÓN PARA GUARDAR DATOS PRINCIPALES ---
  Future<void> _guardarDatos() async {
    if (_nombreCtrl.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    
    Map<String, dynamic> datosAActualizar = {
      'nombre': _nombreCtrl.text.trim(),
      'ubicacion': _ubicacionCtrl.text.trim(),
      'descripcion': _descCtrl.text.trim(),
      'telefono_contacto': _telefonoCtrl.text.trim(),
    };
    
    if (_ubicacionGeo != null) {
      datosAActualizar['ubicacion_geo'] = _ubicacionGeo;
    }
    
    try {
      await FirebaseFirestore.instance.collection('negocios').doc(widget.negocioId).update(datosAActualizar);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos y ubicación guardados exitosamente 💾'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _eliminarProducto(String productoId) async { 
    final confirmar = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Eliminar Producto'), content: const Text('¿Deseas borrar este producto de tu menú?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar'))]));
    if (confirmar == true) { await FirebaseFirestore.instance.collection('productos').doc(productoId).delete(); }
  }
  
  Future<void> _eliminarPromocion(String promoId) async { 
    final confirmar = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Eliminar Promo'), content: const Text('¿Deseas quitar esta promoción? Ya no saldrá en la pantalla principal.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar'))]));
    if (confirmar == true) { await FirebaseFirestore.instance.collection('promociones').doc(promoId).delete(); }
  }

  Widget _infoChip(String texto) { return Padding(padding: const EdgeInsets.only(bottom: 4.0), child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)), child: Text(texto, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500)))); }

  // --- 4. CONFIGURACIÓN DE HORARIOS ---
  Map<String, dynamic> _horarioPorDefecto() {
    Map<String, dynamic> hor = {};
    for (int i = 1; i <= 7; i++) { hor[i.toString()] = {'activo': true, 'abre': '08:00', 'cierra': '22:00'}; }
    return hor;
  }

  Future<void> _abrirConfiguracionHorario(Map<String, dynamic>? horarioActual) async {
    Map<String, dynamic> horarioMutable = horarioActual != null ? Map<String, dynamic>.from(horarioActual) : _horarioPorDefecto();
    final dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16), height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Configurar Horario', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text('Los clientes no podrán pedir si estás fuera de este horario.', style: TextStyle(color: Colors.grey.shade600)), const Divider(height: 30),
                  Expanded(
                    child: ListView.builder(
                      itemCount: 7,
                      itemBuilder: (context, index) {
                        String diaId = (index + 1).toString(); var configDia = horarioMutable[diaId]; bool isActivo = configDia['activo'] ?? false;
                        return Card(
                          elevation: 1, margin: const EdgeInsets.only(bottom: 12), color: isActivo ? Colors.white : Colors.grey.shade100,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(dias[index], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isActivo ? Colors.black : Colors.grey)), Switch(value: isActivo, activeColor: Colors.green, onChanged: (val) { setModalState(() { horarioMutable[diaId]['activo'] = val; }); })]),
                                if (isActivo) Row(children: [Expanded(child: TextButton.icon(icon: const Icon(Icons.wb_sunny_outlined, size: 18), label: Text('Abre: ${configDia['abre']}'), onPressed: () async { final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(configDia['abre'].split(':')[0]), minute: int.parse(configDia['abre'].split(':')[1]))); if (t != null) setModalState(() { horarioMutable[diaId]['abre'] = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'; }); }, )), Expanded(child: TextButton.icon(icon: const Icon(Icons.nightlight_round, size: 18), label: Text('Cierra: ${configDia['cierra']}'), onPressed: () async { final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(configDia['cierra'].split(':')[0]), minute: int.parse(configDia['cierra'].split(':')[1]))); if (t != null) setModalState(() { horarioMutable[diaId]['cierra'] = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'; }); }, ))])
                                else const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Día de Descanso', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Guardar Horario', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)), onPressed: () async { Navigator.pop(context); await FirebaseFirestore.instance.collection('negocios').doc(widget.negocioId).update({'horario': horarioMutable}); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Horario guardado.'), backgroundColor: Colors.green)); }, ))
                ],
              ),
            );
          }
        );
      }
    );
  }

  Future<void> _abrirHorarioGuardado() async {
    final doc = await FirebaseFirestore.instance.collection('negocios').doc(widget.negocioId).get();
    if (!mounted) return;
    await _abrirConfiguracionHorario(doc.data()?['horario'] as Map<String, dynamic>?);
  }

  void _abrirAgregarCita() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgregarCitaWhatsappScreen(
          negocioId: widget.negocioId,
          nombreNegocio: _nombreVisible,
        ),
      ),
    );
  }

  void _irPedidos({bool encargos = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PedidosNegocioScreen(
          negocioId: widget.negocioId,
          nombreNegocio: _nombreVisible,
          puedeVerHistorial: true,
          categoria: widget.categoria,
          abrirEncargos: encargos,
        ),
      ),
    );
  }

  void _irHistorial() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistorialPedidosNegocioScreen(
          negocioId: widget.negocioId,
          nombreNegocio: _nombreVisible,
          categoria: widget.categoria,
        ),
      ),
    );
  }

  void _irEnvios() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfigurarEnviosScreen(negocioId: widget.negocioId),
      ),
    );
  }

  void _irPromo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgregarPromocionScreen(
          negocioId: widget.negocioId,
          nombreNegocio: _nombreVisible,
        ),
      ),
    );
  }

  void _irIngredientes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IngredientesNegocioScreen(
          negocioId: widget.negocioId,
          nombreNegocio: _nombreVisible,
        ),
      ),
    );
  }

  void _irHorarioCitas() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HorarioCitasNegocioScreen(
          negocioId: widget.negocioId,
          nombreNegocio: _nombreVisible,
        ),
      ),
    );
  }

  void _irUbicaciones() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UbicacionesNegocioScreen(
          negocioId: widget.negocioId,
          nombreNegocio: _nombreVisible,
        ),
      ),
    );
  }

  void _irMercancia() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgregarMercanciaScreen(
          negocioId: widget.negocioId,
          nombreNegocio: _nombreVisible,
        ),
      ),
    );
  }

  void _irClientesDescuento() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientesDescuentoScreen(
          negocioId: widget.negocioId,
          nombreNegocio: _nombreVisible,
        ),
      ),
    );
  }

  void _irEquipo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EquipoNegocioScreen(
          negocioId: widget.negocioId,
          nombreNegocio: _nombreVisible,
        ),
      ),
    );
  }

  void _irVentaLocal() {
    context.read<CartProvider>().iniciarPedidoLocal();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuNegocioScreen(
          negocioId: widget.negocioId,
          nombreNegocio: _nombreVisible,
          modoTrabajador: true,
          categoriaNegocio: widget.categoria,
        ),
      ),
    );
  }

  void _irMenuPublico() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuNegocioScreen(
          negocioId: widget.negocioId,
          nombreNegocio: _nombreVisible,
          categoriaNegocio: widget.categoria,
        ),
      ),
    );
  }

  String get _nombreVisible {
    final escrito = _nombreCtrl.text.trim();
    return escrito.isEmpty ? widget.nombreActual : escrito;
  }

  Future<void> _configurarCobros() async {
    final doc = await FirebaseFirestore.instance.collection('negocios').doc(widget.negocioId).get();
    if (!mounted) return;
    const opciones = ['efectivo', 'tarjeta', 'transferencia'];
    const etiquetas = {
      'efectivo': 'Efectivo',
      'tarjeta': 'Tarjeta (terminal)',
      'transferencia': 'Transferencia',
    };
    final seleccion = ((doc.data()?['metodos_pago'] as List?) ?? const ['efectivo'])
        .map((e) => e.toString())
        .where(opciones.contains)
        .toSet();
    if (seleccion.isEmpty) seleccion.add('efectivo');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Cómo cobras'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'El cliente verá estas opciones al reservar o pedir.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              for (final m in opciones)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: seleccion.contains(m),
                  title: Text(etiquetas[m] ?? m),
                  onChanged: (v) => setDialog(() {
                    if (v == true) {
                      seleccion.add(m);
                    } else if (seleccion.length > 1) {
                      seleccion.remove(m);
                    }
                  }),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await FirebaseFirestore.instance.collection('negocios').doc(widget.negocioId).update({
      'metodos_pago': opciones.where(seleccion.contains).toList(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Formas de cobro guardadas'), backgroundColor: Colors.green),
    );
  }

  List<_AccionPanel> _accionesPanel(AvisoBandeja aviso) {
    final cat = widget.categoria;
    final acciones = <_AccionPanel>[];
    void add(IconData icono, String titulo, VoidCallback onTap, {int aviso = 0, bool urgente = false}) {
      acciones.add(_AccionPanel(
        icono: icono,
        titulo: titulo,
        onTap: onTap,
        aviso: aviso,
        urgente: urgente,
      ));
    }

    if (CategoriasNegocio.esBodega(cat)) {
      add(Icons.receipt_long, 'Salidas', _irPedidos, aviso: aviso.pendientesAhora, urgente: true);
      add(Icons.analytics_outlined, 'Historial', _irHistorial);
      if (_opciones.repisas) add(Icons.shelves, 'Repisas', _irUbicaciones);
      if (_opciones.stock) add(Icons.inventory_2, 'Entrada de mercancía', _irMercancia);
    } else if (CategoriasNegocio.esServicios(cat)) {
      add(Icons.add_circle_outline, 'Agregar cita', _abrirAgregarCita);
      add(Icons.analytics_outlined, 'Historial', _irHistorial);
      add(Icons.campaign_outlined, 'Nueva promoción', _irPromo);
      add(Icons.event_available, 'Horario de citas', _irHorarioCitas);
      add(Icons.schedule, 'Horario del local', _abrirHorarioGuardado);
      add(Icons.payments_outlined, 'Formas de cobro', _configurarCobros);
      add(Icons.visibility_outlined, 'Ver como cliente', _irMenuPublico);
    } else {
      add(
        Icons.receipt_long,
        'Pedidos',
        _irPedidos,
        aviso: aviso.pendientesAhora,
        urgente: true,
      );
      add(
        Icons.event_available,
        'Encargos',
        () => _irPedidos(encargos: true),
        aviso: aviso.encargosAbiertos,
        urgente: aviso.encargosUrgentes,
      );
      add(Icons.analytics_outlined, 'Historial', _irHistorial);
      if (CategoriasNegocio.puedeEnvios(cat)) {
        add(Icons.local_shipping_outlined, 'Envíos y cobros', _irEnvios);
      }
      add(Icons.campaign_outlined, 'Nueva promoción', _irPromo);
      if (CategoriasNegocio.usaIngredientes(cat)) {
        add(Icons.restaurant_menu, 'Ingredientes', _irIngredientes);
      }
      if (_opciones.repisas) {
        add(Icons.shelves, 'Repisas', _irUbicaciones);
      }
      if (_opciones.stock) {
        add(Icons.inventory_2, 'Entrada de mercancía', _irMercancia);
      }
      add(Icons.schedule, 'Horario', _abrirHorarioGuardado);
      add(Icons.visibility_outlined, 'Ver como cliente', _irMenuPublico);
    }
    if (_opciones.clientesDescuento && !CategoriasNegocio.esBodega(cat)) {
      add(Icons.loyalty_outlined, 'Clientes con descuento', _irClientesDescuento);
    }
    add(Icons.groups_outlined, 'Equipo', _irEquipo);
    return acciones;
  }

  Widget _tituloBloque(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _botonPrincipal(MaterialColor tono) {
    final cat = widget.categoria;
    final esServicios = CategoriasNegocio.esServicios(cat);
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        icon: Icon(CategoriasNegocio.iconoVentaEnLocal(cat), size: 22),
        label: Text(
          esServicios ? 'Citas y solicitudes' : CategoriasNegocio.etiquetaVentaEnLocalLargo(cat),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: tono.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: esServicios ? _irPedidos : _irVentaLocal,
      ),
    );
  }

  Widget _grillaAcciones(MaterialColor tono) {
    return AvisoPedidosNegocio(
      negocioId: widget.negocioId,
      builder: (aviso) {
        final acciones = _accionesPanel(aviso);
        return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 720 ? 3 : 2;
        const gap = 8.0;
        final ancho = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: acciones.map((accion) {
            return SizedBox(
              width: ancho,
              child: Material(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: accion.onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(accion.icono, size: 22, color: tono.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            accion.titulo,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.2),
                          ),
                        ),
                        EncargoUtils.burbuja(accion.aviso, urgente: accion.urgente),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
      );
      },
    );
  }

  // ==========================================
  // CONSTRUCCIÓN DE LA PANTALLA PRINCIPAL
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final bool esBodega = CategoriasNegocio.esBodega(widget.categoria);
    final bool isPausado = ComisionAppUtils.esPausado(_estado);
    final bool isActivo = ComisionAppUtils.esActivo(_estado);
    final bool puedeOperar = esBodega || isActivo || isPausado;
    final MaterialColor tono = isPausado && !esBodega
        ? Colors.deepPurple
        : CategoriasNegocio.color(widget.categoria);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              esBodega ? 'Gestionar bodega' : 'Gestionar negocio',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.categoria,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: tono.shade100,
            child: Text(
              esBodega
                  ? 'Bodega interna. No sale en Explorar. Solo inventario y salidas.'
                  : (isPausado
                      ? 'En pausa. Nadie lo ve en Explorar hasta que lo publiques.'
                      : (isActivo
                          ? 'Público. ${CategoriasNegocio.resumen(widget.categoria)}'
                          : 'Estado del negocio en actualización.')),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tono.shade900,
                height: 1.3,
              ),
            ),
          ),
          if (!esBodega)
            Material(
              color: tono.shade50,
              child: SwitchListTile(
                value: isActivo,
                activeColor: Colors.green,
                title: Text(
                  isPausado ? 'Oculto al público' : 'Visible para todos',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  isPausado
                      ? 'Actívalo cuando ya tengas productos y quieras que el local salga en Explorar.'
                      : 'Los clientes lo ven. Páusalo si todavía no quieres mostrarlo.',
                  style: const TextStyle(fontSize: 12, height: 1.3),
                ),
                onChanged: _publicando ? null : _cambiarVisibilidadPublica,
              ),
            ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  if (puedeOperar) ...[
                    _tituloBloque('Día a día'),
                    _botonPrincipal(tono),
                    if (CategoriasNegocio.esServicios(widget.categoria)) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _abrirAgregarCita,
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text(
                            'Agregar cita',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: tono.shade800,
                            side: BorderSide(color: tono.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      CategoriasNegocio.ayudaVentaEnLocal(widget.categoria),
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.3),
                    ),
                    const SizedBox(height: 18),
                    _tituloBloque('Herramientas'),
                    _grillaAcciones(tono),
                    const SizedBox(height: 8),
                    const Divider(height: 28),
                  ],

                  // --- DATOS BÁSICOS DEL NEGOCIO (FOTO Y MAPA) ---
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('negocios').doc(widget.negocioId).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      final logoUrl = data['foto_url'];
                      if (!_datosCargados) {
                        _ubicacionCtrl.text = data['ubicacion'] ?? '';
                        _descCtrl.text = data['descripcion'] ?? '';
                        _telefonoCtrl.text = data['telefono_contacto'] ?? '';
                        _ubicacionGeo = data['ubicacion_geo'];
                        _datosCargados = true;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _tituloBloque(esBodega ? 'Datos de la bodega' : 'Datos del local'),
                          if (esBodega) ...[
                            TextField(
                              controller: _nombreCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nombre de la bodega',
                                border: OutlineInputBorder(),
                                isDense: true,
                                prefixIcon: Icon(Icons.warehouse_outlined),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _descCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Nota interna (opcional)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ] else ...[
                            Row(
                            children: [
                              GestureDetector(
                                onTap: _cambiarImagen,
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    SquareImage(
                                      imageUrl: logoUrl,
                                      size: 80,
                                      borderRadius: BorderRadius.circular(12),
                                      placeholder: Container(
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.store, size: 40, color: Colors.grey),
                                      ),
                                    ),
                                    const CircleAvatar(
                                        radius: 14,
                                        backgroundColor: Colors.blueAccent,
                                        child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  children: [
                                    TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre del Negocio', border: OutlineInputBorder(), isDense: true)),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: _ubicacionCtrl,
                                      decoration: InputDecoration(
                                        labelText: 'Ubicación (Ej. Centro...)', border: OutlineInputBorder(borderSide: BorderSide(color: _ubicacionGeo != null ? Colors.green : Colors.grey)), isDense: true, prefixIcon: const Icon(Icons.location_on, size: 18),
                                        suffixIcon: IconButton(
                                          icon: Icon(_ubicacionGeo != null ? Icons.location_on : Icons.add_location_alt, color: _ubicacionGeo != null ? Colors.green : Colors.blueAccent, size: 26),
                                          onPressed: () async {
                                            final resultado = await Navigator.push(context, MaterialPageRoute(builder: (_) => const MapaUbicacionScreen(soloCoordenadas: true)));
                                            if (resultado != null) {
                                              double? lat; 
                                              double? lng;
                                              
                                              // TRADUCTOR UNIVERSAL DE COORDENADAS
                                              if (resultado is LatLng) { 
                                                lat = resultado.latitude; lng = resultado.longitude; 
                                              } else if (resultado is GeoPoint) { 
                                                lat = resultado.latitude; lng = resultado.longitude; 
                                              } else if (resultado is Map) {
                                                lat = (resultado['lat'] ?? resultado['latitude'])?.toDouble();
                                                lng = (resultado['lng'] ?? resultado['longitude'])?.toDouble();
                                              } else if (resultado is List && resultado.length >= 2) {
                                                lat = resultado[0]?.toDouble(); lng = resultado[1]?.toDouble();
                                              } else {
                                                try { lat = resultado.latitude; lng = resultado.longitude; } catch(e) {}
                                              }

                                              // ARREGLO DEL ERROR DOUBLE?: Validamos que no sean nulos y usamos !
                                              if (lat != null && lng != null) {
                                                final geo = GeoPoint(lat, lng);
                                                setState(() => _ubicacionGeo = geo);
                                                await FirebaseFirestore.instance
                                                    .collection('negocios')
                                                    .doc(widget.negocioId)
                                                    .update({'ubicacion_geo': geo});
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Ubicación GPS guardada.'),
                                                      backgroundColor: Colors.green,
                                                    ),
                                                  );
                                                }
                                              } else {
                                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ El mapa devolvió un formato irreconocible.'), backgroundColor: Colors.red));
                                              }
                                            }
                                          },
                                        )
                                      )
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _descCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Descripción para clientes',
                                hintText: 'Qué ofreces, en una o dos líneas',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _telefonoCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Teléfono o WhatsApp',
                                hintText: 'Lo ven al abrir tu local: llamada y WhatsApp',
                                border: OutlineInputBorder(),
                                isDense: true,
                                prefixIcon: Icon(Icons.phone_outlined, size: 18),
                              ),
                            ),
                          ],
                          if (!esBodega && _ubicacionGeo != null) const Padding(padding: EdgeInsets.only(top: 8), child: Align(alignment: Alignment.centerRight, child: Text('✓ Coordenadas fijadas en el mapa', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)))),
                          const SizedBox(height: 15),
                          SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: _isLoading ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save), label: const Text('Guardar Datos'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: _guardarDatos))
                        ],
                      );
                    }
                  ),
                  
                  const SizedBox(height: 20), const Divider(),

                  // --- PROMOCIONES ACTIVAS ---
                  if (!esBodega && (isActivo || isPausado)) ...[
                    const Row(children: [Icon(Icons.campaign, color: Colors.redAccent), SizedBox(width: 8), Text('Mis Promociones Activas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent))]),
                    const SizedBox(height: 10),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('promociones').where('negocio_id', isEqualTo: widget.negocioId).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        final promos = snapshot.data?.docs ?? [];
                        if (promos.isEmpty) return const Text('No tienes promociones activas.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic));
                        
                        return SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: promos.length,
                            itemBuilder: (context, index) {
                              final doc = promos[index];
                              final promo = doc.data() as Map<String, dynamic>;
                              return Container(
                                width: 220, margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
                                child: Row(
                                  children: [
                                    SquareImage(
                                      imageUrl: promo['foto_url'],
                                      size: 80,
                                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                                      placeholder: Container(color: Colors.grey.shade200, child: const Icon(Icons.image)),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (promo['destacado'] == true)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 1, right: 2),
                                                    child: Icon(Icons.star_rounded, size: 14, color: Colors.amber.shade700),
                                                  ),
                                                Expanded(
                                                  child: Text(promo['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                                ),
                                              ],
                                            ),
                                            Text('\$${promo['precio_promo']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                                            const Spacer(),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AgregarPromocionScreen(negocioId: widget.negocioId, nombreNegocio: widget.nombreActual, promoId: doc.id, promoData: promo))), child: const Icon(Icons.edit, size: 20, color: Colors.blueAccent)),
                                                const SizedBox(width: 10),
                                                InkWell(onTap: () => _eliminarPromocion(doc.id), child: const Icon(Icons.delete, size: 20, color: Colors.red)),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20), const Divider(),
                  ],

                  // --- CATÁLOGO ---
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          CategoriasNegocio.etiquetaCatalogo(widget.categoria),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tono.shade700,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Agregar'),
                        onPressed: () {
                          if (CategoriasNegocio.esServicios(widget.categoria)) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AgregarServicioScreen(
                                  negocioId: widget.negocioId,
                                ),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AgregarProductoScreen(
                                  negocioId: widget.negocioId,
                                  categoriaNegocio: widget.categoria,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _busquedaCatalogoCtrl,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: CategoriasNegocio.hintBusqueda(widget.categoria),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _busquedaCatalogo.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _busquedaCatalogoCtrl.clear();
                                setState(() => _busquedaCatalogo = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (v) => setState(() {
                      _busquedaCatalogo = v.trim().toLowerCase();
                      _topeCatalogo = 24;
                    }),
                  ),
                  const SizedBox(height: 15),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('productos').where('negocio_id', isEqualTo: widget.negocioId).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      final todos = snapshot.data?.docs ?? [];
                      final esServ = CategoriasNegocio.esServicios(widget.categoria);
                      final productos = todos.where((doc) {
                        final p = doc.data() as Map<String, dynamic>;
                        final itemServ = p['es_servicio'] == true;
                        return esServ ? itemServ : !itemServ;
                      }).toList();
                      final mapas = productos
                          .map((doc) => doc.data() as Map<String, dynamic>)
                          .toList();
                      final secciones = seccionesOrdenadas(mapas);
                      final sinSeccion = hayProductosSinSeccion(mapas);
                      final filtrados = productos.where((doc) {
                        final p = doc.data() as Map<String, dynamic>;
                        if (!coincideSeccion(p, _seccionCatalogo)) return false;
                        if (_busquedaCatalogo.isEmpty) return true;
                        return _coincideBusquedaCatalogo(p, _busquedaCatalogo);
                      }).toList();
                      final visibles = ordenarProductosDocumentos(filtrados);
                      final mostrados = visibles.take(_topeCatalogo).toList();
                      if (productos.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Center(
                            child: Text(
                              esServ
                                  ? 'No hay servicios registrados aún.'
                                  : 'No hay productos registrados aún.',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }
                      if (visibles.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 10),
                                Text(
                                  'Sin resultados para «$_busquedaCatalogo»',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (secciones.isNotEmpty) ...[
                            FiltroSecciones(
                              secciones: secciones,
                              seleccionada: secciones.contains(_seccionCatalogo) ||
                                      _seccionCatalogo == seccionSinClasificar
                                  ? _seccionCatalogo
                                  : '',
                              incluirSinSeccion: sinSeccion,
                              onSeleccionada: (s) => setState(() {
                                _seccionCatalogo = s;
                                _topeCatalogo = 24;
                              }),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Center(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            double maxW = constraints.maxWidth; if (maxW.isInfinite || maxW <= 0) maxW = MediaQuery.sizeOf(context).width - 32;
                            const spacing = 12.0;
                            final itemWidth = anchoTarjetaCuadricula(maxW, spacing: spacing);

                            return Wrap(
                              spacing: spacing, runSpacing: spacing,
                              children: mostrados.map((doc) {
                                final prod = doc.data() as Map<String, dynamic>;
                                final puedeEditar = puedeOperar;
                                List<Widget> extraWidgets = [];
                                if (prod['es_servicio'] == true) {
                                  final ts = prod['tipo_servicio']?.toString() ?? 'cita';
                                  extraWidgets.add(_infoChip(
                                    ts == 'cita' ? 'Con cita' : 'Solicitud a domicilio',
                                  ));
                                } else {
                                final textoIngredientes = NegocioIngredienteService.textoIngredientes(prod);
                                if (textoIngredientes != null) extraWidgets.add(_infoChip('Ingredientes: $textoIngredientes'));
                                if (prod['peso_o_contenido'] != null && prod['peso_o_contenido'].toString().isNotEmpty) extraWidgets.add(_infoChip('Cont: ${prod['peso_o_contenido']}'));
                                if (prod['requiere_receta'] == true) extraWidgets.add(_infoChip('Requiere receta'));
                                final vence = ProductoPedidoUtils.textoVencimiento(prod['fecha_vencimiento']);
                                if (vence != null) extraWidgets.add(_infoChip(vence));
                                final material = prod['material']?.toString() ?? '';
                                if (material.isNotEmpty) extraWidgets.add(_infoChip('Material: $material'));
                                if (prod['cotizar_whatsapp'] == true) extraWidgets.add(_infoChip('Cotizar por WhatsApp'));
                                }
                                if (_opciones.stock && prod['controla_inventario'] == true) {
                                  extraWidgets.add(_infoChip('Stock: ${NegocioUbicacionService.stockTotal(prod)} pza(s)'));
                                  if (_opciones.repisas) {
                                    final ubic = NegocioUbicacionService.textoUbicaciones(prod);
                                    if (ubic != null) extraWidgets.add(_infoChip('Ubicación: $ubic'));
                                  }
                                }

                                return SizedBox(
                                  width: itemWidth > 0 ? itemWidth : 150,
                                  child: Card(
                                    elevation: 3, shadowColor: Colors.black26, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => _abrirDetalleProducto(
                                        doc.id,
                                        prod,
                                        puedeEditar: puedeEditar,
                                      ),
                                      child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, 
                                      children: [
                                        SquareImage(
                                          imageUrl: prod['foto_url'],
                                          placeholder: Container(color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 50)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (productoEsDestacado(prod)) ...[
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2, right: 4),
                                                      child: Icon(Icons.star_rounded, size: 18, color: Colors.amber.shade700),
                                                    ),
                                                  ],
                                                  Expanded(
                                                    child: Text(
                                                      prod['nombre'] ?? 'Sin nombre',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                        height: 1.15,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (seccionProducto(prod).isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  seccionProducto(prod),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.blue.shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                              if (!esBodega) ...[
                                                const SizedBox(height: 6),
                                                if (_opciones.clientesDescuento)
                                                  PreciosInternos(data: prod)
                                                else
                                                  Text('\$${prod['precio']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 17)),
                                              ],
                                              if (prod['descripcion'] != null && prod['descripcion'].toString().isNotEmpty) ...[const SizedBox(height: 6), Text(prod['descripcion'], style: TextStyle(fontSize: 13, color: Colors.grey.shade800))],
                                              if (extraWidgets.isNotEmpty) ...[const SizedBox(height: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: extraWidgets)],
                                              
                                              const SizedBox(height: 12),
                                              if (puedeEditar)
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    GestureDetector(
                                                      onTap: () {
                                                        if (prod['es_servicio'] == true) {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (_) => AgregarServicioScreen(
                                                                negocioId: widget.negocioId,
                                                                servicioId: doc.id,
                                                                servicioData: prod,
                                                              ),
                                                            ),
                                                          );
                                                        } else {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (_) => AgregarProductoScreen(
                                                                negocioId: widget.negocioId,
                                                                categoriaNegocio: widget.categoria,
                                                                productoId: doc.id,
                                                                productoData: prod,
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                      },
                                                      child: Container(
                                                        padding: const EdgeInsets.all(8), 
                                                        margin: const EdgeInsets.only(right: 8),
                                                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.shade200)), 
                                                        child: const Icon(Icons.edit, color: Colors.blueAccent, size: 20)
                                                      )
                                                    ),
                                                    GestureDetector(
                                                      onTap: () => _eliminarProducto(doc.id),
                                                      child: Container(
                                                        padding: const EdgeInsets.all(8), 
                                                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)), 
                                                        child: const Icon(Icons.delete, color: Colors.red, size: 20)
                                                      )
                                                    )
                                                  ],
                                                )
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                          ),
                          if (visibles.length > mostrados.length)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: OutlinedButton.icon(
                                onPressed: () => setState(() => _topeCatalogo += 24),
                                icon: const Icon(Icons.expand_more),
                                label: Text(
                                  'Ver más (${visibles.length - mostrados.length} restantes)',
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccionPanel {
  final IconData icono;
  final String titulo;
  final VoidCallback onTap;
  final int aviso;
  final bool urgente;

  const _AccionPanel({
    required this.icono,
    required this.titulo,
    required this.onTap,
    this.aviso = 0,
    this.urgente = false,
  });
}