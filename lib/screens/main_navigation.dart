import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:angostura_digital/providers/cart_provider.dart';
import 'package:angostura_digital/screens/carrito_screen.dart';

import 'package:angostura_digital/screens/home_tab.dart'; 
import 'package:angostura_digital/screens/explorar_tab.dart';
import 'package:angostura_digital/screens/pedidos_tab.dart';
import 'package:angostura_digital/screens/perfil_tab.dart';

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
    // Inicia en la pestaña que le pasemos
    _currentIndex = widget.initialIndex; 
  }

  final List<Widget> _pantallas = [
    const HomeTab(),
    const ExplorarTab(),
    const PedidosTab(),
    const PerfilTab(),
  ];

  @override
  Widget build(BuildContext context) {
    // Escuchamos el carrito para saber si hay productos
    final cart = context.watch<CartProvider>();

    return Scaffold(
      body: _pantallas[_currentIndex],
      
      // EL CARRITO FLOTANTE
      floatingActionButton: cart.items.isNotEmpty
          ? FloatingActionButton.extended(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.shopping_cart),
              label: Text('Ver Carrito ( \$${cart.total.toStringAsFixed(2)} )'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CarritoScreen()));
              },
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search), label: 'Explorar'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Pedidos'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}