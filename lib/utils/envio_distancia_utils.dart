import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

class ResultadoEnvioDistancia {
  final double distanciaKm;
  final double distanciaKmCobro;
  final double costo;
  final bool fueraDeRango;

  const ResultadoEnvioDistancia({
    required this.distanciaKm,
    required this.distanciaKmCobro,
    required this.costo,
    this.fueraDeRango = false,
  });
}

class EnvioDistanciaUtils {
  /// Bloques de 50 m para que mover la puerta un poco no cambie el precio.
  static const double _metrosPorBloque = 50;
  static const double _incrementoPesos = 5;

  static double distanciaKm(GeoPoint origen, GeoPoint destino) {
    const radioTierraKm = 6371.0;
    final dLat = _gradosARadianes(destino.latitude - origen.latitude);
    final dLng = _gradosARadianes(destino.longitude - origen.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_gradosARadianes(origen.latitude)) *
            math.cos(_gradosARadianes(destino.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return radioTierraKm * c;
  }

  static double _gradosARadianes(double grados) => grados * math.pi / 180;

  static double kmParaCobro(double km) {
    if (km <= 0) return 0;
    final metros = km * 1000;
    final bloques = (metros / _metrosPorBloque).ceil();
    return (bloques * _metrosPorBloque) / 1000;
  }

  static double redondearCosto(double costo) {
    if (costo <= 0) return 0;
    return (_incrementoPesos * (costo / _incrementoPesos).round()).toDouble();
  }

  static ResultadoEnvioDistancia calcular({
    required GeoPoint origenNegocio,
    required GeoPoint destinoCliente,
    required double costoPorKm,
    double envioMinimo = 0,
    double? distanciaMaximaKm,
  }) {
    final kmReal = distanciaKm(origenNegocio, destinoCliente);
    if (distanciaMaximaKm != null && distanciaMaximaKm > 0 && kmReal > distanciaMaximaKm) {
      return ResultadoEnvioDistancia(
        distanciaKm: kmReal,
        distanciaKmCobro: kmParaCobro(kmReal),
        costo: 0,
        fueraDeRango: true,
      );
    }

    final kmCobro = kmParaCobro(kmReal);
    var costo = kmCobro * costoPorKm;
    if (envioMinimo > 0 && costo < envioMinimo) {
      costo = envioMinimo;
    }
    costo = redondearCosto(costo);

    return ResultadoEnvioDistancia(
      distanciaKm: kmReal,
      distanciaKmCobro: kmCobro,
      costo: costo,
    );
  }
}
