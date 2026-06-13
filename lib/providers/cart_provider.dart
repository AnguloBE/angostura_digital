import 'package:flutter/material.dart';

import '../utils/comision_app_utils.dart';

/// Un ingrediente extra que el cliente agregó (con su costo).
class ExtraIngrediente {
  final String nombre;
  final double precio;

  const ExtraIngrediente({required this.nombre, this.precio = 0});

  Map<String, dynamic> toMap() => {'nombre': nombre, 'precio': precio};
}

class CartItem {
  /// Identificador único de la línea en el carrito (permite varias variantes
  /// del mismo producto, ej. una hamburguesa con cebolla y otra sin).
  final String lineaId;

  /// Id del producto/promoción en Firestore.
  final String id;
  final String nombre;

  /// Precio base del producto (sin extras).
  final double precioBase;
  final String? fotoUrl;
  final Map<String, String> detalles;
  final bool esPromocion;

  /// Ingredientes que el platillo incluye por defecto.
  final List<String> ingredientesBase;

  /// Ingredientes que el cliente pidió quitar.
  List<String> ingredientesQuitados;

  /// Ingredientes extra que el cliente agregó (con costo).
  List<ExtraIngrediente> extras;

  /// Stock disponible al momento de agregar (null = sin control de inventario).
  int? stockDisponible;

  /// Servicio con cita o solicitud a domicilio.
  final bool esServicio;
  final String? tipoServicio; // 'cita' | 'solicitud'
  final DateTime? citaInicio;
  final int duracionMinutos;

  int cantidad;

  CartItem({
    required this.lineaId,
    required this.id,
    required this.nombre,
    required this.precioBase,
    this.fotoUrl,
    this.detalles = const {},
    this.esPromocion = false,
    List<String>? ingredientesBase,
    List<String>? ingredientesQuitados,
    List<ExtraIngrediente>? extras,
    this.stockDisponible,
    this.esServicio = false,
    this.tipoServicio,
    this.citaInicio,
    this.duracionMinutos = 0,
    this.cantidad = 1,
  })  : ingredientesBase = ingredientesBase ?? const [],
        ingredientesQuitados = ingredientesQuitados ?? [],
        extras = extras ?? [];

  double get precioExtras => extras.fold(0.0, (suma, e) => suma + e.precio);

  /// Precio por unidad ya con los extras incluidos.
  double get precio => precioBase + precioExtras;

  bool get tienePersonalizacion =>
      ingredientesQuitados.isNotEmpty || extras.isNotEmpty;

  Map<String, dynamic> toPedidoMap() => {
        'id': id,
        'nombre': nombre,
        'precio': precio,
        'precio_base': precioBase,
        'cantidad': cantidad,
        if (fotoUrl != null && fotoUrl!.isNotEmpty) 'foto_url': fotoUrl,
        if (esPromocion) 'es_promocion': true,
        if (detalles.isNotEmpty) 'detalles': detalles,
        if (ingredientesBase.isNotEmpty) 'ingredientes_base': ingredientesBase,
        if (ingredientesQuitados.isNotEmpty)
          'ingredientes_quitados': ingredientesQuitados,
        if (extras.isNotEmpty) 'extras': extras.map((e) => e.toMap()).toList(),
        if (esServicio) 'es_servicio': true,
        if (tipoServicio != null) 'tipo_servicio': tipoServicio,
        if (citaInicio != null) 'cita_inicio': citaInicio!.toIso8601String(),
        if (duracionMinutos > 0) 'duracion_minutos': duracionMinutos,
      };
}

class CartProvider with ChangeNotifier {
  String? _negocioIdActual;
  final Map<String, CartItem> _items = {};
  int _secuenciaLinea = 0;

  String _generarLineaId(String prodId) => '${prodId}__${_secuenciaLinea++}';
  
  // --- VARIABLES DINÁMICAS DE ENVÍO ---
  double _costoEnvio = 0.0;
  double _comisionApp = 0.0;
  String _metodoEntrega = 'domicilio';
  String _comisionPagadaPor = 'negocio';
  double? _distanciaEnvioKm;

  String? get negocioIdActual => _negocioIdActual;
  Map<String, CartItem> get items => _items;
  double get costoEnvio => _costoEnvio;
  double get comisionApp => _comisionApp;
  String get comisionPagadaPor => _comisionPagadaPor;
  String get metodoEntrega => _metodoEntrega;
  double? get distanciaEnvioKm => _distanciaEnvioKm;
  bool get comisionLaPagaCliente => ComisionAppUtils.cobrarExtraAlCliente(_comisionPagadaPor);

  void establecerLogistica(
    String metodo,
    double costo, {
    double? distanciaKm,
  }) {
    _metodoEntrega = metodo;
    _costoEnvio = costo;
    _distanciaEnvioKm = distanciaKm;
    notifyListeners();
  }

  void establecerComisionApp(double monto, String pagadaPor) {
    _comisionApp = monto;
    _comisionPagadaPor = pagadaPor;
    notifyListeners();
  }

