/// Sección libre del catálogo (Comida, Refrescos, Abarrotes…).
const String seccionSinClasificar = 'Sin sección';

String seccionProducto(Map<String, dynamic> data) {
  final cruda = (data['seccion'] ?? data['categoria_producto'] ?? '')
      .toString()
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  return cruda;
}

bool hayProductosSinSeccion(Iterable<Map<String, dynamic>> items) =>
    items.any((d) => seccionProducto(d).isEmpty);

/// Nombres distintos, sin contar los que no tienen sección.
List<String> seccionesOrdenadas(Iterable<Map<String, dynamic>> items) {
  final vistos = <String, String>{};
  for (final d in items) {
    final s = seccionProducto(d);
    if (s.isEmpty) continue;
    vistos.putIfAbsent(s.toLowerCase(), () => s);
  }
  final lista = vistos.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return lista;
}

bool coincideSeccion(Map<String, dynamic> data, String filtro) {
  if (filtro.isEmpty) return true;
  final s = seccionProducto(data);
  if (filtro == seccionSinClasificar) return s.isEmpty;
  return s.toLowerCase() == filtro.toLowerCase();
}

class BloqueCatalogo<T> {
  final String? titulo;
  final List<T> fila;

  BloqueCatalogo.titulo(String this.titulo) : fila = <T>[];
  BloqueCatalogo.fila(this.fila) : titulo = null;

  bool get esTitulo => titulo != null;
}

/// Filas de [columnas] y, si [agrupar] es true, un título por sección.
/// Los destacados van primero, en su propio bloque, cuando hay más de una sección.
List<BloqueCatalogo<T>> bloquesCatalogo<T>({
  required List<T> items,
  required String Function(T item) seccionDe,
  required bool Function(T item) esDestacado,
  required int columnas,
  required bool agrupar,
}) {
  if (columnas < 1) columnas = 1;
  if (!agrupar || items.isEmpty) {
    return _filas(items, columnas);
  }

  final destacados = items.where(esDestacado).toList();
  final resto = items.where((e) => !esDestacado(e)).toList();
  final base = destacados.isEmpty ? items : resto;

  final grupos = <String, List<T>>{};
  final titulos = <String, String>{};
  for (final item in base) {
    final s = seccionDe(item);
    final clave = (s.isEmpty ? seccionSinClasificar : s).toLowerCase();
    final titulo = s.isEmpty ? seccionSinClasificar : s;
    titulos.putIfAbsent(clave, () => titulo);
    (grupos[clave] ??= <T>[]).add(item);
  }

  final claves = grupos.keys.toList()
    ..sort((a, b) {
      if (a == seccionSinClasificar.toLowerCase() || titulos[a] == seccionSinClasificar) {
        return 1;
      }
      if (b == seccionSinClasificar.toLowerCase() || titulos[b] == seccionSinClasificar) {
        return -1;
      }
      return (titulos[a] ?? a).toLowerCase().compareTo((titulos[b] ?? b).toLowerCase());
    });

  final out = <BloqueCatalogo<T>>[];
  final varias = claves.length > 1 || destacados.isNotEmpty;
  if (destacados.isNotEmpty && varias) {
    out.add(BloqueCatalogo.titulo('Destacados'));
    out.addAll(_filas(destacados, columnas));
  } else if (destacados.isNotEmpty && claves.isEmpty) {
    return _filas(destacados, columnas);
  }

  final mostrarTitulos = claves.length > 1 ||
      (claves.length == 1 && titulos[claves.first] != seccionSinClasificar);
  for (final clave in claves) {
    if (mostrarTitulos) {
      out.add(BloqueCatalogo.titulo(titulos[clave] ?? clave));
    }
    out.addAll(_filas(grupos[clave]!, columnas));
  }
  return out;
}

List<BloqueCatalogo<T>> _filas<T>(List<T> items, int columnas) {
  final out = <BloqueCatalogo<T>>[];
  for (var i = 0; i < items.length; i += columnas) {
    final fin = i + columnas > items.length ? items.length : i + columnas;
    out.add(BloqueCatalogo.fila(items.sublist(i, fin)));
  }
  return out;
}
