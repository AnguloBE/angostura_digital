import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; 
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/widgets/drawer.dart';

import 'package:angostura_digital/screens/menu_negocio_screen.dart';
import 'package:angostura_digital/providers/cart_provider.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      drawer: const DrawerPrincipal(), 
      appBar: AppBar(
        title: const Text('Promociones en Angostura', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: globals.colorFondo,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), 
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('promociones').orderBy('fecha_creacion', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final promos = snapshot.data?.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['fecha_final'] == null) return true; 
            DateTime fechaLimite = (data['fecha_final'] as Timestamp).toDate();
            return fechaLimite.add(const Duration(days: 1)).isAfter(DateTime.now());
          }).toList() ?? [];

          if (promos.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.local_offer, size: 80, color: Colors.grey.shade300), const SizedBox(height: 15), const Text('Aún no hay promociones activas.', style: TextStyle(fontSize: 18, color: Colors.grey))]));
          }

          double screenWidth = MediaQuery.of(context).size.width;
          double cardWidth = screenWidth < 400 ? screenWidth - 32 : 360;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity, 
              child: Wrap(
                alignment: WrapAlignment.center, spacing: 20, runSpacing: 20,
                children: promos.map((doc) {
                  final promo = doc.data() as Map<String, dynamic>;
                  
                  String textoFecha = 'Hasta agotar existencias';
                  if (promo['fecha_final'] != null) {
                    DateTime dt = (promo['fecha_final'] as Timestamp).toDate();
                    textoFecha = 'Válido hasta: ${dt.day}/${dt.month}/${dt.year}';
                  }

                  return SizedBox(
                    width: cardWidth, 
                    child: Card(
                      elevation: 4, shadowColor: Colors.black26, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        // ==========================================
                        // SOLUCIÓN AL ERROR DEL MAP<STRING, DYNAMIC>
                        // ==========================================
                        onTap: () { 
                          // 1. Desglosamos los valores uno por uno para que el Provider los acepte
                          String idNegocio = promo['negocio_id'] ?? '';
                          String idPromo = doc.id;
                          String nombrePromo = '🔥 ${promo['titulo'] ?? 'Oferta'}';
                          double precioPromo = (promo['precio_promo'] ?? 0).toDouble();
                          String? fotoPromo = promo['foto_url'];
                          String nombreDelLocal = promo['nombre_negocio'] ?? 'Negocio';

                          final cart = Provider.of<CartProvider>(context, listen: false);
                          
                          // 2. Usamos tu función agregarProducto tal como está en el Provider
                          bool agregadoConExito = cart.agregarProducto(idNegocio, idPromo, nombrePromo, precioPromo, fotoPromo);

                          if (agregadoConExito) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('¡Oferta agregada al carrito! 🛒🤤'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2))
                            );
                            Navigator.push(context, MaterialPageRoute(builder: (_) => MenuNegocioScreen(negocioId: idNegocio, nombreNegocio: nombreDelLocal)));
                          } else {
                            // 3. Si el carrito tenía cosas de otro local, mostramos la alerta
                            showDialog(
                              context: context, 
                              builder: (ctx) => AlertDialog(
                                title: const Text('⚠️ Carrito Ocupado', style: TextStyle(fontWeight: FontWeight.bold)), 
                                content: const Text('Tu carrito tiene productos de otro restaurante. Por políticas de entrega, solo puedes pedir de un local a la vez.\n\n¿Deseas vaciar tu carrito actual y aprovechar esta oferta?'), 
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))), 
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), 
                                    onPressed: () { 
                                      cart.limpiarCarrito(); 
                                      cart.agregarProducto(idNegocio, idPromo, nombrePromo, precioPromo, fotoPromo); 
                                      Navigator.pop(ctx); 
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Carrito vaciado. Oferta agregada.'), backgroundColor: Colors.green)); 
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => MenuNegocioScreen(negocioId: idNegocio, nombreNegocio: nombreDelLocal)));
                                    }, 
                                    child: const Text('Sí, vaciar y agregar')
                                  )
                                ]
                              )
                            );
                          }
                        },
                        // ==========================================
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                SizedBox(height: 200, width: double.infinity, child: promo['foto_url'] != null ? Image.network(promo['foto_url'], fit: BoxFit.cover) : Container(color: Colors.grey.shade300, child: const Icon(Icons.image, size: 50, color: Colors.grey))),
                                Positioned(top: 15, right: 15, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]), child: const Text('¡OFERTA!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)))),
                              ],
                            ),
                            
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(promo['titulo'] ?? 'Sin título', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text('Por: ${promo['nombre_negocio'] ?? 'Negocio local'}', style: TextStyle(fontSize: 14, color: Colors.blueAccent.shade700, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  if (promo['descripcion'] != null && promo['descripcion'].toString().isNotEmpty)
                                    Text(promo['descripcion'], style: TextStyle(fontSize: 14, color: Colors.grey.shade700), maxLines: 3, overflow: TextOverflow.ellipsis),
                                  const Divider(height: 20),
                                  
                                  Row(children: [const Icon(Icons.timer_outlined, size: 16, color: Colors.redAccent), const SizedBox(width: 4), Text(textoFecha, style: const TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.bold))]),
                                  const SizedBox(height: 10),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Precio normal', style: TextStyle(fontSize: 12, color: Colors.grey)), Text('\$${promo['precio_normal']}', style: const TextStyle(fontSize: 16, color: Colors.grey, decoration: TextDecoration.lineThrough, fontWeight: FontWeight.bold))]),
                                      Row(children: [const Text('A solo: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)), Text('\$${promo['precio_promo']}', style: const TextStyle(fontSize: 26, color: Colors.green, fontWeight: FontWeight.bold))])
                                    ],
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}