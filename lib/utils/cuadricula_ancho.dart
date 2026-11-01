/// Ancho de cada tarjeta de un catálogo, para que en teléfono queden
/// dos columnas legibles y en computadora no se hagan ni microscópicas ni enormes.
double anchoTarjetaCuadricula(double maxW, {double spacing = 12}) {
  if (!maxW.isFinite || maxW <= 0) return 160;

  const objetivo = 210.0;
  var columnas = (maxW / objetivo).round();
  if (columnas < 2) columnas = 2;
  if (maxW < 520) columnas = 2;
  if (columnas > 6) columnas = 6;

  final ancho = (maxW - spacing * (columnas - 1)) / columnas;
  return ancho > 0 ? ancho : 160;
}
