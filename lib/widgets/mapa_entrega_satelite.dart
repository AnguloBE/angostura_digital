import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Mapa satelital: el pin fijo en el centro marca el punto; las coords vienen del target de la cámara.
class MapaEntregaSatelite extends StatefulWidget {
  final LatLng? posicionInicial;
  final LatLng? posicionNegocio;
  final double altura;
  final bool expandir;
  final ValueChanged<LatLng> onCentroCambiado;
  final VoidCallback? onMapaListo;

  const MapaEntregaSatelite({
    super.key,
    this.posicionInicial,
    this.posicionNegocio,
    this.altura = 220,
    this.expandir = false,
    required this.onCentroCambiado,
    this.onMapaListo,
  });

  @override
  State<MapaEntregaSatelite> createState() => MapaEntregaSateliteState();
}

class MapaEntregaSateliteState extends State<MapaEntregaSatelite> {
  GoogleMapController? _controller;
  LatLng? _puntoCentro;
  bool _mostrarMapaNativo = false;

  static const LatLng _fallbackCentro = LatLng(17.5961, -101.1912);
  static const double _tamanoPin = 50;

  static final Set<Factory<OneSequenceGestureRecognizer>> _gestosMapa = {
    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
  };

  @override
  void initState() {
    super.initState();
    _puntoCentro = widget.posicionInicial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _mostrarMapaNativo = true);
    });
  }

  @override
  void didUpdateWidget(MapaEntregaSatelite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.posicionInicial != null &&
        widget.posicionInicial != oldWidget.posicionInicial &&
        _controller != null) {
      _puntoCentro = widget.posicionInicial;
      centrarEn(widget.posicionInicial!);
    }
  }

  Future<void> centrarEn(LatLng posicion) async {
    if (_controller == null) return;
    _puntoCentro = posicion;
    await _controller!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: posicion, zoom: 18),
      ),
    );
  }

  /// Coordenada exacta del centro del mapa (punta del pin).
  Future<LatLng?> leerCentroActual() async => _puntoCentro;

  void _onCameraMove(CameraPosition position) {
    _puntoCentro = position.target;
  }

  void _onCameraIdle() {
    if (_puntoCentro == null) return;
    widget.onCentroCambiado(_puntoCentro!);
  }

  Set<Marker> _marcadoresNegocio() {
    final negocio = widget.posicionNegocio;
    if (negocio == null) return {};
    return {
      Marker(
        markerId: const MarkerId('negocio'),
        position: negocio,
        anchor: const Offset(0.5, 1.0),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Local'),
      ),
    };
  }

  Widget _pinCentro() {
    return IgnorePointer(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: _tamanoPin / 2),
          child: Icon(
            Icons.location_on,
            size: _tamanoPin,
            color: Colors.red.shade700,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
      ),
    );
  }

  Widget _contenidoMapa() {
    final inicial = widget.posicionInicial ?? _fallbackCentro;

    if (!_mostrarMapaNativo) {
      return Container(
        color: Colors.grey.shade300,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Cargando mapa...', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: inicial, zoom: 18),
          mapType: MapType.hybrid,
          padding: EdgeInsets.zero,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          markers: _marcadoresNegocio(),
          gestureRecognizers: _gestosMapa,
          onMapCreated: (c) {
            _controller = c;
            _puntoCentro ??= inicial;
            widget.onMapaListo?.call();
          },
          onCameraMove: _onCameraMove,
          onCameraIdle: _onCameraIdle,
        ),
        _pinCentro(),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xA6000000),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'El pin rojo marca tu puerta — mueve el mapa o centra en tu ubicación',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: widget.expandir
          ? _contenidoMapa()
          : SizedBox(
              height: widget.altura,
              width: double.infinity,
              child: _contenidoMapa(),
            ),
    );
  }
}
