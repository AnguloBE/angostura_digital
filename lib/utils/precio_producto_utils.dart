/// Costo, precio de venta y precio con descuento de un producto o servicio.
class PrecioCobrado {
  final double cobrar;
  final double venta;

  /// Precio con descuento guardado en el producto. Null si no tiene.
  final double? descuento;

  /// True cuando se está cobrando el precio con descuento, distinto al de venta.
  final bool aplicado;

  const PrecioCobrado({
    required this.cobrar,
    required this.venta,
    this.descuento,
    this.aplicado = false,
  });

  const PrecioCobrado.cero()
      : cobrar = 0,
        venta = 0,
        descuento = null,
        aplicado = false;
}

class PrecioProducto {
  PrecioProducto._();

  static double leer(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}'.trim()) ?? 0;
  }

  static double venta(Map<String, dynamic> data) => leer(data['precio']);

  static double costo(Map<String, dynamic> data) => leer(data['costo']);

  static double descuento(Map<String, dynamic> data) => leer(data['precio_descuento']);

  static bool tieneDescuento(Map<String, dynamic> data) => descuento(data) > 0;

  /// [conDescuento] lo decide el rol: cliente con descuento, o el mostrador
  /// cuando elige cobrar ese precio. Si el producto no tiene descuento, se cobra la venta.
  static PrecioCobrado resolver(
    Map<String, dynamic> data, {
    required bool conDescuento,
    bool sinDinero = false,
  }) {
    if (sinDinero) return const PrecioCobrado.cero();
    final precioVenta = venta(data);
    final precioDesc = tieneDescuento(data) ? descuento(data) : null;
    final aplicado = conDescuento && precioDesc != null && precioDesc != precioVenta;
    return PrecioCobrado(
      cobrar: aplicado ? precioDesc : precioVenta,
      venta: precioVenta,
      descuento: precioDesc,
      aplicado: aplicado,
    );
  }

  static String texto(double n) {
    if (n == n.roundToDouble()) return '\$${n.toStringAsFixed(0)}';
    return '\$${n.toStringAsFixed(2)}';
  }

  /// Texto para un campo. Vacío si no hay un monto cargado.
  static String campo(dynamic v) {
    final n = leer(v);
    if (n <= 0) return '';
    if (n == n.roundToDouble()) return n.toStringAsFixed(0);
    return n.toString();
  }
}
