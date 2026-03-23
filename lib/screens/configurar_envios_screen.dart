import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:angostura_digital/globals.dart' as globals;

class ConfigurarEnviosScreen extends StatefulWidget {
  final String negocioId;
  const ConfigurarEnviosScreen({super.key, required this.negocioId});

  @override
  State<ConfigurarEnviosScreen> createState() => _ConfigurarEnviosScreenState();
}

class _ConfigurarEnviosScreenState extends State<ConfigurarEnviosScreen> {
  bool _permiteRecoger = true;
  bool _isLoading = true;
  
  // Ubicación física del negocio
  String? _ubicacionLocal;
  
  // Lista dinámica traída desde Firebase
  List<String> _zonasDisponibles = [];
  
  // Controladores y estados
  final Map<String, TextEditingController> _controladoresZonas = {};
  final Map<String, bool> _zonasActivas = {};

  @override
  void initState() {
    super.initState();
    _cargarZonasYConfiguracion();
  }

  Future<void> _cargarZonasYConfiguracion() async {
    // 1. Traemos la lista maestra de zonas que el Admin creó
    final zonasSnap = await FirebaseFirestore.instance.collection('zonas').orderBy('nombre').get();
    
    _zonasDisponibles = zonasSnap.docs.map((doc) => doc['nombre'] as String).toList();
    
    for (var zona in _zonasDisponibles) {
      _controladoresZonas[zona] = TextEditingController();
      _zonasActivas[zona] = false;
    }

    // 2. Traemos la configuración guardada del negocio
    final doc = await FirebaseFirestore.instance.collection('negocios').doc(widget.negocioId).get();
    
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      
      if (data.containsKey('permite_recoger')) _permiteRecoger = data['permite_recoger'];
      
      // Verificamos si ya guardó su ubicación física y si aún existe en la lista del admin
      if (data.containsKey('ubicacion_local') && _zonasDisponibles.contains(data['ubicacion_local'])) {
        _ubicacionLocal = data['ubicacion_local'];
      }
      
      if (data.containsKey('tarifas_envio')) {
        Map<String, dynamic> tarifas = data['tarifas_envio'];
        tarifas.forEach((zona, precio) {
          // Solo cargamos el precio si el Admin no ha borrado esa zona de la lista
          if (_controladoresZonas.containsKey(zona)) {
            _controladoresZonas[zona]!.text = precio.toString();
            _zonasActivas[zona] = true;
          }
        });
      }
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _guardarConfiguracion() async {
    if (_ubicacionLocal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecciona la ubicación física de tu local.'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);
    Map<String, double> tarifasFinales = {};
    
    _zonasActivas.forEach((zona, activa) {
      if (activa && _controladoresZonas[zona]!.text.isNotEmpty) {
        tarifasFinales[zona] = double.tryParse(_controladoresZonas[zona]!.text) ?? 0.0;
      }
    });

    await FirebaseFirestore.instance.collection('negocios').doc(widget.negocioId).update({
      'ubicacion_local': _ubicacionLocal, // Guardamos dónde está físicamente
      'permite_recoger': _permiteRecoger,
      'tarifas_envio': tarifasFinales,
    });

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuración guardada exitosamente'), backgroundColor: Colors.green));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logística y Envíos'), backgroundColor: globals.colorFondo, foregroundColor: Colors.white),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- NUEVO: UBICACIÓN FÍSICA DEL LOCAL ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [Icon(Icons.storefront, color: Colors.blueAccent), SizedBox(width: 8), Text('Ubicación Física del Local', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent))]),
                    const SizedBox(height: 8),
                    const Text('¿En qué zona está situado este negocio?', style: TextStyle(color: Colors.black87)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                      hint: const Text('Selecciona una zona'),
                      value: _ubicacionLocal,
                      items: _zonasDisponibles.map((zona) => DropdownMenuItem(value: zona, child: Text(zona))).toList(),
                      onChanged: (val) => setState(() => _ubicacionLocal = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              SwitchListTile(
                title: const Text('Permitir "Recoger en el Local"', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('El cliente podrá ir a buscar su comida sin pagar envío.'),
                value: _permiteRecoger,
                activeColor: Colors.blueAccent,
                onChanged: (val) => setState(() => _permiteRecoger = val),
              ),
              const Divider(height: 30, thickness: 2),
              
              const Text('Zonas de Entrega a Domicilio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              const Text('Activa las zonas a las que tu repartidor puede ir y ponles un precio.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 15),
              
              if (_zonasDisponibles.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('El administrador aún no ha registrado zonas de entrega.', style: TextStyle(color: Colors.red), textAlign: TextAlign.center)),
                )
              else
                ..._zonasDisponibles.map((zona) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Checkbox(value: _zonasActivas[zona], activeColor: Colors.blueAccent, onChanged: (val) => setState(() => _zonasActivas[zona] = val!)),
                          Expanded(child: Text(zona, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                          if (_zonasActivas[zona]!)
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _controladoresZonas[zona],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(prefixText: '\$ ', labelText: 'Costo', border: OutlineInputBorder()),
                              ),
                            )
                        ],
                      ),
                    ),
                  );
                }),
              
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.save), label: const Text('Guardar Configuración', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                onPressed: _guardarConfiguracion,
              )
            ],
          ),
    );
  }
}