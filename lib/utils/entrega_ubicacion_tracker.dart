import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Permisos y lectura GPS para entregas.
class EntregaUbicacionTracker {
  LatLng? posicion;
  String direccionTexto = 'Buscando tu ubicación...';
  bool sinPermiso = false;
  bool ubicacionDesactivada = false;

  /// Espera mínima para que el GPS se estabilice (no usar la primera lectura).
  static const Duration tiempoMinimoEspera = Duration(seconds: 5);

  /// Tiempo máximo de búsqueda antes de usar la mejor lectura obtenida.
  static const Duration tiempoMaximoEspera = Duration(seconds: 12);

  /// Si tras el mínimo la precisión es mejor que esto (metros), se acepta y termina.
  static const double precisionObjetivoMetros = 15;

  Future<bool> _asegurarPermisos() async {
    sinPermiso = false;
    ubicacionDesactivada = false;

    final servicioActivo = await Geolocator.isLocationServiceEnabled();
    if (!servicioActivo) {
      ubicacionDesactivada = true;
      direccionTexto = 'Activa la ubicación del teléfono.';
      return false;
    }

    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      sinPermiso = true;
      direccionTexto = 'Permite el acceso a ubicación.';
      return false;
    }
    return true;
  }

  bool _esMejorLectura(Position nueva, Position? actual) {
    if (actual == null) return true;
    final accNueva = nueva.accuracy;
    final accActual = actual.accuracy;
    if (accNueva <= 0) return false;
    if (accActual <= 0) return true;
    return accNueva < accActual;
  }

  /// Varias lecturas GPS durante varios segundos y se usa la más precisa.
  /// Evita mandar la casa del vecino por una primera posición imprecisa.
  Future<LatLng?> obtenerUbicacionPrecisa() async {
    if (!await _asegurarPermisos()) return null;

    direccionTexto = 'Buscando ubicación precisa...';
    Position? mejor;
    StreamSubscription<Position>? sub;

    try {
      final inicio = DateTime.now();
      sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        ),
      ).listen((pos) {
        if (_esMejorLectura(pos, mejor)) mejor = pos;
      });

      while (true) {
        await Future.delayed(const Duration(milliseconds: 250));
        final transcurrido = DateTime.now().difference(inicio);

        if (transcurrido >= tiempoMinimoEspera &&
            mejor != null &&
            mejor!.accuracy > 0 &&
            mejor!.accuracy <= precisionObjetivoMetros) {
          break;
        }
        if (transcurrido >= tiempoMaximoEspera) break;
      }

      await sub.cancel();
      sub = null;

      if (mejor != null) {
        posicion = LatLng(mejor!.latitude, mejor!.longitude);
        return posicion;
      }
    } catch (_) {
      await sub?.cancel();
    }

    // Respaldo: una lectura larga si el stream no devolvió nada.
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 25),
        ),
      );
      posicion = LatLng(pos.latitude, pos.longitude);
      return posicion;
    } catch (_) {
      direccionTexto = 'No pudimos detectar tu ubicación. Intenta al aire libre o cerca de una ventana.';
      return null;
    }
  }

  void dispose() {}
}