  bool agregarProducto(
    String negocioId,
    String prodId,
    String nombre,
    double precio,
    String? fotoUrl, {
    Map<String, String> detalles = const {},
    bool esPromocion = false,
    List<String> ingredientesBase = const [],
    int? stockDisponible,
  }) {
    if (_negocioIdActual != null && _negocioIdActual != negocioId) return false;
    _negocioIdActual = negocioId;

    // Buscar una línea existente del mismo producto SIN personalizar para sumar.
    CartItem? mergeable;
    for (final item in _items.values) {
      if (item.id == prodId && !item.tienePersonalizacion) {
        mergeable = item;
        break;
      }
    }

    if (mergeable != null) {
      mergeable.cantidad += 1;
      mergeable.stockDisponible = stockDisponible;
    } else {
      final lineaId = _generarLineaId(prodId);
      _items[lineaId] = CartItem(
        lineaId: lineaId,
        id: prodId,
        nombre: nombre,
        precioBase: precio,
        fotoUrl: fotoUrl,
        detalles: detalles,
        esPromocion: esPromocion,
        ingredientesBase: ingredientesBase,
        stockDisponible: stockDisponible,
      );
    }
    notifyListeners();
    return true;
  }

  /// Agrega un servicio (cita con hora o solicitud sin calendario).
  bool agregarServicio(
    String negocioId,
    String servicioId,
    String nombre,
    double precio,
    String? fotoUrl, {
    required String tipoServicio,
    DateTime? citaInicio,
    int duracionMinutos = 30,
  }) {
    if (_negocioIdActual != null && _negocioIdActual != negocioId) return false;
    _negocioIdActual = negocioId;

    // Citas: una línea por horario (no fusionar).
    if (tipoServicio == 'cita' && citaInicio != null) {
      for (final item in _items.values) {
        if (item.esServicio &&
            item.tipoServicio == 'cita' &&
            item.citaInicio == citaInicio) {
          return false;
        }
      }
    }

    final lineaId = _generarLineaId(servicioId);
    _items[lineaId] = CartItem(
      lineaId: lineaId,
      id: servicioId,
      nombre: nombre,
      precioBase: precio,
      fotoUrl: fotoUrl,
      esServicio: true,
      tipoServicio: tipoServicio,
      citaInicio: citaInicio,
      duracionMinutos: duracionMinutos,
      cantidad: 1,
    );
    notifyListeners();
    return true;
  }

  bool get tieneServicioSolicitud =>
      _items.values.any((i) => i.esServicio && i.tipoServicio == 'solicitud');

  bool get tieneServicioCita =>
      _items.values.any((i) => i.esServicio && i.tipoServicio == 'cita');

  bool get esCarritoServicios =>
      _items.isNotEmpty && _items.values.every((i) => i.esServicio);

  /// Cuántas piezas de un producto (sumando variantes) hay en el carrito.
  int cantidadEnCarrito(String prodId) {
    var total = 0;
    for (final item in _items.values) {
      if (item.id == prodId) total += item.cantidad;
    }
    return total;
  }

  /// Aplica la personalización de una línea del carrito.
  void personalizarItem(
    String lineaId, {
    required List<String> quitados,
    required List<ExtraIngrediente> extras,
  }) {
    final item = _items[lineaId];
    if (item == null) return;
    item.ingredientesQuitados = quitados;
    item.extras = extras;
    notifyListeners();
  }

  /// Separa [cantidad] unidades de una línea para personalizarlas aparte.
  /// Si [cantidad] cubre toda la línea, se edita la misma (no se separa).
  /// Devuelve el id de la línea que debe personalizarse.
  String separarParaPersonalizar(String lineaId, int cantidad) {
    final base = _items[lineaId];
    if (base == null) return lineaId;
    if (cantidad >= base.cantidad || cantidad <= 0) return lineaId;

    base.cantidad -= cantidad;
    final nuevoId = _generarLineaId(base.id);
    _items[nuevoId] = CartItem(
      lineaId: nuevoId,
      id: base.id,
      nombre: base.nombre,
      precioBase: base.precioBase,
      fotoUrl: base.fotoUrl,
      detalles: base.detalles,
      esPromocion: base.esPromocion,
      ingredientesBase: base.ingredientesBase,
      ingredientesQuitados: [...base.ingredientesQuitados],
      extras: [...base.extras],
      cantidad: cantidad,
    );
    notifyListeners();
    return nuevoId;
  }

  void incrementarCantidad(String lineaId) { if (_items.containsKey(lineaId)) { _items[lineaId]!.cantidad += 1; notifyListeners(); } }
  void decrementarCantidad(String lineaId) { if (_items.containsKey(lineaId)) { if (_items[lineaId]!.cantidad > 1) { _items[lineaId]!.cantidad -= 1; } else { eliminarProducto(lineaId); } notifyListeners(); } }
  void eliminarProducto(String lineaId) { _items.remove(lineaId); if (_items.isEmpty) { _negocioIdActual = null; _costoEnvio = 0; } notifyListeners(); }
  void limpiarCarrito() {
    _items.clear();
    _negocioIdActual = null;
    _costoEnvio = 0.0;
    _comisionApp = 0.0;
    _comisionPagadaPor = 'negocio';
    notifyListeners();
  }

  double get subtotal {
    double t = 0.0;
    _items.forEach((key, item) => t += item.precio * item.cantidad);
    return t;
  }

  double get total {
    if (_items.isEmpty) return 0.0;
    final extraComision = comisionLaPagaCliente ? _comisionApp : 0.0;
    return subtotal + _costoEnvio + extraComision;
  }
}