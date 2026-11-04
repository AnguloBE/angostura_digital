import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:angostura_digital/providers/cart_provider.dart';
import 'package:angostura_digital/screens/carrito_screen.dart';

import 'package:angostura_digital/screens/home_tab.dart'; 
import 'package:angostura_digital/screens/explorar_tab.dart';
import 'package:angostura_digital/screens/pedidos_tab.dart';
class MainNavigation extends StatefulWidget {
  final int initialIndex; // Agregamos esto
  
  // Le decimos que por defecto inicie en 0 (Inicio)
  const MainNavigation({super.key, this.initialIndex = 0}); 

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _currentIndex; // Cambiamos a late

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  final List<Widget> _pantallas = [
    const HomeTab(),
    const ExplorarTab(),
    const PedidosTab(),
    //const PerfilTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pantallas[_currentIndex],

      // El botón escucha el carrito por su cuenta. Si el menú entero
      // lo escuchara, al agregar un producto se redibujarían las fotos.
      floatingActionButton: const _BotonCarritoFlotante(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      bottomNavigationBar: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseAuth.instance.currentUser == null
            ? null
            : FirebaseFirestore.instance
                .collection('pedidos')
                .where('cliente_id', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                .limit(40)
                .snapshots(),
        builder: (context, snap) {
          final activos = snap.data?.docs.where((d) {
                final estado = (d.data()['estado'] ?? '').toString();
                return estado != 'Entregado' && estado != 'Cancelado' && estado != 'Confirmada';
              }).length ??
              0;
          return NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: [
              const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
              const NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search), label: 'Explorar'),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: activos > 0,
                  label: Text(activos > 99 ? '99+' : '$activos'),
                  child: const Icon(Icons.receipt_long_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: activos > 0,
                  label: Text(activos > 99 ? '99+' : '$activos'),
                  child: const Icon(Icons.receipt_long),
                ),
                label: 'Pedidos',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BotonCarritoFlotante extends StatelessWidget {
  const _BotonCarritoFlotante();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    if (!cart.tieneCompraPersonal) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.shopping_cart),
      label: Text('Ver Carrito ( \$${cart.total.toStringAsFixed(2)} )'),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CarritoScreen()),
        );
      },
    );
  }
}