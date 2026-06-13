/// Tipos de negocio soportados por la app.
class CategoriasNegocio {
  CategoriasNegocio._();

  static const String restaurante = 'Restaurante / Comida';
  static const String productos = 'Productos';
  static const String servicios = 'Servicios';

  static const List<String> lista = [restaurante, productos, servicios];

  static bool esRestaurante(String? categoria) => categoria == restaurante;

  static bool esServicios(String? categoria) => categoria == servicios;

  /// Tienda con inventario (abarrotes, farmacias, etc.).
  static bool esProductos(String? categoria) =>
      categoria == productos || (!esRestaurante(categoria) && !esServicios(categoria));

  /// Restaurantes y tiendas pueden registrar ventas en el local (no servicios/citas).
  static bool puedeVentaEnLocal(String? categoria) => !esServicios(categoria);

  static String etiquetaVentaEnLocal(String? categoria) =>
      esRestaurante(categoria) ? 'Nuevo pedido' : 'Nueva venta';

  static String etiquetaVentaEnLocalLargo(String? categoria) =>
      esRestaurante(categoria) ? 'Nuevo pedido en local' : 'Nueva venta en tienda';

  static String normalizar(String? categoria) {
    if (categoria == restaurante) return restaurante;
    if (categoria == servicios) return servicios;
    return productos;
  }
}
