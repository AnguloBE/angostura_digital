import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/screens/mapa_ubicacion_screen.dart';

class ConfigurarEnviosScreen extends StatefulWidget {
  final String negocioId;
  const ConfigurarEnviosScreen({super.key, required this.negocioId});

  @override
  State<ConfigurarEnviosScreen> createState() => _ConfigurarEnviosScreenState();
}

class _ConfigurarEnviosScreenState extends State<ConfigurarEnviosScreen> {
  bool _permiteRecoger = true;
  bool _isLoading = true;
  GeoPoint? _ubicacionGeoNegocio;

  // Métodos de pago que acepta el negocio.
  final Set<String> _metodosPago = {'efectivo'};
  static const List<String> _opcionesPago = [
    'efectivo',
    'tarjeta',
    'transferencia',
  ];

  final TextEditingController _costoPorKmCtrl = TextEditingController();
  final TextEditingController _envioMinimoCtrl = TextEditingController();
  final TextEditingController _distanciaMaxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  @override
  void dispose() {
    _costoPorKmCtrl.dispose();
    _envioMinimoCtrl.dispose();
    _distanciaMaxCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarConfiguracion() async {
    final doc = await FirebaseFirestore.instance.collection('negocios').doc(widget.negocioId).get();

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      if (data.containsKey('permite_recoger')) _permiteRecoger = data['permite_recoger'];
      _ubicacionGeoNegocio = data['ubicacion_geo'] as GeoPoint?;
      if (data['costo_por_km'] != null) _costoPorKmCtrl.text = data['costo_por_km'].toString();
      if (data['envio_minimo'] != null) _envioMinimoCtrl.text = data['envio_minimo'].toString();
      if (data['distancia_maxima_km'] != null) {
        _distanciaMaxCtrl.text = data['distancia_maxima_km'].toString();
      }
      final metodos = (data['metodos_pago'] as List?)
          ?.map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
      if (metodos != null && metodos.isNotEmpty) {
        _metodosPago
          ..clear()
          ..addAll(metodos);
      }
    }

    setState(() => _isLoading = false);
  }

  String _etiquetaPago(String m) {
    switch (m) {
      case 'efectivo':
        return 'Efectivo';
      case 'tarjeta':
        return 'Tarjeta (terminal)';
      case 'transferencia':
        return 'Transferencia';
      default:
        return m;
    }
  }

  IconData _iconoPago(String m) {
    switch (m) {
      case 'efectivo':
        return Icons.payments;
      case 'tarjeta':
        return Icons.credit_card;
      case 'transferencia':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  Future<void> _fijarUbicacionGpsNegocio() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapaUbicacionScreen(soloCoordenadas: true)),
    );
    if (resultado == null) return;

    double? lat;
    double? lng;
    if (resultado is LatLng) {
      lat = resultado.latitude;
      lng = resultado.longitude;
    } else if (resultado is GeoPoint) {
      lat = resultado.latitude;
      lng = resultado.longitude;
    }

    if (lat != null && lng != null) {
      final geo = GeoPoint(lat, lng);
      setState(() => _ubicacionGeoNegocio = geo);
      await FirebaseFirestore.instance.collection('negocios').doc(widget.negocioId).update({
        'ubicacion_geo': geo,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ubicación GPS del local guardada.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _guardarConfiguracion() async {
    final costoKm = double.tryParse(_costoPorKmCtrl.text.trim()) ?? 0;
    if (costoKm > 0 && _ubicacionGeoNegocio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Para cobrar por kilómetro debes marcar la ubicación GPS exacta del local.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_metodosPago.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elige al menos un método de pago que aceptas.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final datos = <String, dynamic>{
      'permite_recoger': _permiteRecoger,
      'costo_por_km': costoKm,
      'envio_minimo': double.tryParse(_envioMinimoCtrl.text.trim()) ?? 0,
      'metodos_pago': _opcionesPago.where(_metodosPago.contains).toList(),
      'tarifas_envio': FieldValue.delete(),
      'ubicacion_local': FieldValue.delete(),
      if (_distanciaMaxCtrl.text.trim().isNotEmpty)
        'distancia_maxima_km': double.tryParse(_distanciaMaxCtrl.text.trim()),
    };

    if (_ubicacionGeoNegocio != null) {
      datos['ubicacion_geo'] = _ubicacionGeoNegocio;
    }

    await FirebaseFirestore.instance.collection('negocios').doc(widget.negocioId).update(datos);

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración guardada exitosamente'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usaKm = (double.tryParse(_costoPorKmCtrl.text.trim()) ?? 0) > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logística y Envíos'),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.storefront, color: Colors.blueAccent),
                          SizedBox(width: 8),
                          Text(
                            'Ubicación del local',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Marca en el mapa dónde está tu negocio. El envío se calcula por distancia hasta el cliente.',
                        style: TextStyle(color: Colors.black87, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            _ubicacionGeoNegocio != null ? Icons.check_circle : Icons.warning_amber,
                            color: _ubicacionGeoNegocio != null ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _ubicacionGeoNegocio != null
                                  ? 'GPS del local configurado'
                                  : 'Falta marcar el local en el mapa',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _ubicacionGeoNegocio != null ? Colors.green.shade800 : Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _fijarUbicacionGpsNegocio,
                          icon: const Icon(Icons.add_location_alt),
                          label: Text(_ubicacionGeoNegocio != null ? 'Cambiar ubicación GPS' : 'Marcar local en mapa'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Envío por distancia',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'El cliente confirma en mapa satelital y el costo se calcula según los km al local.',
                        style: TextStyle(color: Colors.black87, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _costoPorKmCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Costo por kilómetro (\$)',
                          hintText: 'Ej. 15',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          prefixText: '\$ ',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _envioMinimoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Mínimo de envío (opcional)',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          prefixText: '\$ ',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _distanciaMaxCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Distancia máxima de entrega (km, opcional)',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      if (usaKm && _ubicacionGeoNegocio == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'Activa el GPS del local para usar el cobro por km.',
                            style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: Colors.purple),
                          SizedBox(width: 8),
                          Text(
                            'Métodos de pago que aceptas',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.purple),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'El cliente solo podrá elegir entre los que marques. En efectivo se le pedirá con cuánto pagará para llevar su cambio.',
                        style: TextStyle(color: Colors.black87, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _opcionesPago.map((m) {
                          final activo = _metodosPago.contains(m);
                          return FilterChip(
                            avatar: Icon(
                              _iconoPago(m),
                              size: 18,
                              color: activo ? Colors.white : Colors.blueGrey,
                            ),
                            label: Text(_etiquetaPago(m)),
                            labelStyle: TextStyle(
                              color: activo ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                            selected: activo,
                            selectedColor: Colors.purple,
                            backgroundColor: Colors.white,
                            checkmarkColor: Colors.white,
                            onSelected: (sel) => setState(() {
                              if (sel) {
                                _metodosPago.add(m);
                              } else {
                                _metodosPago.remove(m);
                              }
                            }),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  title: const Text('Permitir "Recoger en el Local"', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('El cliente podrá ir a buscar su comida sin pagar envío.'),
                  value: _permiteRecoger,
                  activeThumbColor: Colors.blueAccent,
                  onChanged: (val) => setState(() => _permiteRecoger = val),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar configuración', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: _guardarConfiguracion,
                ),
              ],
            ),
    );
  }
}
