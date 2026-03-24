import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart'; 
import 'package:angostura_digital/globals.dart' as globals;

class PedidosNegocioScreen extends StatelessWidget {
  final String negocioId;
  final String nombreNegocio;

  const PedidosNegocioScreen({super.key, required this.negocioId, required this.nombreNegocio});

  Future<void> _llamarCliente(BuildContext context, String telefono) async {
    final numStr = telefono.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri url = Uri.parse('tel:$numStr');
    try { await launchUrl(url); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el teléfono.'))); }
  }

  Future<void> _abrirWhatsApp(BuildContext context, String telefono) async {
    final numStr = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    final Uri url = Uri.parse('https://wa.me/$numStr');
    try { await launchUrl(url, mode: LaunchMode.externalApplication); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp.'))); }
  }

  // --- ARREGLO: AHORA LEE EL GEOPOINT REAL Y TIENE UN MEJOR ENLACE DE MAPS ---
  Future<void> _abrirRutaEnMaps(BuildContext context, String direccionG, GeoPoint? ubicacionGeo) async {
    double? lat;
    double? lng;

    // 1. Primero intentamos usar las coordenadas GPS reales (el método nuevo)
    if (ubicacionGeo != null) {
      lat = ubicacionGeo.latitude;
      lng = ubicacionGeo.longitude;
    } 
    // 2. Si es un pedido viejo, intentamos extraerlo del texto (Soporte antiguo)
    else {
      final RegExp exp = RegExp(r'\[Coords:\s*(-?\d+\.\d+),\s*(-?\d+\.\d+)\]');
      final match = exp.firstMatch(direccionG);
      if (match != null) {
        lat = double.tryParse(match.group(1)!);
        lng = double.tryParse(match.group(2)!);
      }
    }

    if (lat != null && lng != null) {
      // Enlace universal de Google Maps (funciona en Android y iOS)
      final Uri url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
      try { 
        await launchUrl(url, mode: LaunchMode.externalApplication); 
      } catch (e) { 
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir Google Maps.'), backgroundColor: Colors.red)); 
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontraron coordenadas en este pedido.')));
    }
  }

  // --- LÓGICA DE REEMBOLSO PROTEGIDA ---
  Future<void> _actualizarEstado(BuildContext context, String pedidoId, String nuevoEstado, {String? tiempoEstimado, String? paymentIntentId}) async {
    final messenger = ScaffoldMessenger.of(context);
    
    if (nuevoEstado == 'Cancelado') {
      showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
    }

    try {
      // 1. Intentamos el reembolso primero. Si falla, se va al catch y el pedido NO se cancela.
      if (nuevoEstado == 'Cancelado' && paymentIntentId != null && paymentIntentId.trim().isNotEmpty) {
        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('reembolsarPago');
        await callable.call(<String, dynamic>{'paymentIntentId': paymentIntentId});
      }

      // 2. Si Stripe devolvió el dinero bien, actualizamos Firebase
      Map<String, dynamic> datos = {'estado': nuevoEstado};
      if (tiempoEstimado != null) datos['tiempo_estimado'] = tiempoEstimado;

      await FirebaseFirestore.instance.collection('pedidos').doc(pedidoId).update(datos);
      
      if (tiempoEstimado != null) {
        await FirebaseFirestore.instance.collection('negocios').doc(negocioId).update({
          'ultimo_tiempo_estimado': tiempoEstimado,
          'fecha_ultimo_tiempo': FieldValue.serverTimestamp(),
        });
      }

      if (nuevoEstado == 'Cancelado' && context.mounted) Navigator.pop(context); 
      Future.delayed(const Duration(milliseconds: 100), () { messenger.showSnackBar(SnackBar(content: Text(nuevoEstado == 'Cancelado' ? 'Cancelado y dinero devuelto a tarjeta.' : 'Estado actualizado a: $nuevoEstado'), backgroundColor: nuevoEstado == 'Cancelado' ? Colors.orange : Colors.green)); });
    
    } catch(e) {
      if (nuevoEstado == 'Cancelado' && context.mounted) Navigator.pop(context); 
      Future.delayed(const Duration(milliseconds: 100), () { messenger.showSnackBar(SnackBar(content: Text('Error al reembolsar: $e'), backgroundColor: Colors.red)); });
    }
  }

  void _mostrarDialogoTiempo(BuildContext context, String pedidoId) {
    final TextEditingController tiempoCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿En cuánto tiempo estará listo?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                ActionChip(label: const Text('15m'), onPressed: () { Navigator.pop(ctx); _actualizarEstado(context, pedidoId, 'Preparando', tiempoEstimado: '15 min'); }),
                ActionChip(label: const Text('30m'), onPressed: () { Navigator.pop(ctx); _actualizarEstado(context, pedidoId, 'Preparando', tiempoEstimado: '30 min'); }),
                ActionChip(label: const Text('45m'), onPressed: () { Navigator.pop(ctx); _actualizarEstado(context, pedidoId, 'Preparando', tiempoEstimado: '45 min'); }),
                ActionChip(label: const Text('1h'), onPressed: () { Navigator.pop(ctx); _actualizarEstado(context, pedidoId, 'Preparando', tiempoEstimado: '1 hora'); }),
                ActionChip(label: const Text('1h 15m'), onPressed: () { Navigator.pop(ctx); _actualizarEstado(context, pedidoId, 'Preparando', tiempoEstimado: '1 hora 15 min'); }),
                ActionChip(label: const Text('1h 30m'), onPressed: () { Navigator.pop(ctx); _actualizarEstado(context, pedidoId, 'Preparando', tiempoEstimado: '1 hora 30 min'); }),
                ActionChip(label: const Text('1h 45m'), onPressed: () { Navigator.pop(ctx); _actualizarEstado(context, pedidoId, 'Preparando', tiempoEstimado: '1 hora 45 min'); }),
                ActionChip(label: const Text('2h'), onPressed: () { Navigator.pop(ctx); _actualizarEstado(context, pedidoId, 'Preparando', tiempoEstimado: '2 horas'); }),
              ],
            ),
            const SizedBox(height: 15),
            TextField(controller: tiempoCtrl, decoration: const InputDecoration(labelText: 'Otro tiempo', border: OutlineInputBorder()))
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () { if (tiempoCtrl.text.isNotEmpty) { Navigator.pop(ctx); _actualizarEstado(context, pedidoId, 'Preparando', tiempoEstimado: tiempoCtrl.text); } }, child: const Text('Confirmar'))
        ],
      ),
    );
  }

  void _confirmarCancelacion(BuildContext context, String pedidoId, String? paymentIntentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Cancelar Pedido'),
        content: const Text('¿Estás seguro de que quieres cancelar este pedido? Si el cliente pagó con tarjeta, se le hará el reembolso automático de inmediato.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No, mantener')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () { Navigator.pop(ctx); _actualizarEstado(context, pedidoId, 'Cancelado', paymentIntentId: paymentIntentId); }, child: const Text('Sí, Cancelar', style: TextStyle(color: Colors.white)))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pedidos: $nombreNegocio', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), backgroundColor: globals.colorFondo, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('pedidos').where('negocio_id', isEqualTo: negocioId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          var pedidos = snapshot.data?.docs.toList() ?? [];
          
          pedidos.sort((a, b) {
            final fechaA = (a.data() as Map<String, dynamic>)['fecha'] as Timestamp?;
            final fechaB = (b.data() as Map<String, dynamic>)['fecha'] as Timestamp?;
            if (fechaA == null) return -1; if (fechaB == null) return 1; return fechaB.compareTo(fechaA);
          });

          if (pedidos.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox, size: 80, color: Colors.grey.shade300), const SizedBox(height: 10), const Text('No hay pedidos nuevos.', style: TextStyle(color: Colors.grey))]));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: pedidos.length,
            itemBuilder: (context, index) {
              final doc = pedidos[index];
              final data = doc.data() as Map<String, dynamic>;
              final estadoActual = data['estado'] ?? 'Pendiente';
              final notas = data['notas'] ?? '';
              final clienteId = data['cliente_id'];
              
              final metodoEntrega = data['metodo_entrega'] ?? 'domicilio'; 
              
              final String? paymentIntentId = data['payment_intent_id']?.toString(); 
              
              final subtotal = (data['subtotal'] ?? 0).toDouble();
              final costoEnvio = (data['costo_envio'] ?? 0).toDouble();
              final totalARecibir = subtotal + costoEnvio;

              final Timestamp? timestamp = data['fecha'] as Timestamp?;
              String fechaFormateada = 'Fecha pendiente...';
              if (timestamp != null) {
                final dt = timestamp.toDate();
                final hora12 = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
                fechaFormateada = '${dt.day}/${dt.month}/${dt.year} • $hora12:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
              }

              // --- ARREGLO: LÓGICA DE VISIBILIDAD DEL BOTÓN DEL MAPA ---
              // Revisamos si el pedido tiene un GeoPoint válido, o si es de los antiguos que traía [Coords:]
              bool tieneMapa = data['ubicacion_geo'] != null || (data['direccion'] != null && data['direccion'].toString().contains('[Coords:'));

              return Card(
                elevation: 3, margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ORDEN', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                Text('#${doc.id.substring(0, 6).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Row(children: [const Icon(Icons.access_time, size: 14, color: Colors.blueGrey), const SizedBox(width: 4), Text(fechaFormateada, style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.w500))]),
                              ],
                            ),
                          ),
                          _buildEstadoDropdown(context, doc.id, estadoActual, paymentIntentId, metodoEntrega),
                        ],
                      ),
                      
                      const SizedBox(height: 15),
                      
                      Container(
                        width: double.infinity, padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [Icon(Icons.delivery_dining, color: Colors.blueAccent, size: 20), SizedBox(width: 6), Text('Dirección de Entrega', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent))]),
                            const SizedBox(height: 6),
                            // Limpiamos el texto por si es un pedido viejo con [Coords:]
                            Text((data['direccion'] ?? 'El cliente recogerá en el local.').replaceAll(RegExp(r'\n?\[Coords:.*\]'), ''), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
                            
                            // AHORA USAMOS LA VARIABLE QUE CREAMOS ARRIBA
                            if (tieneMapa) ...[
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.map, size: 18), label: const Text('Ver ruta en Google Maps'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blueAccent, elevation: 1),
                                // Pasamos ambos posibles valores (String viejo y GeoPoint nuevo)
                                onPressed: () => _abrirRutaEnMaps(context, data['direccion'] ?? '', data['ubicacion_geo'] as GeoPoint?),
                              )
                            ]
                          ],
                        ),
                      ),

                      if (clienteId != null)
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('usuarios').doc(clienteId).get(),
                          builder: (context, userSnap) {
                            if (!userSnap.hasData || !userSnap.data!.exists) return const SizedBox.shrink();
                            
                            final userData = userSnap.data!.data() as Map<String, dynamic>?;
                            final telefono = userData?['telefono'] ?? userData?['phoneNumber'];
                            
                            if (telefono == null || telefono.toString().trim().isEmpty) return const SizedBox.shrink();

                            return Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50, 
                                borderRadius: BorderRadius.circular(8), 
                                border: Border.all(color: Colors.green.shade200)
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.phone_in_talk, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Contacto del Cliente', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 11)),
                                        Text(telefono, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.call, color: Colors.blueAccent),
                                    tooltip: 'Llamar',
                                    onPressed: () => _llamarCliente(context, telefono),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.message, color: Colors.teal),
                                    tooltip: 'WhatsApp',
                                    onPressed: () => _abrirWhatsApp(context, telefono),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      if (notas.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.yellow.shade100, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.yellow.shade600)), child: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20), const SizedBox(width: 8), Expanded(child: Text('Notas: $notas', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)))]))
                      ],

                      const Divider(height: 25),
                      if (data['productos'] != null)
                        ...((data['productos'] as List<dynamic>).map((item) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${item['cantidad']}x ${item['nombre']}', style: const TextStyle(fontWeight: FontWeight.w500)), Text('\$${(item['precio'] * item['cantidad']).toStringAsFixed(2)}', style: const TextStyle(color: Colors.black54))])))),
                      const Divider(height: 25),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total a recibir:', style: TextStyle(fontWeight: FontWeight.bold)), Text('\$${totalARecibir.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18))]),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEstadoDropdown(BuildContext context, String pedidoId, String estadoActual, String? paymentIntentId, String metodoEntrega) {
    if (estadoActual == 'Entregado' || estadoActual == 'Cancelado') {
      Color colorFinal = estadoActual == 'Entregado' ? Colors.green : Colors.red;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: colorFinal.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: colorFinal)),
        child: Row(children: [Icon(estadoActual == 'Entregado' ? Icons.check_circle : Icons.cancel, color: colorFinal, size: 16), const SizedBox(width: 6), Text(estadoActual, style: TextStyle(color: colorFinal, fontWeight: FontWeight.bold, fontSize: 13))]),
      );
    }

    String estadoIntermedio = metodoEntrega == 'recoger' ? 'Listo para recoger' : 'En Camino';
    
    List<String> estadosPermitidos = [];
    if (estadoActual == 'Pendiente') {
      estadosPermitidos = ['Pendiente', 'Preparando', 'Cancelado'];
    } else if (estadoActual == 'Preparando') {
      estadosPermitidos = ['Preparando', estadoIntermedio, 'Cancelado'];
    } else if (estadoActual == estadoIntermedio || estadoActual == 'En Camino') {
      estadosPermitidos = [estadoActual, 'Entregado', 'Cancelado'];
    } else {
      estadosPermitidos = [estadoActual];
    }

    Color color = Colors.orange;
    if (estadoActual == 'Preparando') color = Colors.blueAccent;
    if (estadoActual == 'En Camino' || estadoActual == 'Listo para recoger') color = Colors.purpleAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: estadoActual,
          icon: Icon(Icons.arrow_drop_down, color: color),
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          items: estadosPermitidos.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (nuevoEstado) {
            if (nuevoEstado != null && nuevoEstado != estadoActual) {
              if (nuevoEstado == 'Preparando') _mostrarDialogoTiempo(context, pedidoId);
              else if (nuevoEstado == 'Cancelado') _confirmarCancelacion(context, pedidoId, paymentIntentId);
              else _actualizarEstado(context, pedidoId, nuevoEstado);
            }
          },
        ),
      ),
    );
  }
}