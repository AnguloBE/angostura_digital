import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/utils/mobile_image_utils.dart';
import 'package:angostura_digital/widgets/square_image.dart';

// --- IMPORTACIONES DE TUS PANTALLAS ---
import 'package:angostura_digital/screens/agregar_producto_screen.dart';
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
import 'package:angostura_digital/screens/ingredientes_negocio_screen.dart';
import 'package:angostura_digital/screens/ubicaciones_negocio_screen.dart';
import 'package:angostura_digital/screens/horario_citas_negocio_screen.dart';
import 'package:angostura_digital/services/negocio_ingrediente_service.dart';
import 'package:angostura_digital/services/negocio_ubicacion_service.dart';
import 'package:angostura_digital/utils/categorias_negocio.dart';
import 'package:angostura_digital/utils/comision_app_utils.dart';
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
  GeoPoint? _ubicacionGeo; 
  bool _isLoading = false;
  bool _datosCargados = false; 

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.nombreActual);
    _ubicacionCtrl = TextEditingController();
    NegocioEquipoService.migrarPropietarioLegacy(widget.negocioId);
    NotificacionesService.refrescarToken();
  }

  // --- 1. FUNCIÓN PARA CAMBIAR EL LOGO ---
  Future<void> _subirLogoDesdeFuente(ImageSource source) async {
    try {
      final bytes = await MobileImageUtils.pickCropAndReadBytes(
        context: context,
        source: source,
        cropTitle: 'Recortar logo',
        imageQuality: 80,
      );
      if (bytes == null) return;

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

  void _cambiarImagen() {
    MobileImageUtils.showImageSourcePicker(
      context,
      galleryLabel: 'Elegir logo de la galería',
      cameraLabel: 'Tomar foto del logo',
      onSelected: _subirLogoDesdeFuente,
    );
  }

  // --- 2. FUNCIÓN PARA GUARDAR DATOS PRINCIPALES ---
  Future<void> _guardarDatos() async {
    if (_nombreCtrl.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    
    Map<String, dynamic> datosAActualizar = {
      'nombre': _nombreCtrl.text.trim(), 
      'ubicacion': _ubicacionCtrl.text.trim()
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

  // ==========================================
  // CONSTRUCCIÓN DE LA PANTALLA PRINCIPAL
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final bool isPausado = ComisionAppUtils.esPausado(widget.estadoActual);
    final bool isActivo = ComisionAppUtils.esActivo(widget.estadoActual);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Gestionar Negocio'),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.groups),
            tooltip: 'Equipo y trabajadores',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EquipoNegocioScreen(
                    negocioId: widget.negocioId,
                    nombreNegocio: widget.nombreActual,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: isPausado ? Colors.deepPurple.shade100 : Colors.green.shade100,
            child: Text(
              isPausado
                  ? '⏸ PAUSADO: Los clientes no ven tu negocio. Regulariza el pago de la app.'
                  : (isActivo
                      ? '✅ ACTIVO: Tu negocio es visible para clientes.'
                      : 'Estado del negocio en actualización.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isPausado ? Colors.deepPurple.shade800 : Colors.green.shade800,
              ),
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  if (isActivo || isPausado) ...[
                    if (CategoriasNegocio.esServicios(widget.categoria))
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.event_available, size: 20),
                              label: const Text('Citas',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PedidosNegocioScreen(
                                      negocioId: widget.negocioId,
                                      nombreNegocio: widget.nombreActual,
                                      puedeVerHistorial: true,
                                      categoria: widget.categoria,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.campaign, size: 20),
                              label: const Text('Promo',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AgregarPromocionScreen(
                                      negocioId: widget.negocioId,
                                      nombreNegocio: widget.nombreActual,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          if (CategoriasNegocio.puedeVentaEnLocal(widget.categoria)) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: Icon(
                                  CategoriasNegocio.esProductos(widget.categoria)
                                      ? Icons.point_of_sale
                                      : Icons.add_shopping_cart,
                                  size: 20,
                                ),
                                label: Text(
                                  CategoriasNegocio.etiquetaVentaEnLocalLargo(widget.categoria),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  context.read<CartProvider>().limpiarCarrito();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MenuNegocioScreen(
                                        negocioId: widget.negocioId,
                                        nombreNegocio: widget.nombreActual,
                                        modoTrabajador: true,
                                        categoriaNegocio: widget.categoria,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.receipt_long, size: 20),
                              label: const Text('Pedidos',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PedidosNegocioScreen(
                                      negocioId: widget.negocioId,
                                      nombreNegocio: widget.nombreActual,
                                      puedeVerHistorial: true,
                                      categoria: widget.categoria,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.local_shipping, size: 20),
                              label: const Text('Envíos',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ConfigurarEnviosScreen(negocioId: widget.negocioId),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.campaign, size: 20),
                              label: const Text('Promo',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AgregarPromocionScreen(
                                      negocioId: widget.negocioId,
                                      nombreNegocio: widget.nombreActual,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.analytics_outlined),
                        label: const Text('Historial y ventas', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.indigo,
                          side: const BorderSide(color: Colors.indigo),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HistorialPedidosNegocioScreen(
                                negocioId: widget.negocioId,
                                nombreNegocio: widget.nombreActual,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (NegocioIngredienteService.usaIngredientes(widget.categoria))
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.restaurant_menu),
                          label: const Text('Mis ingredientes', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade800,
                            side: BorderSide(color: Colors.green.shade700),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => IngredientesNegocioScreen(
                                  negocioId: widget.negocioId,
                                  nombreNegocio: widget.nombreActual,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    if (CategoriasNegocio.esServicios(widget.categoria))
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event_available),
                          label: const Text(
                            'Horario para citas',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.deepPurple,
                            side: const BorderSide(color: Colors.deepPurple),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HorarioCitasNegocioScreen(
                                  negocioId: widget.negocioId,
                                  nombreNegocio: widget.nombreActual,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    if (CategoriasNegocio.esProductos(widget.categoria))
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.shelves),
                          label: const Text('Ubicaciones / Repisas', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.indigo,
                            side: const BorderSide(color: Colors.indigo),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UbicacionesNegocioScreen(
                                  negocioId: widget.negocioId,
                                  nombreNegocio: widget.nombreActual,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 15),

                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('negocios').doc(widget.negocioId).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
                        final data = snapshot.data!.data() as Map<String, dynamic>;
                        return Card(elevation: 0, color: Colors.blue.shade50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.shade200)), child: ListTile(leading: const Icon(Icons.calendar_month, color: Colors.blueAccent, size: 30), title: const Text('Horario de Atención', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)), subtitle: Text('Configura tus días de descanso', style: TextStyle(fontSize: 12, color: Colors.blue.shade800)), trailing: const Icon(Icons.chevron_right, color: Colors.blueAccent), onTap: () => _abrirConfiguracionHorario(data['horario'] as Map<String, dynamic>?)));
                      }
                    ),
                    const Divider(height: 30),
                  ],

                  // --- DATOS BÁSICOS DEL NEGOCIO (FOTO Y MAPA) ---
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('negocios').doc(widget.negocioId).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      final logoUrl = data['foto_url'];
                      if (!_datosCargados) { _ubicacionCtrl.text = data['ubicacion'] ?? ''; _ubicacionGeo = data['ubicacion_geo']; _datosCargados = true; }

                      return Column(
                        children: [
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
                          if (_ubicacionGeo != null) const Padding(padding: EdgeInsets.only(top: 8), child: Align(alignment: Alignment.centerRight, child: Text('✓ Coordenadas fijadas en el mapa', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)))),
                          const SizedBox(height: 15),
                          SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: _isLoading ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save), label: const Text('Guardar Datos'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: _guardarDatos))
                        ],
                      );
                    }
                  ),
                  
                  const SizedBox(height: 20), const Divider(),

                  // --- PROMOCIONES ACTIVAS ---
                  if (isActivo || isPausado) ...[
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
                                            Text(promo['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        CategoriasNegocio.esServicios(widget.categoria)
                            ? 'Mis servicios'
                            : 'Catálogo / Productos',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CategoriasNegocio.esServicios(widget.categoria)
                              ? Colors.deepPurple
                              : Colors.blueAccent,
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
                      
                      return Center(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            double maxW = constraints.maxWidth; if (maxW.isInfinite || maxW <= 0) maxW = MediaQuery.of(context).size.width - 32;
                            int crossAxisCount = (maxW / 180).ceil(); if (crossAxisCount < 2) crossAxisCount = 2; 
                            final double spacing = 12; final double totalSpacing = spacing * (crossAxisCount - 1); final double itemWidth = (maxW - totalSpacing) / crossAxisCount;

                            return Wrap(
                              spacing: spacing, runSpacing: spacing,
                              children: productos.map((doc) {
                                final prod = doc.data() as Map<String, dynamic>;
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
                                }
                                if (CategoriasNegocio.esProductos(widget.categoria)) {
                                  extraWidgets.add(_infoChip('Stock: ${NegocioUbicacionService.stockTotal(prod)} pza(s)'));
                                  final ubic = NegocioUbicacionService.textoUbicaciones(prod);
                                  if (ubic != null) extraWidgets.add(_infoChip('Ubicación: $ubic'));
                                }

                                return SizedBox(
                                  width: itemWidth > 0 ? itemWidth : 150,
                                  child: Card(
                                    elevation: 3, shadowColor: Colors.black26, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), clipBehavior: Clip.antiAlias,
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
                                              Text(prod['nombre'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.15, color: Colors.black87)),
                                              const SizedBox(height: 6), Text('\$${prod['precio']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 17)),
                                              if (prod['descripcion'] != null && prod['descripcion'].toString().isNotEmpty) ...[const SizedBox(height: 6), Text(prod['descripcion'], style: TextStyle(fontSize: 13, color: Colors.grey.shade800))],
                                              if (extraWidgets.isNotEmpty) ...[const SizedBox(height: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: extraWidgets)],
                                              
                                              const SizedBox(height: 12),
                                              // --- ARREGLO: BOTONES DE EDITAR Y BORRAR PRODUCTO ---
                                              if (isActivo || isPausado)
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
                                );
                              }).toList(),
                            );
                          },
                        ),
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