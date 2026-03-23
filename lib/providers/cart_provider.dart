import 'package:flutter/material.dart';

class CartItem {
  final String id;
  final String nombre;
  final double precio;
  final String? fotoUrl;
  int cantidad;

  CartItem({required this.id, required this.nombre, required this.precio, this.fotoUrl, this.cantidad = 1});
}

class CartProvider with ChangeNotifier {
  String? _negocioIdActual;
  final Map<String, CartItem> _items = {};
  
  // --- VARIABLES DINÁMICAS DE ENVÍO ---
  double _costoEnvio = 0.0;
  String _metodoEntrega = 'domicilio'; // 'domicilio' o 'recoger'
  String? _zonaSeleccionada;

  String? get negocioIdActual => _negocioIdActual;
  Map<String, CartItem> get items => _items;
  double get costoEnvio => _costoEnvio;
  String get metodoEntrega => _metodoEntrega;
  String? get zonaSeleccionada => _zonaSeleccionada;

  // Actualiza el costo según lo que elija el cliente en el carrito
  void establecerLogistica(String metodo, double costo, {String? zona}) {
    _metodoEntrega = metodo;
    _costoEnvio = costo;
    _zonaSeleccionada = zona;
    notifyListeners();
  }

  bool agregarProducto(String negocioId, String prodId, String nombre, double precio, String? fotoUrl) {
    if (_negocioIdActual != null && _negocioIdActual != negocioId) return false; 
    _negocioIdActual = negocioId;
    if (_items.containsKey(prodId)) {
      _items[prodId]!.cantidad += 1;
    } else {
      _items[prodId] = CartItem(id: prodId, nombre: nombre, precio: precio, fotoUrl: fotoUrl);
    }
    notifyListeners();
    return true;
  }

  void incrementarCantidad(String prodId) { if (_items.containsKey(prodId)) { _items[prodId]!.cantidad += 1; notifyListeners(); } }
  void decrementarCantidad(String prodId) { if (_items.containsKey(prodId)) { if (_items[prodId]!.cantidad > 1) { _items[prodId]!.cantidad -= 1; } else { eliminarProducto(prodId); } notifyListeners(); } }
  void eliminarProducto(String prodId) { _items.remove(prodId); if (_items.isEmpty) { _negocioIdActual = null; _costoEnvio = 0; } notifyListeners(); }
  void limpiarCarrito() { _items.clear(); _negocioIdActual = null; _costoEnvio = 0.0; notifyListeners(); }

  final double tarifaPlataforma = 5.0;
  double get subtotal { double t = 0.0; _items.forEach((key, item) => t += item.precio * item.cantidad); return t; }
  double get total => _items.isEmpty ? 0.0 : subtotal + tarifaPlataforma + _costoEnvio;
}