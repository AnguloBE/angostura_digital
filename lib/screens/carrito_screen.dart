import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:angostura_digital/providers/cart_provider.dart';
import 'package:angostura_digital/screens/main_navigation.dart';
import 'package:angostura_digital/screens/mapa_ubicacion_screen.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CarritoScreen extends StatefulWidget {
  const CarritoScreen({super.key});

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  final TextEditingController _notasCtrl = TextEditingController();
  
  String? _direccionCompleta;
  GeoPoint? _coordenadasEntrega; 

  bool _cargandoDatos = true;
  bool _permiteRecoger = false;
  Map<String, dynamic> _tarifasEnvio = {};
  
  String _metodoSeleccionado = 'domicilio'; 
  String? _zonaSeleccionada;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    
    // 1. CARGAMOS LA UBICACIÓN DIRECTO DE LA BD DEL CLIENTE
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        if (data.containsKey('direccion_entrega')) {
          _direccionCompleta = data['direccion_entrega'];
        }
        if (data.containsKey('coordenadas_entrega')) {
          _coordenadasEntrega = data['coordenadas_entrega'] as GeoPoint?;
        }
      }
    }

    // 2. CARGAMOS LAS ZONAS DEL NEGOCIO
    if (cart.negocioIdActual != null) {
      final negDoc = await FirebaseFirestore.instance.collection('negocios').doc(cart.negocioIdActual).get();
      if (negDoc.exists) {
        final data = negDoc.data()!;
        _permiteRecoger = data['permite_recoger'] ?? false;
        
        if (data.containsKey('tarifas_envio')) {
          _tarifasEnvio = Map<String, dynamic>.from(data['tarifas_envio']);
          // Eliminamos la auto-selección para obligar al usuario a elegir
        }
      }
    }

    _actualizarLogisticaEnProvider();
    setState(() => _cargandoDatos = false);
  }

  void _actualizarLogisticaEnProvider() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    double costo = 0.0;
    
    if (_metodoSeleccionado == 'domicilio' && _zonaSeleccionada != null) {
      costo = (_tarifasEnvio[_zonaSeleccionada] ?? 0).toDouble();
    }
    cart.establecerLogistica(_metodoSeleccionado, costo, zona: _zonaSeleccionada);
  }

  Future<void> _mostrarFormularioDireccion() async {
    final resultado = await Navigator.push(context, MaterialPageRoute(builder: (_) => const MapaUbicacionScreen()));
    
    if (resultado != null && resultado is Map) {
      final String dirStr = resultado['direccion'];
      final LatLng coords = resultado['coordenadas'];
      final GeoPoint geo = GeoPoint(coords.latitude, coords.longitude);

      setState(() {
        _direccionCompleta = dirStr;
        _coordenadasEntrega = geo;
      });

      // Guardamos en el perfil del cliente
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).update({
          'direccion_entrega': dirStr,
          'coordenadas_entrega': geo,
        });
      }
    }
  }

  Future<void> _guardarPedidoEnFirebase(BuildContext context, CartProvider cart, String paymentIntentId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    if (_metodoSeleccionado == 'domicilio' && (_direccionCompleta == null || _coordenadasEntrega == null)) return;

    final negocioId = cart.negocioIdActual;
    if (negocioId == null) return;

    String negocioNombre = 'Negocio';
    try {
      final doc = await FirebaseFirestore.instance.collection('negocios').doc(negocioId).get();
      if (doc.exists) negocioNombre = doc.data()?['nombre'] ?? 'Local';
    } catch (e) {}

    final listaProductos = cart.items.values.map((i) => {'id': i.id, 'nombre': i.nombre, 'precio': i.precio, 'cantidad': i.cantidad}).toList();
    String infoDireccion = _metodoSeleccionado == 'recoger' ? 'El cliente pasará a recoger al local.' : 'ZONA: $_zonaSeleccionada\n$_direccionCompleta';

    await FirebaseFirestore.instance.collection('pedidos').add({
      'cliente_id': user.uid,
      'negocio_id': negocioId,
      'negocio_nombre': negocioNombre,
      'productos': listaProductos,
      'subtotal': cart.subtotal,
      'tarifa_plataforma': cart.tarifaPlataforma,
      'costo_envio': cart.costoEnvio,
      'total': cart.total,
      'estado': 'Pendiente', 
      'notas': _notasCtrl.text.trim(), 
      'metodo_entrega': _metodoSeleccionado,
      'direccion': infoDireccion, 
      'ubicacion_geo': _metodoSeleccionado == 'domicilio' ? _coordenadasEntrega : null,
      'fecha': FieldValue.serverTimestamp(), 
      'payment_intent_id': paymentIntentId, 
    });
  }

  Future<void> _procesarPago(BuildContext context, CartProvider cart) async {
    bool loaderAbierto = true;
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('crearIntentoDePago');
      final response = await callable.call(<String, dynamic>{'total': cart.total.toDouble()});
      final clientSecret = response.data['clientSecret'];
      final paymentIntentId = clientSecret.toString().split('_secret_')[0];
      
      if (kIsWeb) {
        await Stripe.instance.confirmPayment(paymentIntentClientSecret: clientSecret, data: const PaymentMethodParams.card(paymentMethodData: PaymentMethodData()));
      } else {
        await Stripe.instance.initPaymentSheet(paymentSheetParameters: SetupPaymentSheetParameters(paymentIntentClientSecret: clientSecret, merchantDisplayName: 'Angostura Digital'));
        
        if (context.mounted) {
          Navigator.pop(context); 
          loaderAbierto = false;
        }
        
        await Stripe.instance.presentPaymentSheet(); 
      }
      
      if (loaderAbierto && context.mounted) {
        Navigator.pop(context); 
        loaderAbierto = false;
      }

      await _guardarPedidoEnFirebase(context, cart, paymentIntentId);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Pago exitoso!'), backgroundColor: Colors.green));
        cart.limpiarCarrito();
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainNavigation(initialIndex: 2)), (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        if (loaderAbierto) {
          Navigator.pop(context); 
        }
        if (e is StripeException) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago cancelado. Tu carrito sigue guardado.'), backgroundColor: Colors.orange));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
        }
      }
    }
  }

  bool _puedePagar(CartProvider cart) {
    if (cart.items.isEmpty) return false;
    if (_metodoSeleccionado == 'domicilio') {
      if (_zonaSeleccionada == null || _direccionCompleta == null || _coordenadasEntrega == null) return false;
    }
    return true;
  }

  // Texto dinámico para decirle al usuario qué falta
  String _obtenerTextoBoton(CartProvider cart) {
    if (cart.items.isEmpty) return 'Carrito vacío';
    if (_metodoSeleccionado == 'domicilio') {
      if (_zonaSeleccionada == null) return 'Falta seleccionar Zona';
      if (_direccionCompleta == null || _coordenadasEntrega == null) return 'Falta Dirección';
    }
    return 'Pagar Total';
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final bool botonActivo = _puedePagar(cart);

    return Scaffold(
      appBar: AppBar(title: const Text('Tu Pedido', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: globals.colorFondo, iconTheme: const IconThemeData(color: Colors.white)),
      body: _cargandoDatos 
        ? const Center(child: CircularProgressIndicator())
        : cart.items.isEmpty
          ? const Center(child: Text('Tu carrito está vacío 🌮', style: TextStyle(fontSize: 18)))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(10),
                    children: [
                      const Text('¿Cómo quieres tu pedido?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('A Domicilio'),
                              value: 'domicilio',
                              groupValue: _metodoSeleccionado,
                              activeColor: Colors.blueAccent,
                              onChanged: (val) {
                                setState(() => _metodoSeleccionado = val!);
                                _actualizarLogisticaEnProvider();
                              },
                            ),
                          ),
                          if (_permiteRecoger)
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Recoger'),
                                value: 'recoger',
                                groupValue: _metodoSeleccionado,
                                activeColor: Colors.blueAccent,
                                onChanged: (val) {
                                  setState(() => _metodoSeleccionado = val!);
                                  _actualizarLogisticaEnProvider();
                                },
                              ),
                            ),
                        ],
                      ),
                      
                      if (_metodoSeleccionado == 'recoger')
                         Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: const Text('Pasarás al local por tu pedido. ¡No te cobraremos envío!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))
                      else ...[
                        if (_tarifasEnvio.isEmpty)
                           Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: const Text('Este restaurante no tiene entregas a domicilio configuradas.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))
                        else ...[
                          
                          // --- MENSAJE DE ALERTA ROJO SI FALTA ZONA ---
                          if (_zonaSeleccionada == null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  Text('¡Por favor, selecciona tu zona de envío!', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),

                          // --- DROPDOWN MEJORADO CON ESTILO DE ERROR ---
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Selecciona tu Zona', 
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: _zonaSeleccionada == null ? Colors.red.shade400 : Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true, 
                              fillColor: _zonaSeleccionada == null ? Colors.red.shade50 : Colors.white
                            ),
                            value: _zonaSeleccionada,
                            hint: Text('Toca para elegir tu zona', style: TextStyle(color: _zonaSeleccionada == null ? Colors.red.shade800 : Colors.black54)),
                            items: _tarifasEnvio.keys.map((zona) => DropdownMenuItem(value: zona, child: Text('$zona (Costo: \$${_tarifasEnvio[zona]})'))).toList(),
                            onChanged: (val) {
                              setState(() => _zonaSeleccionada = val);
                              _actualizarLogisticaEnProvider();
                            },
                          ),

                          const SizedBox(height: 10),
                          Card(
                            elevation: 0,
                            color: _direccionCompleta == null || _coordenadasEntrega == null ? Colors.red.shade50 : Colors.blue.shade50,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: _direccionCompleta == null || _coordenadasEntrega == null ? Colors.red.shade200 : Colors.blue.shade200)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [Icon(Icons.location_on, color: _direccionCompleta == null || _coordenadasEntrega == null ? Colors.red : Colors.blueAccent), const SizedBox(width: 8), Text('Dirección Exacta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _direccionCompleta == null || _coordenadasEntrega == null ? Colors.red.shade800 : Colors.blue.shade900))]),
                                  const SizedBox(height: 8),
                                  Text(_direccionCompleta ?? 'Falta dirección de entrega.', style: TextStyle(color: Colors.black87, fontWeight: _direccionCompleta == null ? FontWeight.normal : FontWeight.w500)),
                                  const SizedBox(height: 10),
                                  SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: Icon(_direccionCompleta == null ? Icons.add_location_alt : Icons.edit_location), label: Text(_direccionCompleta == null ? 'Agregar Dirección' : 'Cambiar Dirección'), style: OutlinedButton.styleFrom(foregroundColor: _direccionCompleta == null ? Colors.red : Colors.blueAccent), onPressed: _mostrarFormularioDireccion))
                                ],
                              ),
                            ),
                          ),
                        ]
                      ],
                      const Divider(height: 30),

                      ...cart.items.values.map((item) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                ClipRRect(borderRadius: BorderRadius.circular(8), child: item.fotoUrl != null ? Image.network(item.fotoUrl!, width: 70, height: 70, fit: BoxFit.cover) : Container(width: 70, height: 70, color: Colors.grey.shade200, child: const Icon(Icons.fastfood, color: Colors.grey))),
                                const SizedBox(width: 15),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('\$${item.precio.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)), Row(children: [_botonCantidad(Icons.remove, () => cart.decrementarCantidad(item.id)), Padding(padding: const EdgeInsets.symmetric(horizontal: 15), child: Text('${item.cantidad}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), _botonCantidad(Icons.add, () => cart.incrementarCantidad(item.id)), const Spacer(), IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => cart.eliminarProducto(item.id))])])),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                      TextField(controller: _notasCtrl, decoration: InputDecoration(hintText: 'Ej. Sin cebolla...', labelText: 'Instrucciones Especiales', prefixIcon: const Icon(Icons.edit_note, color: Colors.blueAccent), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.grey.shade50), maxLines: 2),
                    ],
                  ),
                ),
                
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))], borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  child: Column(
                    children: [
                      _filaResumen('Subtotal:', '\$${cart.subtotal.toStringAsFixed(2)}', false),
                      if (_metodoSeleccionado == 'domicilio')
                        _filaResumen('Envío a ${_zonaSeleccionada ?? "ZONA PENDIENTE"}:', '\$${cart.costoEnvio.toStringAsFixed(2)}', true),
                      _filaResumen('Tarifa de app:', '\$${cart.tarifaPlataforma.toStringAsFixed(2)}', true),
                      const Divider(height: 20, thickness: 2),
                      _filaResumen('Total a pagar:', '\$${cart.total.toStringAsFixed(2)}', false, esTotal: true),
                      const SizedBox(height: 15),
                      if (kIsWeb) ...[
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: const CardField(onCardChanged: null)),
                        const SizedBox(height: 15),
                      ],
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: botonActivo ? Colors.blueAccent : Colors.grey, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          onPressed: botonActivo ? () => _procesarPago(context, cart) : null,
                          // --- EL BOTÓN AHORA TE DICE EXACTAMENTE QUÉ FALTA ---
                          child: Text(_obtenerTextoBoton(cart), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
    );
  }

  Widget _botonCantidad(IconData icono, VoidCallback accion) => SizedBox(width: 36, height: 36, child: IconButton(onPressed: accion, icon: Icon(icono, size: 20), style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))));
  Widget _filaResumen(String titulo, String valor, bool esGris, {bool esTotal = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(titulo, style: TextStyle(fontSize: esTotal ? 20 : 16, fontWeight: esTotal ? FontWeight.bold : FontWeight.normal, color: esGris ? Colors.grey : Colors.black)), Text(valor, style: TextStyle(fontSize: esTotal ? 20 : 16, fontWeight: esTotal ? FontWeight.bold : FontWeight.normal, color: esTotal ? Colors.green : Colors.black))]));
}