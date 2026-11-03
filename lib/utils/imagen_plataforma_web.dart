import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

bool get esNavegadorMovil {
  final ua = web.window.navigator.userAgent.toLowerCase();
  if (ua.contains('android') ||
      ua.contains('iphone') ||
      ua.contains('ipad') ||
      ua.contains('ipod')) {
    return true;
  }
  // iPadOS se presenta como Mac, pero la pantalla es táctil.
  return ua.contains('macintosh') && web.window.navigator.maxTouchPoints > 1;
}

/// Convierte la foto a JPG y la achica. Así el recorte no se cae con
/// fotos grandes de la cámara ni con HEIC de iPhone.
Future<String> prepararImagenParaRecorte(String ruta, {int calidad = 82}) async {
  try {
    final imagen = web.HTMLImageElement();
    final carga = Completer<void>();
    imagen.onLoad.listen((_) {
      if (!carga.isCompleted) carga.complete();
    });
    imagen.onError.listen((_) {
      if (!carga.isCompleted) carga.completeError(StateError('imagen'));
    });
    imagen.src = ruta;
    await carga.future.timeout(const Duration(seconds: 12));

    final anchoOriginal = imagen.naturalWidth;
    final altoOriginal = imagen.naturalHeight;
    if (anchoOriginal <= 0 || altoOriginal <= 0) return ruta;

    const maxLado = 1600;
    final mayor = math.max(anchoOriginal, altoOriginal);
    final escala = mayor > maxLado ? maxLado / mayor : 1.0;
    final ancho = math.max(1, (anchoOriginal * escala).round());
    final alto = math.max(1, (altoOriginal * escala).round());

    final lienzo = web.HTMLCanvasElement()
      ..width = ancho
      ..height = alto;
    lienzo.context2D.drawImage(
      imagen,
      0,
      0,
      ancho.toDouble(),
      alto.toDouble(),
    );

    final listo = Completer<String?>();
    final calidadJpeg = (calidad.clamp(40, 90) / 100).toJS;
    lienzo.toBlob(
      (web.Blob blob) {
        if (!listo.isCompleted) {
          listo.complete(web.URL.createObjectURL(blob));
        }
      }.toJS,
      'image/jpeg',
      calidadJpeg,
    );
    final nueva = await listo.future.timeout(const Duration(seconds: 12));
    return (nueva == null || nueva.isEmpty) ? ruta : nueva;
  } catch (_) {
    return ruta;
  }
}
