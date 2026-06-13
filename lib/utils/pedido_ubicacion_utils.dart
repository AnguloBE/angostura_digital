import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PedidoUbicacionCoords {
  final double lat;
  final double lng;

  const PedidoUbicacionCoords(this.lat, this.lng);

  GeoPoint toGeoPoint() => GeoPoint(lat, lng);
}

class PedidoUbicacionUtils {
  static final _coordsLegado = RegExp(r'\[Coords:\s*(-?\d+\.\d+),\s*(-?\d+\.\d+)\]');

  static PedidoUbicacionCoords? desdeGeoPoint(GeoPoint? geo) {
    if (geo == null) return null;
    return PedidoUbicacionCoords(geo.latitude, geo.longitude);
  }

  static PedidoUbicacionCoords? desdeNumeros(dynamic lat, dynamic lng) {
    if (lat is! num || lng is! num) return null;
    return PedidoUbicacionCoords(lat.toDouble(), lng.toDouble());
  }

  static PedidoUbicacionCoords? extraerDeDireccionLegado(String direccion) {
    final match = _coordsLegado.firstMatch(direccion);
    if (match == null) return null;
    final lat = double.tryParse(match.group(1)!);
    final lng = double.tryParse(match.group(2)!);
    if (lat == null || lng == null) return null;
    return PedidoUbicacionCoords(lat, lng);
  }

  static PedidoUbicacionCoords? resolverEntrega(Map<String, dynamic> data) {
    final geo = data['ubicacion_geo'];
    if (geo is GeoPoint) return desdeGeoPoint(geo);

    final entrega = data['entrega'];
    if (entrega is Map) {
      final lat = entrega['lat'];
      final lng = entrega['lng'];
      final coords = desdeNumeros(lat, lng);
      if (coords != null) return coords;
    }

    final coords = desdeNumeros(data['entrega_lat'], data['entrega_lng']);
    if (coords != null) return coords;

    return extraerDeDireccionLegado((data['direccion'] ?? '').toString());
  }

  static PedidoUbicacionCoords? resolverNegocio(Map<String, dynamic> data) {
    final geo = data['negocio_ubicacion_geo'];
    if (geo is GeoPoint) return desdeGeoPoint(geo);
    return null;
  }

  static String formatear(PedidoUbicacionCoords coords, {int decimales = 6}) {
    return '${coords.lat.toStringAsFixed(decimales)}, ${coords.lng.toStringAsFixed(decimales)}';
  }

  static Uri urlUbicacion(PedidoUbicacionCoords coords) {
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${coords.lat},${coords.lng}',
    );
  }

  static Future<void> abrirUrl(BuildContext context, Uri url, {String? errorMsg}) async {
    try {
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        _mostrarError(context, errorMsg ?? 'No se pudo abrir Google Maps.');
      }
    } catch (_) {
      if (context.mounted) {
        _mostrarError(context, errorMsg ?? 'No se pudo abrir Google Maps.');
      }
    }
  }

  static Future<void> abrirUbicacion(
    BuildContext context,
    PedidoUbicacionCoords coords,
  ) {
    return abrirUrl(context, urlUbicacion(coords));
  }

  static void _mostrarError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }
}
