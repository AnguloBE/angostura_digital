import 'package:flutter/material.dart';

/// Tipos de negocio soportados por la app.
class CategoriasNegocio {
  CategoriasNegocio._();

  static const String restaurante = 'Restaurante / Comida';
  static const String postres = 'Postres y Antojos';
  static const String productos = 'Productos';
  static const String farmacia = 'Farmacia';
  static const String imprenta = 'Imprenta';
  static const String servicios = 'Servicios';
  static const String bodega = 'Bodega';

  static const List<String> lista = [
    restaurante,
    postres,
    productos,
    farmacia,
    imprenta,
    servicios,
    bodega,
  ];

  /// Categorías que aparecen en Explorar (chips y búsqueda pública).
  static const List<String> listaPublica = [
    restaurante,
    postres,
    productos,
    farmacia,
    imprenta,
    servicios,
  ];

  static bool esRestaurante(String? categoria) => categoria == restaurante;

  static bool esPostres(String? categoria) => categoria == postres;

  /// Comida preparada: menú con ingredientes (restaurante o pastelería).
  static bool esComida(String? categoria) =>
      esRestaurante(categoria) || esPostres(categoria);

  static bool esServicios(String? categoria) => categoria == servicios;

  static bool esBodega(String? categoria) => categoria == bodega;

  static bool esFarmacia(String? categoria) => categoria == farmacia;

  static bool esImprenta(String? categoria) => categoria == imprenta;

  /// Tienda con inventario (abarrotes, ferretería, etc.).
  static bool esProductos(String? categoria) => categoria == productos;

  static bool usaIngredientes(String? categoria) => esComida(categoria);

  /// Bodega, tienda o farmacia: stock, ubicaciones, mercancía.
  static bool usaInventario(String? categoria) =>
      esProductos(categoria) || esBodega(categoria) || esFarmacia(categoria);

  /// Nunca visible en Explorar ni comprable por clientes.
  static bool visibleAlPublico(String? categoria) => !esBodega(categoria);

  /// Salidas de inventario sin precios ni cobros.
  static bool sinRegistroDinero(String? categoria) => esBodega(categoria);

  /// Restaurantes, tiendas, farmacias y bodegas registran movimientos en el local.
  static bool puedeVentaEnLocal(String? categoria) => !esServicios(categoria);

  /// Envío a domicilio (servicios usan cita o solicitud, no esta logística).
  static bool puedeEnvios(String? categoria) =>
      visibleAlPublico(categoria) && !esServicios(categoria);

  static bool puedePromos(String? categoria) => visibleAlPublico(categoria);

  /// Servicios no entran a la pantalla de envíos, pero sí eligen cómo cobran.
  static bool puedeCobrosDirectos(String? categoria) => esServicios(categoria);

  static String etiquetaVentaEnLocal(String? categoria) {
    if (esBodega(categoria)) return 'Sacar producto';
    if (esFarmacia(categoria)) return 'Despacho';
    if (esImprenta(categoria)) return 'Nuevo trabajo';
    if (esPostres(categoria)) return 'Nuevo encargo';
    if (esRestaurante(categoria)) return 'Nuevo pedido';
    return 'Nueva venta';
  }

  static String etiquetaVentaEnLocalLargo(String? categoria) {
    if (esBodega(categoria)) return 'Sacar producto de bodega';
    if (esFarmacia(categoria)) return 'Despacho en mostrador';
    if (esImprenta(categoria)) return 'Nuevo trabajo en local';
    if (esPostres(categoria)) return 'Nuevo encargo en local';
    if (esRestaurante(categoria)) return 'Nuevo pedido en local';
    return 'Nueva venta en tienda';
  }

  static String ayudaVentaEnLocal(String? categoria) {
    if (esBodega(categoria)) {
      return 'Registra una salida de inventario, sin precio ni cobro.';
    }
    if (esFarmacia(categoria)) {
      return 'Despacha en mostrador y descuenta el stock de la repisa.';
    }
    if (esImprenta(categoria)) {
      return 'Cobra un trabajo en el local. Los diseños nuevos se cotizan por WhatsApp.';
    }
    if (esPostres(categoria)) {
      return 'Anota un encargo que se prepara o se entrega en el local.';
    }
    if (esRestaurante(categoria)) {
      return 'Toma un pedido de mesa o para llevar, directo en el local.';
    }
    if (esServicios(categoria)) {
      return 'Revisa citas y solicitudes a domicilio de las últimas horas.';
    }
    return 'Cobra una venta en el local y descuenta existencias.';
  }

