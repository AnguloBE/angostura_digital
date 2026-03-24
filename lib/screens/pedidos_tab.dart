import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart'; 
import 'package:angostura_digital/globals.dart' as globals;
import 'package:url_launcher/url_launcher.dart'; // IMPORTANTE PARA EL MAPA

class PedidosTab extends StatelessWidget {
  const PedidosTab({super.key});

  // --- FUNCIÓN PARA ABRIR MAPAS ---
  Future<void> _abrirMapaGoogle(GeoPoint geo, BuildContext context) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${geo.latitude},${geo.longitude}');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir Mapas')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al abrir el mapa')));
    }
  }

  // --- FUNCIÓN ARREGLADA: AHORA RECIBE EL ID DE PAGO Y HABLA CON STRIPE ---
  Future<void> _cancelarPedidoCliente(BuildContext context, String pedidoId, String? paymentIntentId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Pedido'),
        content: const Text('¿Estás seguro de que quieres cancelar este pedido? Se iniciará el proceso de reembolso automáticamente a tu tarjeta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No, mantener')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Sí, Cancelar', style: TextStyle(color: Colors.white))
          )
        ],
      ),
    );

    if (confirmar == true) {
      showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));

      try {
        if (paymentIntentId != null && paymentIntentId.trim().isNotEmpty) {
          final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('reembolsarPago');
          await callable.call(<String, dynamic>{'paymentIntentId': paymentIntentId});
        }

        await FirebaseFirestore.instance.collection('pedidos').doc(pedidoId).update({'estado': 'Cancelado'});
        
        if (context.mounted) {
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido cancelado y dinero en proceso de reembolso.'), backgroundColor: Colors.orange));
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cancelar: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Pedidos', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: globals.colorFondo, foregroundColor: Colors.white),
      body: user == null
          ? const Center(child: Text('Inicia sesión para ver tus pedidos.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('pedidos').where('cliente_id', isEqualTo: user.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                var pedidos = snapshot.data?.docs.toList() ?? [];
                
                pedidos.sort((a, b) {
                  final fA = (a.data() as Map<String, dynamic>)['fecha'] as Timestamp?;
                  final fB = (b.data() as Map<String, dynamic>)['fecha'] as Timestamp?;
                  if (fA == null) return -1; if (fB == null) return 1; return fB.compareTo(fA); 
                });

                if (pedidos.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300), const SizedBox(height: 16), Text('Aún no has hecho pedidos', style: TextStyle(color: Colors.grey.shade600, fontSize: 16))]));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pedidos.length,
                  itemBuilder: (context, index) {
                    final doc = pedidos[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    final notas = data['notas'] ?? '';
                    final tiempoEstimado = data['tiempo_estimado'] ?? '';
                    final estadoActual = data['estado'] ?? 'Pendiente';
                    final negocioId = data['negocio_id'] ?? '';
                    
                    final String? paymentIntentId = data['payment_intent_id']?.toString();
                    
                    final Timestamp? timestamp = data['fecha'] as Timestamp?;
                    String fechaFormateada = 'Pendiente...';
                    if (timestamp != null) {
                      final dt = timestamp.toDate();
                      final hora12 = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
                      fechaFormateada = '${dt.day}/${dt.month}/${dt.year} • $hora12:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
                    }

                    Color colorEstado = Colors.orange;
                    if (estadoActual == 'Preparando') colorEstado = Colors.blueAccent;
                    if (estadoActual == 'En Camino') colorEstado = Colors.purpleAccent;
                    if (estadoActual == 'Entregado') colorEstado = Colors.green;
                    if (estadoActual == 'Cancelado') colorEstado = Colors.red;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16), elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data['negocio_nombre'] ?? 'Local', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), Row(children: [const Icon(Icons.access_time, size: 14, color: Colors.blueGrey), const SizedBox(width: 4), Text(fechaFormateada, style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.w500))])])),
                                Chip(label: Text(estadoActual, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)), backgroundColor: colorEstado, padding: EdgeInsets.zero)
                              ],
                            ),
                            
                            if (tiempoEstimado.isNotEmpty && estadoActual != 'Entregado' && estadoActual != 'Cancelado') ...[
                              const SizedBox(height: 12),
                              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue.shade200)), child: Row(children: [const Icon(Icons.timer, color: Colors.blueAccent, size: 20), const SizedBox(width: 8), Expanded(child: Text('Tiempo estimado: $tiempoEstimado', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)))]))
                            ],

                            if (notas.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.yellow.shade100, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.yellow.shade600)), child: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20), const SizedBox(width: 8), Expanded(child: Text('Notas: $notas', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)))]))
                            ],

                            const Divider(height: 20),
                            if (data['productos'] != null)
                              ...((data['productos'] as List<dynamic>).map((item) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${item['cantidad']}x  ${item['nombre']}', style: const TextStyle(color: Colors.black87)), Text('\$${(item['precio'] * item['cantidad']).toStringAsFixed(2)}', style: const TextStyle(color: Colors.black54))])))),
                            
                            const Divider(height: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Subtotal: \$${data['subtotal']?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(color: Colors.black54)),
                                Text('Envío a domicilio: \$${data['costo_envio']?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(color: Colors.black54)),
                                Text('Tarifa por uso de app: \$${data['tarifa_plataforma']?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(color: Colors.black54)),
                                const SizedBox(height: 5),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total pagado:', style: TextStyle(fontWeight: FontWeight.bold)), Text('\$${data['total']?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16))]),
                              ],
                            ),

                            // === NUEVO BOTÓN PARA VER LA UBICACIÓN DEL NEGOCIO ===
                            if (negocioId.isNotEmpty)
                              FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance.collection('negocios').doc(negocioId).get(),
                                builder: (context, snapshotNegocio) {
                                  if (!snapshotNegocio.hasData || !snapshotNegocio.data!.exists) return const SizedBox.shrink();
                                  
                                  final dataNegocio = snapshotNegocio.data!.data() as Map<String, dynamic>;
                                  final GeoPoint? geoNegocio = dataNegocio['ubicacion_geo'];
                                  
                                  if (geoNegocio == null) return const SizedBox.shrink();

                                  return Padding(
                                    padding: const EdgeInsets.only(top: 15),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.place, color: Colors.blueAccent),
                                        label: const Text('Ver ubicación del negocio'),
                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent, side: BorderSide(color: Colors.blueAccent.shade100)),
                                        onPressed: () => _abrirMapaGoogle(geoNegocio, context),
                                      ),
                                    ),
                                  );
                                }
                              ),

                            // === BOTÓN DE CANCELAR PARA EL CLIENTE ===
                            if (estadoActual == 'Pendiente') ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text('Cancelar Pedido'),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                  onPressed: () => _cancelarPedidoCliente(context, doc.id, paymentIntentId),
                                ),
                              )
                            ]
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
}