import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/providers/cart_provider.dart';
import 'package:angostura_digital/screens/menu_negocio_screen.dart';
import 'package:angostura_digital/widgets/pedido_producto_linea.dart';
import 'package:angostura_digital/utils/pedido_ubicacion_utils.dart';
import 'package:angostura_digital/screens/historial_pedidos_negocio_screen.dart';
import 'package:angostura_digital/screens/surtir_pedido_screen.dart';
import 'package:angostura_digital/utils/pedidos_historial_utils.dart';
import 'package:angostura_digital/utils/categorias_negocio.dart';
import 'package:angostura_digital/utils/pedido_servicios_utils.dart';
import 'package:angostura_digital/utils/pedido_mostrador_utils.dart';
import 'package:angostura_digital/widgets/editar_pedido_mostrador_dialog.dart';

class PedidosNegocioScreen extends StatelessWidget {
  final String negocioId;
  final String nombreNegocio;
  final bool puedeVerHistorial;
  final String categoria;

  const PedidosNegocioScreen({
    super.key,
    required this.negocioId,
    required this.nombreNegocio,
    this.puedeVerHistorial = false,
    this.categoria = '',
  });

  bool get _puedeVentaEnLocal => CategoriasNegocio.puedeVentaEnLocal(categoria);

  void _abrirNuevoPedidoMostrador(BuildContext context) {
    context.read<CartProvider>().limpiarCarrito();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuNegocioScreen(
          negocioId: negocioId,
          nombreNegocio: nombreNegocio,
          modoTrabajador: true,
          categoriaNegocio: categoria,
        ),
      ),
    );
  }

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

  Future<void> _actualizarEstado(BuildContext context, String pedidoId, String nuevoEstado, {String? tiempoEstimado}) async {
    final messenger = ScaffoldMessenger.of(context);
    
    if (nuevoEstado == 'Cancelado') {
      showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
    }

    try {
      final datos = <String, dynamic>{'estado': nuevoEstado};
      if (tiempoEstimado != null) {
        datos['tiempo_estimado'] = tiempoEstimado;
      } else if (nuevoEstado != 'Preparando') {
        datos['tiempo_estimado'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance.collection('pedidos').doc(pedidoId).update(datos);
      
      if (tiempoEstimado != null) {
        await FirebaseFirestore.instance.collection('negocios').doc(negocioId).update({
          'ultimo_tiempo_estimado': tiempoEstimado,
          'fecha_ultimo_tiempo': FieldValue.serverTimestamp(),
        });
      }

      if (nuevoEstado == 'Cancelado' && context.mounted) Navigator.pop(context); 
      Future.delayed(const Duration(milliseconds: 100), () { messenger.showSnackBar(SnackBar(content: Text(nuevoEstado == 'Cancelado' ? 'Pedido cancelado.' : 'Estado actualizado a: $nuevoEstado'), backgroundColor: nuevoEstado == 'Cancelado' ? Colors.orange : Colors.green)); });
    
    } catch(e) {
      if (nuevoEstado == 'Cancelado' && context.mounted) Navigator.pop(context); 
      Future.delayed(const Duration(milliseconds: 100), () { messenger.showSnackBar(SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.red)); });
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

  bool get _esNegocioServicios => PedidoServiciosUtils.esNegocioServicios(categoria);

  void _confirmarCancelacion(BuildContext context, String pedidoId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_esNegocioServicios ? '⚠️ Cancelar cita' : '⚠️ Cancelar Pedido'),
        content: Text(_esNegocioServicios
            ? '¿Seguro que quieres cancelar esta cita?'
            : '¿Estás seguro de que quieres cancelar este pedido?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No, mantener')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () { Navigator.pop(ctx); _actualizarEstado(context, pedidoId, 'Cancelado'); }, child: const Text('Sí, Cancelar', style: TextStyle(color: Colors.white)))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _esNegocioServicios ? 'Citas: $nombreNegocio' : 'Pedidos: $nombreNegocio',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
        actions: [
          if (puedeVerHistorial)
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              tooltip: 'Historial y ventas',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HistorialPedidosNegocioScreen(
                      negocioId: negocioId,
                      nombreNegocio: nombreNegocio,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      floatingActionButton: _puedeVentaEnLocal
          ? FloatingActionButton.extended(
              onPressed: () => _abrirNuevoPedidoMostrador(context),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              icon: Icon(CategoriasNegocio.esProductos(categoria)
                  ? Icons.point_of_sale
                  : Icons.add_shopping_cart),
              label: Text(CategoriasNegocio.etiquetaVentaEnLocal(categoria)),
            )
          : null,
      body: Column(
        children: [
          Material(
            color: Colors.blueGrey.shade50,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 18, color: Colors.blueGrey.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _esNegocioServicios
                          ? 'Citas de las últimas 24 horas. Anteriores en Historial y ventas.'
                          : _puedeVentaEnLocal
                              ? 'Últimas 24 horas. Usa «${CategoriasNegocio.etiquetaVentaEnLocal(categoria)}» para registrar ventas en el local.'
                              : 'Últimas 24 horas (incluye turno nocturno). Pedidos anteriores en Historial y ventas.',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade800, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('pedidos').where('negocio_id', isEqualTo: negocioId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          var pedidos = snapshot.data?.docs.toList() ?? [];

          pedidos = pedidos.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return PedidosHistorialUtils.esPedidoEnVentanaActiva(data);
          }).toList();
          
          pedidos.sort((a, b) {
            final fechaA = (a.data() as Map<String, dynamic>)['fecha'] as Timestamp?;
            final fechaB = (b.data() as Map<String, dynamic>)['fecha'] as Timestamp?;
            if (fechaA == null) return -1; if (fechaB == null) return 1; return fechaB.compareTo(fechaA);
          });

          if (pedidos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      _esNegocioServicios
                          ? 'No hay citas en las últimas 24 horas'
                          : 'No hay pedidos en las últimas 24 horas',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Si cerraste tarde o buscas pedidos de ayer, revísalos en el historial.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    if (puedeVerHistorial) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HistorialPedidosNegocioScreen(
                                negocioId: negocioId,
                                nombreNegocio: nombreNegocio,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.analytics_outlined),
                        label: const Text('Historial y ventas'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

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
              final esMostrador =
                  data['es_pedido_mostrador'] == true || metodoEntrega == 'mostrador';
              
              final subtotal = (data['subtotal'] ?? 0).toDouble();
              final costoEnvio = (data['costo_envio'] ?? 0).toDouble();
              final comisionApp = ((data['comision_app'] ?? 0) as num).toDouble();
              final comisionLaPagaCliente =
                  data['comision_pagada_por'] == 'cliente' && comisionApp > 0;
              final totalPedido = ((data['total'] ?? 0) as num).toDouble();
              final totalARecibir = totalPedido > 0
                  ? totalPedido
                  : subtotal + costoEnvio + (comisionLaPagaCliente ? comisionApp : 0);

              final Timestamp? timestamp = data['fecha'] as Timestamp?;
              String fechaFormateada = 'Fecha pendiente...';
              if (timestamp != null) {
                final dt = timestamp.toDate();
                final hora12 = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
                fechaFormateada = '${dt.day}/${dt.month}/${dt.year} • $hora12:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
              }

              // Coordenadas de entrega (GeoPoint, campos planos o pedidos antiguos)
              final coordsEntrega = PedidoUbicacionUtils.resolverEntrega(data);

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
                                Text(
                                  _esNegocioServicios
                                      ? 'CITA'
                                      : (esMostrador ? 'MOSTRADOR' : 'ORDEN'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: esMostrador ? Colors.indigo : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text('#${doc.id.substring(0, 6).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Row(children: [const Icon(Icons.access_time, size: 14, color: Colors.blueGrey), const SizedBox(width: 4), Text(fechaFormateada, style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.w500))]),
                              ],
                            ),
                          ),
                          _buildEstadoControl(context, doc.id, estadoActual, metodoEntrega),
                        ],
                      ),
                      
                      const SizedBox(height: 15),
                      
                      if (_esNegocioServicios && metodoEntrega == 'cita')
                        _buildBloqueCita(data)
                      else if (_esNegocioServicios && metodoEntrega == 'servicio_solicitud')
                        _buildBloqueSolicitudDomicilio(context, data, coordsEntrega)
                      else if (esMostrador)
                        _buildBloqueMostrador(context, data, doc.id, estadoActual)
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.delivery_dining, color: Colors.blueAccent, size: 20),
                                  SizedBox(width: 6),
                                  Text('Dirección de Entrega',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                (data['direccion'] ?? 'El cliente recogerá en el local.')
                                    .replaceAll(RegExp(r'\n?\[Coords:.*\]'), ''),
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
                              ),
                              if (coordsEntrega != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  PedidoUbicacionUtils.formatear(coordsEntrega),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blueGrey.shade700,
                                      fontFamily: 'monospace'),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.map, size: 18),
                                  label: const Text('Ver en Maps'),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.blueAccent,
                                      elevation: 1),
                                  onPressed: () =>
                                      PedidoUbicacionUtils.abrirUbicacion(context, coordsEntrega),
                                ),
                              ],
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
                      if (data['productos'] != null) ...[
                        Builder(builder: (context) {
                          final esProductos =
                              CategoriasNegocio.esProductos(categoria);
                          final surtidoLineas =
                              (data['surtido_lineas'] as Map?) ?? {};
                          final productos = data['productos'] as List<dynamic>;

                          int totalUnidades = 0;
                          int totalSurtido = 0;
                          final lineas = <Widget>[];
                          for (var i = 0; i < productos.length; i++) {
                            final itemMap =
                                Map<String, dynamic>.from(productos[i] as Map);
                            final cant =
                                (itemMap['cantidad'] as num?)?.toInt() ?? 1;
                            final ya = (surtidoLineas['$i'] as num?)?.toInt() ?? 0;
                            totalUnidades += cant;
                            totalSurtido += ya > cant ? cant : ya;
                            lineas.add(PedidoProductoLinea(
                              item: itemMap,
                              surtido: esProductos ? ya : null,
                            ));
                          }

                          final completo = esProductos &&
                              totalUnidades > 0 &&
                              totalSurtido >= totalUnidades;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...lineas,
                              if (esProductos && totalUnidades > 0) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: completo
                                        ? Colors.green.shade50
                                        : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: completo
                                            ? Colors.green
                                            : Colors.orange.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        completo
                                            ? Icons.check_circle
                                            : Icons.shopping_bag_outlined,
                                        size: 18,
                                        color: completo
                                            ? Colors.green
                                            : Colors.orange.shade800,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        completo
                                            ? 'Pedido surtido ✓'
                                            : 'Surtido: $totalSurtido de $totalUnidades',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: completo
                                              ? Colors.green.shade800
                                              : Colors.orange.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          );
                        }),
                      ],
                      if (CategoriasNegocio.esProductos(categoria) &&
                          data['productos'] != null &&
                          estadoActual != 'Cancelado') ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.indigo,
                              side: const BorderSide(color: Colors.indigo),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text(
                              'Surtir pedido (escanear)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              final productos = (data['productos'] as List)
                                  .map((e) => Map<String, dynamic>.from(e as Map))
                                  .toList();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SurtirPedidoScreen(
                                    pedidoId: doc.id,
                                    negocioId: negocioId,
                                    nombreNegocio: nombreNegocio,
                                    productos: productos,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      _buildInfoPago(data, totalARecibir),
                      const Divider(height: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Subtotal: \$${subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          if (!_esNegocioServicios &&
                              metodoEntrega == 'domicilio' &&
                              costoEnvio > 0)
                            Text(
                              'Envío: \$${costoEnvio.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                            )
                          else if (!_esNegocioServicios &&
                              (metodoEntrega == 'recoger' || metodoEntrega == 'mostrador'))
                            Text(
                              metodoEntrega == 'mostrador'
                                  ? 'Pedido en mostrador (sin envío)'
                                  : 'Recoger en local (sin envío)',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (comisionLaPagaCliente)
                            Text(
                              'Uso de la app: \$${comisionApp.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                comisionLaPagaCliente ? 'Total cobrado al cliente:' : 'Total a recibir:',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '\$${totalARecibir.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPago(Map<String, dynamic> data, double total) {
    final metodo = (data['metodo_pago'] ?? 'efectivo').toString();
    final etiqueta = metodo == 'tarjeta'
        ? 'Tarjeta'
        : metodo == 'transferencia'
            ? 'Transferencia'
            : 'Efectivo';
    final icono = metodo == 'tarjeta'
        ? Icons.credit_card
        : metodo == 'transferencia'
            ? Icons.account_balance
            : Icons.payments;

    final pagaCon = (data['paga_con'] as num?)?.toDouble();
    final esEfectivo = metodo == 'efectivo';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pago: $etiqueta',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.purple),
              ),
            ],
          ),
          if (esEfectivo && pagaCon != null && pagaCon > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Paga con \$${pagaCon.toStringAsFixed(2)}  ·  Cambio: \$${(pagaCon - total).clamp(0, double.infinity).toStringAsFixed(2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ] else if (esEfectivo) ...[
            const SizedBox(height: 4),
            Text(
              'No indicó con cuánto paga (lleva cambio surtido).',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBloqueMostrador(
    BuildContext context,
    Map<String, dynamic> data,
    String pedidoId,
    String estadoActual,
  ) {
    final nombre = (data['cliente_nombre'] ?? '').toString().trim();
    final telefono = (data['cliente_telefono'] ?? '').toString().trim();
    final creadoPor = (data['creado_por_nombre'] ?? '').toString().trim();
    final puedeEditar = PedidoMostradorUtils.puedeEditarContenido(estadoActual);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.point_of_sale, color: Colors.indigo, size: 20),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Pedido en el local',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
              ),
              if (puedeEditar)
                IconButton(
                  tooltip: 'Editar datos del pedido',
                  icon: const Icon(Icons.edit, color: Colors.indigo, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () async {
                    await EditarPedidoMostradorDialog.mostrar(
                      context,
                      pedidoId: pedidoId,
                      pedido: data,
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            nombre.isNotEmpty ? 'Cliente: $nombre' : 'Cliente en mostrador (sin nombre)',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          if (creadoPor.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Tomado por: $creadoPor',
              style: TextStyle(fontSize: 12, color: Colors.indigo.shade800),
            ),
          ],
          if (telefono.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    telefono,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
          ],
        ],
      ),
    );
  }

  Widget _buildBloqueCita(Map<String, dynamic> data) {
    final resumen = PedidoServiciosUtils.resumenCitaDesdePedido(data);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_available, color: Colors.deepPurple, size: 20),
              SizedBox(width: 6),
              Text('Cita en el local',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            ],
          ),
          if (resumen.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(resumen,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        ],
      ),
    );
  }

  Widget _buildBloqueSolicitudDomicilio(
    BuildContext context,
    Map<String, dynamic> data,
    PedidoUbicacionCoords? coordsEntrega,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.home_repair_service, color: Colors.teal, size: 20),
              SizedBox(width: 6),
              Text('Servicio a domicilio',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            (data['direccion'] ?? 'Ubicación del cliente')
                .replaceAll(RegExp(r'\n?\[Coords:.*\]'), ''),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          if (coordsEntrega != null) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.map, size: 18),
              label: const Text('Ver ubicación en Maps'),
              onPressed: () => PedidoUbicacionUtils.abrirUbicacion(context, coordsEntrega),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEstadoControl(
    BuildContext context,
    String pedidoId,
    String estadoActual,
    String metodoEntrega,
  ) {
    if (_esNegocioServicios) {
      return _buildEstadoCitas(context, pedidoId, estadoActual);
    }
    return _buildEstadoDropdown(context, pedidoId, estadoActual, metodoEntrega);
  }

  Widget _buildEstadoCitas(BuildContext context, String pedidoId, String estadoActual) {
    if (estadoActual == PedidoServiciosUtils.estadoConfirmada) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 16),
            SizedBox(width: 6),
            Text('Confirmada',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      );
    }
    if (estadoActual == PedidoServiciosUtils.estadoCancelado) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel, color: Colors.red, size: 16),
            SizedBox(width: 6),
            Text('Cancelada',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 168,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            icon: const Icon(Icons.event_available, size: 18),
            label: const Text('Confirmar cita', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _actualizarEstado(
              context,
              pedidoId,
              PedidoServiciosUtils.estadoConfirmada,
            ),
          ),
        ),
        TextButton(
          onPressed: () => _confirmarCancelacion(context, pedidoId),
          child: const Text('Cancelar cita', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  Widget _buildEstadoDropdown(BuildContext context, String pedidoId, String estadoActual, String metodoEntrega) {
    if (estadoActual == 'Entregado' || estadoActual == 'Cancelado') {
      Color colorFinal = estadoActual == 'Entregado' ? Colors.green : Colors.red;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: colorFinal.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: colorFinal)),
        child: Row(children: [Icon(estadoActual == 'Entregado' ? Icons.check_circle : Icons.cancel, color: colorFinal, size: 16), const SizedBox(width: 6), Text(estadoActual, style: TextStyle(color: colorFinal, fontWeight: FontWeight.bold, fontSize: 13))]),
      );
    }

    String estadoIntermedio =
        (metodoEntrega == 'recoger' || metodoEntrega == 'mostrador')
            ? 'Listo para recoger'
            : 'En Camino';
    
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
              else if (nuevoEstado == 'Cancelado') _confirmarCancelacion(context, pedidoId);
              else _actualizarEstado(context, pedidoId, nuevoEstado);
            }
          },
        ),
      ),
    );
  }
}