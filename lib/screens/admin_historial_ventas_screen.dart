import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/utils/pedidos_historial_utils.dart';
import 'package:angostura_digital/widgets/pedido_producto_linea.dart';
import 'package:angostura_digital/widgets/pedido_ubicacion_entrega.dart';

class AdminHistorialVentasScreen extends StatefulWidget {
  const AdminHistorialVentasScreen({super.key});

  @override
  State<AdminHistorialVentasScreen> createState() => _AdminHistorialVentasScreenState();
}

class _AdminHistorialVentasScreenState extends State<AdminHistorialVentasScreen> {
  PeriodoPedidosHistorial _periodo = PeriodoPedidosHistorial.mes;
  FiltroEstadoPedidos _filtroEstado = FiltroEstadoPedidos.todos;
  VistaAdminActividad _vista = VistaAdminActividad.resumen;
  final _busquedaCtrl = TextEditingController();
  bool _verificandoAcceso = true;
  bool _accesoDenegado = false;
  Map<String, String> _nombresUsuarios = {};
  Map<String, String> _telefonosUsuarios = {};

  @override
  void initState() {
    super.initState();
    _verificarAcceso();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _verificarAcceso() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() { _verificandoAcceso = false; _accesoDenegado = true; });
      return;
    }
    final snap = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    if (snap.data()?['rol'] != 'admin') {
      if (mounted) setState(() { _verificandoAcceso = false; _accesoDenegado = true; });
      return;
    }
    await _cargarUsuarios();
    if (mounted) setState(() { _verificandoAcceso = false; _accesoDenegado = false; });
  }

  Future<void> _cargarUsuarios() async {
    final snap = await FirebaseFirestore.instance.collection('usuarios').get();
    final nombres = <String, String>{};
    final telefonos = <String, String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      nombres[doc.id] = (data['nombre'] ?? 'Usuario').toString();
      telefonos[doc.id] = (data['telefono'] ?? '').toString();
    }
    _nombresUsuarios = nombres;
    _telefonosUsuarios = telefonos;
  }

  String _nombreUsuario(String? uid) {
    if (uid == null || uid.isEmpty) return 'Sin cliente';
    return _nombresUsuarios[uid] ?? 'Usuario ${uid.substring(0, 6)}';
  }

  String _telefonoUsuario(String? uid) {
    if (uid == null || uid.isEmpty) return '';
    return _telefonosUsuarios[uid] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (_verificandoAcceso) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Actividad en Angostura'),
          backgroundColor: globals.colorFondo,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_accesoDenegado) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Actividad'),
          backgroundColor: globals.colorFondo,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Solo administradores.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Actividad en Angostura', style: TextStyle(fontSize: 17)),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('pedidos').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final todos = snap.data?.docs
                  .map((d) => PedidoHistorialItem.desdeDoc(
                        d.id,
                        d.data() as Map<String, dynamic>,
                      ))
                  .toList() ??
              [];

          var filtrados = PedidosHistorialUtils.filtrar(
            todos,
            periodo: _periodo,
            estado: _filtroEstado,
          );
          filtrados = PedidosHistorialUtils.filtrarPorTexto(filtrados, _busquedaCtrl.text);

          final resumen = PedidosHistorialUtils.calcularResumenPlataforma(filtrados);

          return Column(
            children: [
              _panelFiltros(),
              Expanded(
                child: filtrados.isEmpty && _vista != VistaAdminActividad.resumen
                    ? _vacio()
                    : _contenidoVista(filtrados, resumen),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _contenidoVista(List<PedidoHistorialItem> filtrados, ResumenHistorialPlataforma resumen) {
    switch (_vista) {
      case VistaAdminActividad.pedidos:
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            _seccionTitulo('Pedidos (${filtrados.length})'),
            ...filtrados.map(_tarjetaPedido),
          ],
        );
      case VistaAdminActividad.negocios:
        return _vistaNegocios(filtrados);
      case VistaAdminActividad.productos:
        return _vistaProductos(filtrados);
      case VistaAdminActividad.usuarios:
        return _vistaUsuarios(filtrados);
      case VistaAdminActividad.resumen:
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            _tarjetasGlobales(resumen),
            if (resumen.topNegocios.isNotEmpty) ...[
              _seccionTitulo('Top negocios'),
              _listaNegociosCompacta(resumen.topNegocios.take(5).toList()),
            ],
            if (resumen.general.topProductos.isNotEmpty) ...[
              _seccionTitulo('Top productos'),
              _listaProductosCompacta(resumen.general.topProductos.take(5).toList()),
            ],
            _seccionTitulo('Pedidos recientes'),
            ...filtrados.take(15).map(_tarjetaPedido),
          ],
        );
    }
  }

  Widget _vistaNegocios(List<PedidoHistorialItem> filtrados) {
    final negocios = PedidosHistorialUtils.agruparNegocios(filtrados);
    if (negocios.isEmpty) return _vacio();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: negocios.length,
      itemBuilder: (context, i) {
        final n = negocios[i];
        final pedidosNeg = PedidosHistorialUtils.pedidosDeNegocio(filtrados, n.negocioId);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.indigo.shade100,
              child: const Icon(Icons.storefront, color: Colors.indigo, size: 20),
            ),
            title: Text(n.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(
              '${n.pedidos} pedidos · Ventas \$${n.ventas.toStringAsFixed(2)} · Comisión \$${n.comisionApp.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID: ${n.negocioId}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    const Divider(),
                    ...pedidosNeg.take(20).map((p) => _tarjetaPedido(p, mostrarNegocio: false)),
                    if (pedidosNeg.length > 20)
                      Text('+ ${pedidosNeg.length - 20} pedidos más', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _vistaProductos(List<PedidoHistorialItem> filtrados) {
    final productos = PedidosHistorialUtils.todosProductos(filtrados);
    if (productos.isEmpty) return _vacio();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: productos.length,
      itemBuilder: (context, i) {
        final prod = productos[i];
        final pedidosProd = PedidosHistorialUtils.pedidosConProducto(filtrados, prod.nombre);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: const Icon(Icons.shopping_bag_outlined, color: Colors.orange, size: 20),
            ),
            title: Text(prod.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(
              '${prod.cantidad} uds · \$${prod.monto.toStringAsFixed(2)} · ${prod.pedidos} pedidos · ${prod.negocios.length} negocio(s)',
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (prod.negocios.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: prod.negocios
                            .map((n) => Chip(label: Text(n, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact))
                            .toList(),
                      ),
                    const Divider(),
                    ...pedidosProd.take(15).map((p) => _tarjetaPedido(p, productoDestacado: prod.nombre)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _vistaUsuarios(List<PedidoHistorialItem> filtrados) {
    final usuarios = PedidosHistorialUtils.agruparUsuarios(filtrados);
    if (usuarios.isEmpty) return _vacio();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: usuarios.length,
      itemBuilder: (context, i) {
        final u = usuarios[i];
        final pedidosUser = PedidosHistorialUtils.pedidosDeUsuario(filtrados, u.uid);
        final tel = _telefonosUsuarios[u.uid] ?? '';
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            leading: CircleAvatar(
              child: Text(
                _nombreUsuario(u.uid).isNotEmpty ? _nombreUsuario(u.uid)[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(_nombreUsuario(u.uid), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(
              '${u.pedidos} pedidos · Gastó \$${u.gastoTotal.toStringAsFixed(2)} · ${u.entregados} entregados'
              '${tel.isNotEmpty ? ' · $tel' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('UID: ${u.uid}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    if (u.cancelados > 0)
                      Text('Cancelados: ${u.cancelados}', style: TextStyle(fontSize: 12, color: Colors.red.shade400)),
                    const Divider(),
                    ...pedidosUser.take(20).map((p) => _tarjetaPedido(p)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: VistaAdminActividad.values.map((v) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(PedidosHistorialUtils.etiquetaVista(v)),
                      selected: _vista == v,
                      onSelected: (_) => setState(() => _vista = v),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _busquedaCtrl,
              decoration: InputDecoration(
                labelText: 'Buscar',
                hintText: 'Negocio, producto, usuario, pedido…',
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _busquedaCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _busquedaCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: PeriodoPedidosHistorial.values.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(PedidosHistorialUtils.etiquetaPeriodo(p)),
                      selected: _periodo == p,
                      onSelected: (_) => setState(() => _periodo = p),
                    ),
                  );
                }).toList(),
              ),
            ),
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: _filtroEstado == valor,
        onSelected: (_) => setState(() => _filtroEstado = valor),
      ),
    );
  }

  Widget _tarjetasGlobales(ResumenHistorialPlataforma r) {
    final g = r.general;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _miniCard('Pedidos', '${g.totalPedidos}', Icons.receipt_long, Colors.blueAccent)),
            const SizedBox(width: 8),
            Expanded(child: _miniCard('Ventas', '\$${g.ventasTotales.toStringAsFixed(0)}', Icons.payments, Colors.green)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _miniCard('Negocios', '${r.negociosConPedidos}', Icons.storefront, Colors.indigo)),
            const SizedBox(width: 8),
            Expanded(child: _miniCard('Comisión', '\$${r.comisionTotalApp.toStringAsFixed(0)}', Icons.account_balance, Colors.deepPurple)),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _filaDetalle('Entregados / En curso / Cancelados', '${g.entregados} / ${g.enProceso} / ${g.cancelados}', esMoneda: false),
                _filaDetalle('Subtotal productos', g.subtotalProductos),
                _filaDetalle('Envíos', g.totalEnvios),
                _filaDetalle('Unidades vendidas', g.unidadesVendidas.toDouble(), esMoneda: false),
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(valor, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color), textAlign: TextAlign.center),
            Text(titulo, style: const TextStyle(fontSize: 10, color: Colors.black54), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _filaDetalle(String label, dynamic valor, {bool esMoneda = true}) {
    final texto = esMoneda && valor is double
        ? '\$${valor.toStringAsFixed(2)}'
        : valor.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(texto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _listaNegociosCompacta(List<NegocioAgregadoHistorial> lista) {
    return Card(
      child: Column(
        children: lista.map((n) {
          return ListTile(
            dense: true,
            leading: const Icon(Icons.store, size: 20, color: Colors.indigo),
            title: Text(n.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text('\$${n.ventas.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${n.pedidos} pedidos'),
            onTap: () => setState(() {
              _vista = VistaAdminActividad.negocios;
              _busquedaCtrl.text = n.nombre;
            }),
          );
        }).toList(),
      ),
    );
  }

  Widget _listaProductosCompacta(List<ProductoAgregadoHistorial> lista) {
    return Card(
      child: Column(
        children: lista.map((p) {
          return ListTile(
            dense: true,
            leading: const Icon(Icons.shopping_bag, size: 20, color: Colors.orange),
            title: Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text('${p.cantidad} u', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('\$${p.monto.toStringAsFixed(0)} · ${p.negocios.length} neg.'),
            onTap: () => setState(() {
              _vista = VistaAdminActividad.productos;
              _busquedaCtrl.text = p.nombre;
            }),
          );
        }).toList(),
      ),
    );
  }

  Widget _tarjetaPedido(
    PedidoHistorialItem p, {
    bool mostrarNegocio = true,
    String? productoDestacado,
  }) {
    final color = PedidosHistorialUtils.estadoColor(p.estado);
    final tel = _telefonoUsuario(p.clienteId);
    final esRecoger = p.metodoEntrega == 'recoger';
    final direccionTexto = p.direccion.trim().isNotEmpty
        ? p.direccion
        : (esRecoger ? 'Recoger en el local' : 'Sin dirección registrada');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          radius: 18,
          child: Icon(Icons.receipt, color: color, size: 18),
        ),
        title: Text(
          '#${p.id.substring(0, 6).toUpperCase()} · \$${p.totalCobrado.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mostrarNegocio)
              Text(p.negocioNombre, style: TextStyle(fontSize: 12, color: Colors.indigo.shade700, fontWeight: FontWeight.w600)),
            Text(
              '${_nombreUsuario(p.clienteId)}${tel.isNotEmpty ? ' · $tel' : ''} · ${PedidosHistorialUtils.formatearFecha(p.fecha)}',
              style: const TextStyle(fontSize: 11),
            ),
            Text('${p.estado} · ${p.cantidadArticulos} artículo(s)', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
        children: [
          if (productoDestacado != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _textoProductoDestacado(p, productoDestacado),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          _bloqueInfoPedido(
            icon: esRecoger ? Icons.storefront : Icons.delivery_dining,
            titulo: esRecoger ? 'Recoger en local' : 'Entrega a domicilio',
            contenido: direccionTexto,
            color: Colors.blue,
          ),
          if (p.esDomicilio) ...[
            const SizedBox(height: 8),
            PedidoUbicacionEntregaBlock(pedido: p),
          ],
          if (p.tiempoEstimado.isNotEmpty) ...[
            const SizedBox(height: 8),
            _bloqueInfoPedido(
              icon: Icons.schedule,
              titulo: 'Tiempo estimado',
              contenido: p.tiempoEstimado,
              color: Colors.teal,
            ),
          ],
          if (p.notas.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _bloqueInfoPedido(
              icon: Icons.note_alt_outlined,
              titulo: 'Notas del cliente',
              contenido: p.notas,
              color: Colors.brown,
            ),
          ],
          const SizedBox(height: 10),
          Text('ID completo: ${p.id}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          if (p.productos.isNotEmpty) ...[
            const Divider(height: 20),
            const Text('Productos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ...p.productos.map((item) => PedidoProductoLinea(item: item)),
          ],
          const Divider(height: 16),
          _filaDetalle('Subtotal', p.subtotal),
          if (p.costoEnvio > 0) _filaDetalle('Envío', p.costoEnvio),
          if (p.comisionApp > 0) ...[
            _filaDetalle('Comisión app', p.comisionApp),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                p.comisionLaPagaCliente ? 'La paga el cliente' : 'La absorbe el negocio',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total cobrado', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('\$${p.totalCobrado.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _textoProductoDestacado(PedidoHistorialItem p, String nombre) {
    for (final item in p.productos) {
      if ((item['nombre'] ?? '').toString() == nombre) {
        final qty = (item['cantidad'] as num?)?.toInt() ?? 1;
        final precio = (item['precio'] as num?)?.toDouble() ?? 0;
        return '$nombre · $qty u · \$${(precio * qty).toStringAsFixed(2)}';
      }
    }
    return nombre;
  }

  Widget _bloqueInfoPedido({
    required IconData icon,
    required String titulo,
    required String contenido,
    required MaterialColor color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color.shade700),
              const SizedBox(width: 6),
              Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color.shade800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(contenido, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _seccionTitulo(String t) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );

  Widget _vacio() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No hay datos con estos filtros'),
            TextButton(
              onPressed: () => setState(() {
                _periodo = PeriodoPedidosHistorial.todos;
                _filtroEstado = FiltroEstadoPedidos.todos;
                _busquedaCtrl.clear();
              }),
              child: const Text('Limpiar filtros'),
            ),
          ],
        ),
      );
}
