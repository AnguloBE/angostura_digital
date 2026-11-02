import 'package:angostura_digital/services/negocio_ingrediente_service.dart';

/// Texto indexable de un producto/servicio para búsqueda local.
String textoBusquedaProducto(Map<String, dynamic> data) {
  final partes = <String>[
    data['nombre']?.toString() ?? '',
    data['descripcion']?.toString() ?? '',
    data['peso_o_contenido']?.toString() ?? '',
    data['codigo_barras']?.toString() ?? '',
    data['tallas_disponibles']?.toString() ?? '',
    data['colores']?.toString() ?? '',
    data['seccion']?.toString() ?? '',
    data['categoria_producto']?.toString() ?? '',
    NegocioIngredienteService.textoIngredientes(data) ?? '',
  ];

  final listaIng = data['ingredientes_lista'];
  if (listaIng is List) {
    partes.addAll(listaIng.map((e) => e.toString()));
  }

  return partes
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .join(' ');
}

String _sinAcentos(String s) {
  const pares = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n',
  };
  var out = s.toLowerCase();
  pares.forEach((k, v) => out = out.replaceAll(k, v));
  return out;
}

String _normalizar(String s) =>
    _sinAcentos(s).replaceAll(RegExp(r'\s+'), ' ').trim();

/// Quita espacios y signos comunes para emparejar "600ml" con "600 ml".
String _compactar(String s) =>
    _normalizar(s).replaceAll(RegExp(r'[\s.\-_/]'), '');

/// True si [query] coincide con nombre, descripción, contenido (600 ml), ingredientes, etc.
bool coincideBusquedaProducto(Map<String, dynamic> data, String query) {
  final q = _normalizar(query);
  if (q.isEmpty) return true;

  final stack = _normalizar(textoBusquedaProducto(data));
  if (stack.isEmpty) return false;

  final stackCompact = _compactar(textoBusquedaProducto(data));
  final qCompact = _compactar(query);

  if (qCompact.isNotEmpty && stackCompact.contains(qCompact)) return true;
  if (stack.contains(q)) return true;

  final tokens = q.split(' ').where((t) => t.isNotEmpty);
  for (final token in tokens) {
    final tCompact = _compactar(token);
    final ok = stack.contains(token) ||
        (tCompact.isNotEmpty && stackCompact.contains(tCompact));
    if (!ok) return false;
  }
  return true;
}
