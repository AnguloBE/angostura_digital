import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:angostura_digital/globals.dart' as globals;

class MapaUbicacionScreen extends StatefulWidget {
  const MapaUbicacionScreen({super.key});

  @override
  State<MapaUbicacionScreen> createState() => _MapaUbicacionScreenState();
}

class _MapaUbicacionScreenState extends State<MapaUbicacionScreen> {
  GoogleMapController? _mapController;
  
  // Coordenadas iniciales (Centro de Angostura aprox)
  static const LatLng _centroAngostura = LatLng(25.3636, -108.1611);
  
  LatLng? _posicionSeleccionada;
  String _direccionTraducida = 'Toca el mapa para seleccionar tu ubicación';
  bool _buscandoDireccion = false;
  
  final TextEditingController _referenciasCtrl = TextEditingController();

  // Tu llave de Google Maps (Usada aquí para traducir coordenadas a texto)
  final String _googleApiKey = "AIzaSyB96gNYG1I92oeAA8H-_WvTAJNFMLKVtkA";

  // Función mágica que le pregunta a Google cómo se llama la calle tocada
  Future<void> _traducirCoordenadas(LatLng posicion) async {
    setState(() {
      _posicionSeleccionada = posicion;
      _buscandoDireccion = true;
    });

    try {
      final url = "https://maps.googleapis.com/maps/api/geocode/json?latlng=${posicion.latitude},${posicion.longitude}&key=$_googleApiKey&language=es";
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['results'] != null && json['results'].isNotEmpty) {
          setState(() {
            _direccionTraducida = json['results'][0]['formatted_address'];
          });
        } else {
          setState(() => _direccionTraducida = 'Ubicación seleccionada (sin calle registrada)');
        }
      }
    } catch (e) {
      setState(() => _direccionTraducida = 'Coordenadas: ${posicion.latitude.toStringAsFixed(4)}, ${posicion.longitude.toStringAsFixed(4)}');
    }

    setState(() => _buscandoDireccion = false);
  }

  void _confirmarUbicacion() {
    if (_posicionSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, toca el mapa para poner el pin en tu casa.'), backgroundColor: Colors.orange));
      return;
    }
    if (_referenciasCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Las referencias son obligatorias para que el repartidor no se pierda.'), backgroundColor: Colors.orange));
      return;
    }

    // Armamos el super texto que verá el restaurante
    final direccionFinal = "$_direccionTraducida\n📍 Referencias: ${_referenciasCtrl.text.trim()}\n[Coords: ${_posicionSeleccionada!.latitude}, ${_posicionSeleccionada!.longitude}]";
    
    // Regresamos al carrito con esta dirección
    Navigator.pop(context, direccionFinal);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📍 Ubica tu entrega', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: globals.colorFondo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // MAPA INTERACTIVO (Toma la mitad de la pantalla)
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(target: _centroAngostura, zoom: 15),
              onMapCreated: (controller) => _mapController = controller,
              onTap: _traducirCoordenadas,
              markers: _posicionSeleccionada != null 
                ? { Marker(markerId: const MarkerId('pin_entrega'), position: _posicionSeleccionada!) } 
                : {},
            ),
          ),

          // PANEL INFERIOR DE CONFIRMACIÓN
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ubicación Detectada:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                const SizedBox(height: 5),
                if (_buscandoDireccion) 
                  const LinearProgressIndicator() 
                else 
                  Text(_direccionTraducida, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                
                const Divider(height: 30),
                
                TextField(
                  controller: _referenciasCtrl,
                  decoration: InputDecoration(
                    labelText: 'Referencias de la casa',
                    hintText: 'Ej. Casa verde, frente al parque, rejas negras.',
                    prefixIcon: const Icon(Icons.home),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                
                const SizedBox(height: 20),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent, 
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                    onPressed: _confirmarUbicacion,
                    child: const Text('Confirmar Dirección', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}