import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:angostura_digital/providers/cart_provider.dart';
import 'package:angostura_digital/screens/carrito_screen.dart'; 
import 'package:angostura_digital/globals.dart' as globals;
import 'package:url_launcher/url_launcher.dart'; 

class MenuNegocioScreen extends StatelessWidget {
  final String negocioId;
  final String nombreNegocio;
  final String? fotoUrl;

  const MenuNegocioScreen({
    super.key, 
    required this.negocioId, 
    required this.nombreNegocio,
    this.fotoUrl,
  });

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

  // --- GOOGLE MAPS LAUNCHER (Más robusto) ---
  Future<void> _abrirMapa(GeoPoint geo, BuildContext context) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${geo.latitude},${geo.longitude}');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir Google Maps')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al abrir el mapa')));
    }
  }

  Widget _infoChip(String texto) { return Padding(padding: const EdgeInsets.only(bottom: 4.0), child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)), child: Text(texto, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500)))); }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(nombreNegocio, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: globals.colorFondo, foregroundColor: Colors.white),
      
      floatingActionButton: cart.items.isNotEmpty
          ? FloatingActionButton.extended(backgroundColor: Colors.green, foregroundColor: Colors.white, icon: const Icon(Icons.shopping_cart), label: Text('Ver Carrito ( \$${cart.total.toStringAsFixed(2)} )'), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const CarritoScreen())); }) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('negocios').doc(negocioId).snapshots(),
        builder: (context, snapshotNegocio) {
          if (!snapshotNegocio.hasData || !snapshotNegocio.data!.exists) return const Center(child: CircularProgressIndicator());
          
          final dataNegocio = snapshotNegocio.data!.data() as Map<String, dynamic>;
          String? estadoCierre = _verificarHorario(dataNegocio['horario'] as Map<String, dynamic>?);
          bool isAbierto = estadoCierre == null;
          
          String ubicacion = dataNegocio['ubicacion'] ?? ''; 
          GeoPoint? ubicacionGeo = dataNegocio['ubicacion_geo'];
          
          // ATRAPAMOS LA ZONA CON CUALQUIER NOMBRE
          String zonaEnvio = (dataNegocio['zona_envio'] ?? dataNegocio['zona'] ?? dataNegocio['zonas'] ?? '').toString(); 
          
          String mensajeTiempo = ''; Color colorTiempo = Colors.grey;
          if (!isAbierto) { mensajeTiempo = '🔴 $estadoCierre'; colorTiempo = Colors.red; } 
          else { mensajeTiempo = '🟢 ABIERTO AHORA • Listos para tu pedido'; colorTiempo = Colors.green; }

          return Column(
            children: [
              Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: !isAbierto ? Colors.red.shade50 : Colors.green.shade50, border: Border(bottom: BorderSide(color: Colors.grey.shade300)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]),
                child: Row(children: [Icon(!isAbierto ? Icons.lock_clock : Icons.store_mall_directory, color: colorTiempo, size: 20), const SizedBox(width: 8), Expanded(child: Text(mensajeTiempo.toUpperCase(), style: TextStyle(color: colorTiempo, fontWeight: FontWeight.bold, fontSize: 13)))]),
              ),
              
              if (ubicacion.isNotEmpty || zonaEnvio.isNotEmpty || ubicacionGeo != null)
                Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ubicacion.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(children: [Icon(Icons.location_on, color: Colors.red.shade400, size: 18), const SizedBox(width: 8), Expanded(child: Text(ubicacion, style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 14)))]),
                        ),
                      if (zonaEnvio.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(children: [Icon(Icons.delivery_dining, color: Colors.blue.shade400, size: 18), const SizedBox(width: 8), Expanded(child: Text('Zona de envío: $zonaEnvio', style: TextStyle(color: Colors.blue.shade800, fontSize: 14, fontWeight: FontWeight.bold)))]),
                        ),
                      if (ubicacionGeo != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.directions, size: 20), 
                            label: const Text('Cómo llegar (Google Maps)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            onPressed: () => _abrirMapa(ubicacionGeo, context),
                          ),
                        )
                    ],
                  ),
                ),

              const Padding(padding: EdgeInsets.all(16.0), child: Align(alignment: Alignment.centerLeft, child: Text('Catálogo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
              
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('productos').where('negocio_id', isEqualTo: negocioId).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    final productos = snapshot.data?.docs ?? [];
                    if (productos.isEmpty) return const Center(child: Text('Este local aún no ha subido productos.', style: TextStyle(color: Colors.grey)));

                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                      child: Center(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            double maxW = constraints.maxWidth; if (maxW.isInfinite || maxW <= 0) maxW = MediaQuery.of(context).size.width - 32;
                            int crossAxisCount = (maxW / 180).ceil(); if (crossAxisCount < 2) crossAxisCount = 2; 
                            final double spacing = 12; final double totalSpacing = spacing * (crossAxisCount - 1); final double itemWidth = (maxW - totalSpacing) / crossAxisCount;

                            return Wrap(
                              spacing: spacing, runSpacing: spacing,
                              children: productos.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                String? prodFoto = data['foto_url'];

                                List<Widget> extraWidgets = [];
                                if (data['ingredientes'] != null && data['ingredientes'].toString().isNotEmpty) extraWidgets.add(_infoChip('Ingredientes: ${data['ingredientes']}'));
                                if (data['peso_o_contenido'] != null && data['peso_o_contenido'].toString().isNotEmpty) extraWidgets.add(_infoChip('Cont: ${data['peso_o_contenido']}'));
                                if (data['codigo_barras'] != null && data['codigo_barras'].toString().isNotEmpty) extraWidgets.add(_infoChip('Cód: ${data['codigo_barras']}'));
                                if (data['tallas_disponibles'] != null && data['tallas_disponibles'].toString().isNotEmpty) extraWidgets.add(_infoChip('Tallas: ${data['tallas_disponibles']}'));
                                if (data['colores'] != null && data['colores'].toString().isNotEmpty) extraWidgets.add(_infoChip('Colores: ${data['colores']}'));

                                return SizedBox(
                                  width: itemWidth > 0 ? itemWidth : 150,
                                  child: Card(
                                    elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, 
                                      children: [
                                        AspectRatio(
                                          aspectRatio: 1, 
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: prodFoto != null 
                                                ? Image.network(prodFoto, fit: BoxFit.cover, color: !isAbierto ? Colors.black.withOpacity(0.5) : null, colorBlendMode: !isAbierto ? BlendMode.saturation : null) 
                                                : Container(color: Colors.grey.shade200, child: const Icon(Icons.fastfood, color: Colors.grey, size: 50)),
                                          ),
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
                                              const SizedBox(height: 12),
                                              
                                              if (isAbierto)
                                                Align(
                                                  alignment: Alignment.bottomRight,
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      bool exito = cart.agregarProducto(negocioId, doc.id, data['nombre'] ?? '', (data['precio'] ?? 0).toDouble(), prodFoto);
                                                      if (exito) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${data['nombre']} agregado 🛒', style: const TextStyle(fontWeight: FontWeight.bold)), duration: const Duration(milliseconds: 800), backgroundColor: Colors.green));
                                                      } else { _mostrarAlertaCarrito(context, cart, doc.id, data, prodFoto); }
                                                    },
                                                    child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add, color: Colors.white, size: 20)),
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

  void _mostrarAlertaCarrito(BuildContext context, CartProvider cart, String prodId, Map<String, dynamic> data, String? foto) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('⚠️ Carrito Ocupado', style: TextStyle(fontWeight: FontWeight.bold)), content: const Text('Tu carrito tiene productos de otro restaurante. Por políticas de entrega, solo puedes pedir de un local a la vez.\n\n¿Deseas vaciar tu carrito actual y comenzar un pedido aquí?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), onPressed: () { cart.limpiarCarrito(); cart.agregarProducto(negocioId, prodId, data['nombre'] ?? '', (data['precio'] ?? 0).toDouble(), foto); Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Carrito vaciado. Producto agregado.'), backgroundColor: Colors.green)); }, child: const Text('Sí, vaciar y agregar'))]));
  }
}