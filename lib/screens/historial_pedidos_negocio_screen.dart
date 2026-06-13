import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/services/negocio_equipo_service.dart';
import 'package:angostura_digital/utils/negocio_equipo_utils.dart';
import 'package:angostura_digital/utils/pedidos_historial_utils.dart';
import 'package:angostura_digital/widgets/pedido_producto_linea.dart';
import 'package:angostura_digital/widgets/pedido_ubicacion_entrega.dart';

class HistorialPedidosNegocioScreen extends StatefulWidget {
  final String negocioId;
  final String nombreNegocio;

  const HistorialPedidosNegocioScreen({
    super.key,
    required this.negocioId,
    required this.nombreNegocio,
  });

  @override
  State<HistorialPedidosNegocioScreen> createState() => _HistorialPedidosNegocioScreenState();
}

class _HistorialPedidosNegocioScreenState extends State<HistorialPedidosNegocioScreen> {
  PeriodoPedidosHistorial _periodo = PeriodoPedidosHistorial.mes;
  FiltroEstadoPedidos _filtroEstado = FiltroEstadoPedidos.todos;
  bool _verificandoAcceso = true;
  bool _accesoDenegado = false;

  @override
  void initState() {
    super.initState();
    _verificarAcceso();
  }

  Future<void> _verificarAcceso() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() { _verificandoAcceso = false; _accesoDenegado = true; });
      return;
    }

    final userSnap = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    final esAdmin = userSnap.data()?['rol'] == 'admin';
    final rolNegocio = await NegocioEquipoService.obtenerRolEnNegocio(widget.negocioId, uid);
    final esDueno = NegocioEquipoUtils.esDueno(rolNegocio);

    if (!mounted) return;
    setState(() {
      _verificandoAcceso = false;
      _accesoDenegado = !esAdmin && !esDueno;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_verificandoAcceso) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Historial · ${widget.nombreNegocio}', style: const TextStyle(fontSize: 17)),
          backgroundColor: globals.colorFondo,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_accesoDenegado) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Historial'),
          backgroundColor: globals.colorFondo,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'Solo los dueños pueden ver el historial y ventas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Historial · ${widget.nombreNegocio}', style: const TextStyle(fontSize: 17)),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pedidos')
            .where('negocio_id', isEqualTo: widget.negocioId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error al cargar pedidos: ${snap.error}', textAlign: TextAlign.center),
              ),
            );
          }

          final todos = snap.data?.docs
                  .map((d) => PedidoHistorialItem.desdeDoc(
                        d.id,
                        d.data() as Map<String, dynamic>,
                      ))
                  .toList() ??
              [];

          final filtrados = PedidosHistorialUtils.filtrar(
            todos,
            periodo: _periodo,
            estado: _filtroEstado,
          );
          final resumen = PedidosHistorialUtils.calcularResumen(filtrados);

          return Column(
            children: [
              _panelFiltros(),
              Expanded(
                child: filtrados.isEmpty
                    ? _vacio()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        children: [
                          _tarjetasResumen(resumen),
                          if (resumen.topProductos.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _seccionTitulo('Lo más pedido'),
                            _topProductos(resumen),
                          ],
                          if (resumen.conteoPorEstado.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _seccionTitulo('Por estado'),
                            _chipsEstado(resumen),
                          ],
                          const SizedBox(height: 8),
                          _seccionTitulo('Pedidos (${filtrados.length})'),
                          ...filtrados.map(_tarjetaPedido),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _panelFiltros() {
    return Material(
      color: Colors.white,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Periodo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: PeriodoPedidosHistorial.values.map((p) {
                  final sel = _periodo == p;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(PedidosHistorialUtils.etiquetaPeriodo(p)),
                      selected: sel,
                      onSelected: (_) => setState(() => _periodo = p),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Estado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chipEstado(FiltroEstadoPedidos.todos, 'Todos'),
                  _chipEstado(FiltroEstadoPedidos.activos, 'En curso'),
                  _chipEstado(FiltroEstadoPedidos.entregado, 'Entregados'),
                  _chipEstado(FiltroEstadoPedidos.cancelado, 'Cancelados'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipEstado(FiltroEstadoPedidos valor, String label) {
    final sel = _filtroEstado == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => setState(() => _filtroEstado = valor),
      ),
    );
  }

  Widget _tarjetasResumen(ResumenHistorialPedidos r) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _miniCard('Pedidos', '${r.totalPedidos}', Icons.receipt_long, Colors.blueAccent)),
            const SizedBox(width: 8),
            Expanded(child: _miniCard('Ventas', '\$${r.ventasTotales.toStringAsFixed(0)}', Icons.payments, Colors.green)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _miniCard('Entregados', '${r.entregados}', Icons.check_circle, Colors.teal)),
            const SizedBox(width: 8),
            Expanded(child: _miniCard('En curso', '${r.enProceso}', Icons.hourglass_top, Colors.orange)),
            const SizedBox(width: 8),
            Expanded(child: _miniCard('Cancelados', '${r.cancelados}', Icons.cancel, Colors.redAccent)),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _filaDetalle('Subtotal productos', r.subtotalProductos),
                _filaDetalle('Envíos cobrados', r.totalEnvios),
                if (r.totalComisionApp > 0)
                  _filaDetalle('Uso de la app (cliente)', r.totalComisionApp),
                _filaDetalle('Unidades vendidas', r.unidadesVendidas.toDouble(), esMoneda: false),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniCard(String titulo, String valor, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(valor, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            Text(titulo, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _filaDetalle(String label, double valor, {bool esMoneda = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          Text(
            esMoneda ? '\$${valor.toStringAsFixed(2)}' : valor.toInt().toString(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _topProductos(ResumenHistorialPedidos r) {
    final max = r.topProductos.isEmpty ? 1 : r.topProductos.first.cantidad;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: r.topProductos.map((p) {
            final frac = p.cantidad / max;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      Text(
                        '${p.cantidad} u · \$${p.monto.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: frac,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      color: globals.colorFondo,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _chipsEstado(ResumenHistorialPedidos r) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: r.conteoPorEstado.entries.map((e) {
        final color = PedidosHistorialUtils.estadoColor(e.key);
        return Chip(
          avatar: CircleAvatar(backgroundColor: color.withValues(alpha: 0.2), radius: 10),
          label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
    );
  }

  Widget _tarjetaPedido(PedidoHistorialItem p) {
    final color = PedidosHistorialUtils.estadoColor(p.estado);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            p.cancelado ? Icons.cancel : (p.entregado ? Icons.check : Icons.receipt),
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          '#${p.id.substring(0, 6).toUpperCase()} · \$${p.totalCobrado.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(PedidosHistorialUtils.formatearFecha(p.fecha), style: const TextStyle(fontSize: 12)),
            Text(
              '${p.estado} · ${p.cantidadArticulos} artículo(s) · ${p.metodoEntrega == 'recoger' ? 'Recoger' : 'Domicilio'}',
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        children: [
          if (p.esDomicilio) ...[
            PedidoUbicacionEntregaBlock(pedido: p),
            const Divider(height: 16),
          ],
          if (p.productos.isNotEmpty) ...[
            const Divider(),
            ...p.productos.map(
              (item) => PedidoProductoLinea(item: item, mostrarVerDetalle: true),
            ),
          ],
          const Divider(height: 16),
          _filaDetalle('Subtotal', p.subtotal),
          if (p.costoEnvio > 0) _filaDetalle('Envío', p.costoEnvio),
          if (p.comisionLaPagaCliente) _filaDetalle('Uso de la app', p.comisionApp),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '\$${p.totalCobrado.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                ),
              ],
            ),
          ),
          if (p.notas.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text('Notas: ${p.notas}', style: const TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _seccionTitulo(String t) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8, left: 4),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );

  Widget _vacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No hay pedidos en este periodo',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
          ),
          TextButton(
            onPressed: () => setState(() {
              _periodo = PeriodoPedidosHistorial.todos;
              _filtroEstado = FiltroEstadoPedidos.todos;
            }),
            child: const Text('Ver todos los pedidos'),
          ),
        ],
      ),
    );
  }
}
