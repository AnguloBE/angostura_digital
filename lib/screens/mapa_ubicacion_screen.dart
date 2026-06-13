import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/utils/entrega_ubicacion_tracker.dart';
import 'package:angostura_digital/widgets/mapa_entrega_satelite.dart';

class MapaUbicacionScreen extends StatefulWidget {
  final bool soloCoordenadas;
  final LatLng? posicionInicial;

  const MapaUbicacionScreen({
    super.key,
    this.soloCoordenadas = false,
    this.posicionInicial,
  });

  @override
  State<MapaUbicacionScreen> createState() => _MapaUbicacionScreenState();
}

class _MapaUbicacionScreenState extends State<MapaUbicacionScreen> {
  final EntregaUbicacionTracker _tracker = EntregaUbicacionTracker();
  final GlobalKey<MapaEntregaSateliteState> _mapaKey = GlobalKey<MapaEntregaSateliteState>();

  LatLng? _posicionInicialMapa;
  bool _buscandoGps = true;

  @override
  void initState() {
    super.initState();
    _posicionInicialMapa = widget.posicionInicial;
    _irAMiUbicacion();
  }

  @override
  void dispose() {
    _tracker.dispose();
    super.dispose();
  }

  Future<void> _irAMiUbicacion() async {
    setState(() => _buscandoGps = true);
    final gps = await _tracker.obtenerUbicacionPrecisa();
    if (!mounted) return;

  setState(() {
      _buscandoGps = false;
      if (gps != null) _posicionInicialMapa = gps;
    });

    if (gps != null) {
      await _mapaKey.currentState?.centrarEn(gps);
    }
  }

  Future<void> _confirmarUbicacion() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final centro = await _mapaKey.currentState?.leerCentroActual();
    if (centro == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mueve el mapa hasta marcar el punto correcto.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (widget.soloCoordenadas) {
      if (!mounted) return;
      Navigator.pop(context, centro);
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, {
      'direccion': 'Punto de entrega confirmado en mapa',
      'coordenadas': centro,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.soloCoordenadas ? 'Ubicación del negocio' : 'Confirmar en mapa',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: globals.colorFondo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Stack(
                children: [
                  MapaEntregaSatelite(
                    key: _mapaKey,
                    expandir: true,
                    posicionInicial: _posicionInicialMapa,
                    onCentroCambiado: (_) {},
                    onMapaListo: () {
                      final pos = _posicionInicialMapa;
                      if (pos != null) _mapaKey.currentState?.centrarEn(pos);
                    },
                  ),
                  if (_buscandoGps)
                    Container(
                      color: Colors.black26,
                      alignment: Alignment.center,
                      child: const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 12),
                              Text('Ubicándote...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_tracker.sinPermiso || _tracker.ubicacionDesactivada)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _tracker.direccionTexto,
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _buscandoGps ? null : _irAMiUbicacion,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Ir a mi ubicación actual'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _confirmarUbicacion,
                    child: Text(
                      widget.soloCoordenadas ? 'Guardar ubicación del local' : 'Usar este punto',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
