import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Para carga rápida
import 'package:angostura_digital/widgets/drawer.dart';
import 'package:angostura_digital/globals.dart' as globals;

class AnunciosScreen extends StatefulWidget {
  const AnunciosScreen({super.key});

  @override
  State<AnunciosScreen> createState() => _AnunciosScreenState();
}

class _AnunciosScreenState extends State<AnunciosScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Angostura Digital'),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      drawer: const DrawerPrincipal(),
      body: StreamBuilder<QuerySnapshot>(
        // FILTRO MAESTRO: Solo productos de negocios que ya existen (puedes mejorar este filtro luego)
        stream: FirebaseFirestore.instance
            .collection('productos')
            .orderBy('fecha_creacion', descending: true) // Lo más nuevo primero
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Aún no hay productos disponibles.', style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }

          final productos = snapshot.data!.docs;

          // --- DISEÑO GRID (Cuadrícula) RESPONSIVO ---
          // Usamos un LayoutBuilder para decidir cuántas columnas poner según el ancho de pantalla
          return LayoutBuilder(
            builder: (context, constraints) {
              // Si es celular (ancho < 600), ponemos 2 columnas. Si es Web/Tablet, ponemos 3 o 4.
              int crossAxisCount = constraints.maxWidth < 600 ? 2 : (constraints.maxWidth < 900 ? 3 : 4);

              return GridView.builder(
                padding: const EdgeInsets.all(10),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount, // Columnas dinámicas
                  crossAxisSpacing: 10, // Espacio horizontal entre tarjetas
                  mainAxisSpacing: 10, // Espacio vertical
                  childAspectRatio: 0.75, // OBLIGAMOS A FORMATO PORTRAIT (La foto cuadrada arriba y espacio para texto abajo)
                ),
                itemCount: productos.length,
                itemBuilder: (context, index) {
                  final doc = productos[index];
                  final prod = doc.data() as Map<String, dynamic>;

                  return WidgetProductoCard(prod: prod);
                },
              );
            },
          );
        },
      ),
    );
  }
}

// --- EL COMPONENTE DE LA TARJETA DE PRODUCTO (Estilo Diseñador) ---
class WidgetProductoCard extends StatelessWidget {
  final Map<String, dynamic> prod;

  const WidgetProductoCard({super.key, required this.prod});

  @override
  Widget build(BuildContext context) {
    final String nombre = prod['nombre'] ?? 'Sin nombre';
    final double precio = prod['precio'] ?? 0.0;
    final String? fotoUrl = prod['foto_url'];

    return Card(
      elevation: 4, // Sombrita para dar profundidad
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), // Bordes redondeados modernos
      clipBehavior: Clip.antiAlias, // Para que la imagen no se salga de los bordes redondeados
      child: InkWell(
        onTap: () {
          // Aquí abrirás el detalle del producto en el futuro
          print("Tocado: $nombre");
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. LA IMAGEN (Highlight / Protagonista)
            AspectRatio(
              aspectRatio: 1, // HACEMOS QUE EL ÁREA DE LA FOTO SEA UN CUADRADO PERFECTO
              child: fotoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: fotoUrl,
                      fit: BoxFit.cover, // La imagen cuadrada recortada llenará este espacio perfectamente
                      placeholder: (context, url) => Container(color: Colors.grey.shade200, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                    )
                  : Container(color: Colors.grey.shade200, child: const Icon(Icons.image, size: 50, color: Colors.grey)),
            ),
            
            // 2. DETALLES (Abajo)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Precio siempre abajo
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 2, // Máximo dos líneas para el nombre
                      overflow: TextOverflow.ellipsis, // Pone "..." si es muy largo
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${precio.toStringAsFixed(2)}', // Formato $100.00
                          style: const TextStyle(
                            color: Colors.green, // Precio resalta en verde
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Un iconito pequeño decorativo según categoría
                        Icon(
                          _getIconoCategoria(prod['categoria_negocio']),
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconoCategoria(String? categoria) {
    switch (categoria) {
      case 'Restaurante / Comida': return Icons.fastfood;
      case 'Ropa y Accesorios': return Icons.checkroom;
      case 'Abarrotes y Supermercados': return Icons.local_grocery_store;
      default: return Icons.shutter_speed;
    }
  }
}