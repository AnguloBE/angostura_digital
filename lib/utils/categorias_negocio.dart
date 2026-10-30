/// Tipos de negocio soportados por la app.
class CategoriasNegocio {
  CategoriasNegocio._();

  static const String restaurante = 'Restaurante / Comida';
  static const String productos = 'Productos';
  static const String servicios = 'Servicios';
  static const String bodega = 'Bodega';

  static const List<String> lista = [restaurante, productos, servicios, bodega];

  /// Categorías que aparecen en Explorar (chips y búsqueda pública).
  static const List<String> listaPublica = [restaurante, productos, servicios];

  static bool esRestaurante(String? categoria) => categoria == restaurante;

  static bool esServicios(String? categoria) => categoria == servicios;

  static bool esBodega(String? categoria) => categoria == bodega;

  /// Tienda con inventario (abarrotes, farmacias, etc.).
  static bool esProductos(String? categoria) => categoria == productos;

  /// Bodega o tienda: stock, ubicaciones, mercancía, surtido.
  static bool usaInventario(String? categoria) => esProductos(categoria) || esBodega(categoria);

  /// Nunca visible en Explorar ni comprable por clientes.
  static bool visibleAlPublico(String? categoria) => !esBodega(categoria);

  /// Salidas de inventario sin precios ni cobros.
  static bool sinRegistroDinero(String? categoria) => esBodega(categoria);

  /// Restaurantes, tiendas y bodegas pueden registrar movimientos en el local.
  static bool puedeVentaEnLocal(String? categoria) => !esServicios(categoria);

  static String etiquetaVentaEnLocal(String? categoria) {
    if (esBodega(categoria)) return 'Sacar producto';
    if (esRestaurante(categoria)) return 'Nuevo pedido';
    return 'Nueva venta';
  }

  static String etiquetaVentaEnLocalLargo(String? categoria) {
    if (esBodega(categoria)) return 'Sacar producto de bodega';
    if (esRestaurante(categoria)) return 'Nuevo pedido en local';
    return 'Nueva venta en tienda';
  }

  static String etiquetaHistorial(String? categoria) =>
      esBodega(categoria) ? 'Historial de salidas' : 'Historial y ventas';

  static String normalizar(String? categoria) {
    if (categoria == restaurante) return restaurante;
    if (categoria == servicios) return servicios;
    if (categoria == bodega) return bodega;
    return productos;
  }
}