  static String etiquetaHistorial(String? categoria) =>
      esBodega(categoria) ? 'Historial de salidas' : 'Historial y ventas';

  static String etiquetaCatalogo(String? categoria) {
    if (esServicios(categoria)) return 'Mis servicios';
    if (esBodega(categoria)) return 'Inventario';
    if (esPostres(categoria)) return 'Mis antojos';
    if (esFarmacia(categoria)) return 'Medicamentos';
    if (esImprenta(categoria)) return 'Trabajos';
    if (esRestaurante(categoria)) return 'Menú';
    return 'Catálogo';
  }

  static String etiquetaCatalogoPublico(String? categoria) {
    if (esServicios(categoria)) return 'Servicios';
    if (esPostres(categoria)) return 'Antojos';
    if (esFarmacia(categoria)) return 'Farmacia';
    if (esImprenta(categoria)) return 'Impresos';
    if (esRestaurante(categoria)) return 'Menú';
    return 'Catálogo';
  }

  static String hintBusqueda(String? categoria) {
    if (esServicios(categoria)) return 'Buscar servicio...';
    if (esFarmacia(categoria)) return 'Buscar nombre, presentación, código...';
    if (esImprenta(categoria)) return 'Buscar lona, sticker, talla, gorra...';
    if (esComida(categoria)) return 'Buscar nombre o ingrediente...';
    if (esBodega(categoria)) return 'Buscar nombre o código...';
    return 'Buscar nombre, 600 ml, código...';
  }

  /// Texto corto para quien elige el tipo al crear el negocio.
  static String resumen(String? categoria) {
    if (esRestaurante(categoria)) {
      return 'Menú con ingredientes, pedidos en el local, envíos y promociones.';
    }
    if (esPostres(categoria)) {
      return 'Pastelería, helados y antojos. Encargos, ingredientes y envíos.';
    }
    if (esFarmacia(categoria)) {
      return 'Stock y repisas. Puedes marcar receta y fecha de vencimiento.';
    }
    if (esProductos(categoria)) {
      return 'Tienda con inventario, repisas, ventas en el local y envíos.';
    }
    if (esImprenta(categoria)) {
      return 'Lonas, stickers, uniformes, gorras y bordados. Diseños nuevos por WhatsApp.';
    }
    if (esServicios(categoria)) {
      return 'Citas con horario o solicitudes a domicilio. Sin venta de mostrador.';
    }
    if (esBodega(categoria)) {
      return 'Uso interno. Salidas de inventario, sin precios ni clientes.';
    }
    return '';
  }

  static IconData icono(String? categoria) {
    if (esRestaurante(categoria)) return Icons.restaurant;
    if (esPostres(categoria)) return Icons.cake_outlined;
    if (esFarmacia(categoria)) return Icons.medication_outlined;
    if (esImprenta(categoria)) return Icons.print_outlined;
    if (esServicios(categoria)) return Icons.content_cut;
    if (esBodega(categoria)) return Icons.warehouse_outlined;
    return Icons.storefront_outlined;
  }

  static IconData iconoVentaEnLocal(String? categoria) {
    if (esBodega(categoria)) return Icons.output;
    if (esFarmacia(categoria)) return Icons.medication;
    if (esImprenta(categoria)) return Icons.print;
    if (esPostres(categoria)) return Icons.cake;
    if (esRestaurante(categoria)) return Icons.add_shopping_cart;
    if (esServicios(categoria)) return Icons.event_available;
    return Icons.point_of_sale;
  }

  static MaterialColor color(String? categoria) {
    if (esRestaurante(categoria)) return Colors.orange;
    if (esPostres(categoria)) return Colors.pink;
    if (esFarmacia(categoria)) return Colors.teal;
    if (esImprenta(categoria)) return Colors.deepOrange;
    if (esServicios(categoria)) return Colors.deepPurple;
    if (esBodega(categoria)) return Colors.brown;
    return Colors.green;
  }

  static String normalizar(String? categoria) {
    if (categoria == restaurante) return restaurante;
    if (categoria == postres) return postres;
    if (categoria == servicios) return servicios;
    if (categoria == bodega) return bodega;
    if (categoria == farmacia) return farmacia;
    if (categoria == imprenta) return imprenta;
    return productos;
  }
}
