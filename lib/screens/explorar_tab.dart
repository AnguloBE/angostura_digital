import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:provider/provider.dart';
import 'package:angostura_digital/providers/cart_provider.dart';
import 'package:angostura_digital/screens/menu_negocio_screen.dart';

class ExplorarTab extends StatefulWidget {
  const ExplorarTab({super.key});
  @override
  State<ExplorarTab> createState() => _ExplorarTabState();
}

class _ExplorarTabState extends State<ExplorarTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _categoriaSeleccionada = ''; 

  Future<void> _navegarAMenu(BuildContext context, String negocioId) async {
    final negDoc = await FirebaseFirestore.instance.collection('negocios').doc(negocioId).get();
    String nombreNeg = 'Local'; String? fotoNeg;
    if (negDoc.exists && negDoc.data() != null) { final negData = negDoc.data() as Map<String, dynamic>; nombreNeg = negData['nombre'] ?? 'Local'; fotoNeg = negData['foto_url']; }
    if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => MenuNegocioScreen(negocioId: negocioId, nombreNegocio: nombreNeg, fotoUrl: fotoNeg)));
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
    final partes = hhmm.split(':'); int h = int.parse(partes[0]); final m = partes[1]; final ampm = h >= 12 ? 'PM' : 'AM';
    if (h > 12) h -= 12; if (h == 0) h = 12; return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Container(height: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: TextField(controller: _searchController, autofocus: false, decoration: InputDecoration(hintText: 'Buscar locales, ej. Capomos...', hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14), prefixIcon: const Icon(Icons.search, color: Colors.grey), suffixIcon: _searchQuery.isNotEmpty || _categoriaSeleccionada.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _searchController.clear(); setState(() { _searchQuery = ''; _categoriaSeleccionada = ''; }); }) : null, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 10)), onChanged: (value) { setState(() { _searchQuery = value.toLowerCase().trim(); _categoriaSeleccionada = ''; }); })), backgroundColor: globals.colorFondo),
      body: _searchQuery.isEmpty && _categoriaSeleccionada.isEmpty ? _buildEstadoInicial() : _buildResultadosBusqueda(),
    );
  }

  Widget _buildEstadoInicial() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [_chipCategoria('Restaurante / Comida', Icons.restaurant, Colors.orange), const SizedBox(width: 8), _chipCategoria('Abarrotes y Supermercados', Icons.store, Colors.green), const SizedBox(width: 8), _chipCategoria('Farmacias', Icons.medical_services, Colors.blue), const SizedBox(width: 8), _chipCategoria('Ropa y Accesorios', Icons.checkroom, Colors.pink)])),
        const SizedBox(height: 30), const Text('Negocios Populares', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 15),
        
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('negocios').where('estado', isEqualTo: 'aprobado').limit(10).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final negocios = snapshot.data!.docs;
            if (negocios.isEmpty) return const Text('Próximamente más locales...', style: TextStyle(color: Colors.grey));
            return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: Column(children: negocios.map((doc) => _tarjetaNegocio(doc)).toList())));
          },
        ),
      ],
    );
  }

  Widget _chipCategoria(String titulo, IconData icono, Color color) { return ActionChip(avatar: Icon(icono, color: color, size: 18), label: Text(titulo, style: const TextStyle(fontSize: 14)), backgroundColor: color.withOpacity(0.1), side: BorderSide.none, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), onPressed: () { setState(() { _categoriaSeleccionada = titulo; _searchController.text = titulo; _searchQuery = ''; }); }); }
  Widget _buildResultadosBusqueda() { return ListView(padding: const EdgeInsets.all(16), children: [const Text('NEGOCIOS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)), const SizedBox(height: 10), _buildStreamNegocios(), const SizedBox(height: 20), const Divider(), const SizedBox(height: 10), const Text('PRODUCTOS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)), const SizedBox(height: 10), _buildStreamProductos()]); }

  Widget _buildStreamNegocios() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('negocios').where('estado', isEqualTo: 'aprobado').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        final negocios = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (_categoriaSeleccionada.isNotEmpty) return data['categoria'] == _categoriaSeleccionada;
          
          final nombre = (data['nombre'] ?? '').toString().toLowerCase(); 
          final ubicacion = data.containsKey('ubicacion') ? (data['ubicacion'] ?? '').toString().toLowerCase() : '';
          
          // Buscamos la zona de envío sin importar cómo se guarde
          final zonaEnvio = (data['zona_envio'] ?? data['zona'] ?? data['zonas'] ?? '').toString().toLowerCase();
          
          return nombre.contains(_searchQuery) || ubicacion.contains(_searchQuery) || zonaEnvio.contains(_searchQuery);
        }).toList();
        if (negocios.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('No hay locales.', style: TextStyle(color: Colors.grey.shade600)));
        return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: Column(children: negocios.map((doc) => _tarjetaNegocio(doc)).toList())));
      },
    );
  }

  Widget _tarjetaNegocio(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    String? estadoCierre = _verificarHorario(data['horario'] as Map<String, dynamic>?);
    bool isAbierto = estadoCierre == null;
    
    String ubicacion = data['ubicacion'] ?? ''; 
    // Atrapamos la zona de envío (ya sea zona_envio, zona o zonas)
    String zonaEnvio = (data['zona_envio'] ?? data['zona'] ?? data['zonas'] ?? '').toString(); 

    return GestureDetector(
      onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => MenuNegocioScreen(negocioId: doc.id, nombreNegocio: data['nombre'] ?? 'Local', fotoUrl: data['foto_url']))); },
      child: Card(
        elevation: 0, margin: const EdgeInsets.only(bottom: 12), color: Colors.grey.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(50), child: SizedBox(width: 70, height: 70, child: data['foto_url'] != null ? Image.network(data['foto_url'], fit: BoxFit.cover, color: !isAbierto ? Colors.black.withOpacity(0.5) : null, colorBlendMode: !isAbierto ? BlendMode.saturation : null) : Container(color: Colors.grey.shade300, child: const Icon(Icons.store, color: Colors.grey, size: 30)))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Text(data['nombre'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: !isAbierto ? Colors.grey : Colors.black)), 
                    const SizedBox(height: 4), 
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4,
                      children: [
                        Text(data['categoria'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                        if (ubicacion.isNotEmpty)
                          Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.location_on, size: 14, color: Colors.red.shade400), const SizedBox(width: 2), Text(ubicacion, style: TextStyle(color: Colors.grey.shade800, fontSize: 12, fontWeight: FontWeight.w600))]),
                        if (zonaEnvio.isNotEmpty)
                          Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.delivery_dining, size: 14, color: Colors.blue.shade400), const SizedBox(width: 2), Text('Envía a: $zonaEnvio', style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.bold))]),
                        if (!isAbierto) 
                          Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade200)), child: Text(estadoCierre!.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold))),
                      ],
                    )
                  ]
                )
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreamProductos() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('productos').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        final productos = snapshot.data!.docs.where((doc) {
          if (_categoriaSeleccionada.isNotEmpty) return doc['categoria_negocio'] == _categoriaSeleccionada;
          final nombre = (doc['nombre'] ?? '').toString().toLowerCase(); final descripcion = (doc['descripcion'] ?? '').toString().toLowerCase();
          return nombre.contains(_searchQuery) || descripcion.contains(_searchQuery);
        }).toList();
        if (productos.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('No encontramos este producto.', style: TextStyle(color: Colors.grey.shade600)));

        return Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              double maxW = constraints.maxWidth; if (maxW.isInfinite || maxW <= 0) maxW = MediaQuery.of(context).size.width - 32;
              int crossAxisCount = (maxW / 180).ceil(); if (crossAxisCount < 2) crossAxisCount = 2; 
              final double spacing = 12; final double totalSpacing = spacing * (crossAxisCount - 1); final double itemWidth = (maxW - totalSpacing) / crossAxisCount;

              return Wrap(
                spacing: spacing, runSpacing: spacing,
                children: productos.map((doc) => SizedBox(width: itemWidth > 0 ? itemWidth : 150, child: _tarjetaProducto(doc))).toList(),
              );
            },
          ),
        );
      },
    );
  }

  Widget _infoChip(String texto) { return Padding(padding: const EdgeInsets.only(bottom: 4.0), child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)), child: Text(texto, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500)))); }

  Widget _tarjetaProducto(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    String negocioId = data['negocio_id'] ?? 'ID_DESCONOCIDO';
    List<Widget> extraWidgets = [];
    if (data['ingredientes'] != null && data['ingredientes'].toString().isNotEmpty) extraWidgets.add(_infoChip('Ingredientes: ${data['ingredientes']}'));
    if (data['peso_o_contenido'] != null && data['peso_o_contenido'].toString().isNotEmpty) extraWidgets.add(_infoChip('Cont: ${data['peso_o_contenido']}'));
    if (data['codigo_barras'] != null && data['codigo_barras'].toString().isNotEmpty) extraWidgets.add(_infoChip('Cód: ${data['codigo_barras']}'));
    if (data['tallas_disponibles'] != null && data['tallas_disponibles'].toString().isNotEmpty) extraWidgets.add(_infoChip('Tallas: ${data['tallas_disponibles']}'));
    if (data['colores'] != null && data['colores'].toString().isNotEmpty) extraWidgets.add(_infoChip('Colores: ${data['colores']}'));

    return Card(
      elevation: 3, shadowColor: Colors.black26, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navegarAMenu(context, negocioId),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(aspectRatio: 1, child: SizedBox(width: double.infinity, child: data['foto_url'] != null ? Image.network(data['foto_url'], fit: BoxFit.cover) : Container(color: Colors.grey.shade200, child: const Icon(Icons.fastfood, color: Colors.grey, size: 50)))),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['nombre'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.15, color: Colors.black87)),
                  const SizedBox(height: 6), Text('\$${data['precio']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 17)),
                  if (data['descripcion'] != null && data['descripcion'].toString().isNotEmpty) ...[const SizedBox(height: 6), Text(data['descripcion'], style: TextStyle(fontSize: 13, color: Colors.grey.shade800))],
                  if (extraWidgets.isNotEmpty) ...[const SizedBox(height: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: extraWidgets)],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: GestureDetector(
                      onTap: () {
                        final cart = Provider.of<CartProvider>(context, listen: false);
                        bool exito = cart.agregarProducto(negocioId, doc.id, data['nombre'] ?? '', (data['precio'] ?? 0).toDouble(), data['foto_url'] ?? '');
                        if (exito) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${data['nombre']} agregado'), duration: const Duration(seconds: 1), backgroundColor: Colors.green));
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
  }
}