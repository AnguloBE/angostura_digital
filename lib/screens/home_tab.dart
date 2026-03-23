import 'package:flutter/material.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/widgets/drawer.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const DrawerPrincipal(), // Accesible desde el icono del AppBar
      body: CustomScrollView(
        slivers: [
          // 1. App Bar Dinámico
          SliverAppBar(
            floating: true,
            pinned: true,
            backgroundColor: globals.colorFondo,
            foregroundColor: Colors.white,
            title: const Text('Angostura Digital', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  // Ir al carrito
                },
              )
            ],
          ),

          // 2. Banners de Promociones (Horizontal)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(16),
                itemCount: 3,
                itemBuilder: (context, index) {
                  return Container(
                    width: 280,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Center(child: Text('Banner de Oferta')),
                  );
                },
              ),
            ),
          ),

          // 3. Categorías (Círculos)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Categorías', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 90,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: const [
                        _CategoriaItem(icon: Icons.fastfood, label: 'Comida'),
                        _CategoriaItem(icon: Icons.local_pharmacy, label: 'Farmacia'),
                        _CategoriaItem(icon: Icons.shopping_bag, label: 'Abarrotes'),
                        _CategoriaItem(icon: Icons.checkroom, label: 'Ropa'),
                        _CategoriaItem(icon: Icons.more_horiz, label: 'Más'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Feed de Negocios Destacados
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: const Text('Negocios Destacados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // Aquí iría tu StreamBuilder consultando Firebase
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.store),
                    ),
                    title: Text('Negocio de Ejemplo $index', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Comida rápida • Envío \$20\nAbierto ahora', style: TextStyle(height: 1.5)),
                    isThreeLine: true,
                    onTap: () {
                      // Ir a la vista del negocio
                    },
                  ),
                );
              },
              childCount: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriaItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CategoriaItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.blue.shade50,
            child: Icon(icon, color: Colors.blueAccent, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}