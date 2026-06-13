import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:angostura_digital/providers/cart_provider.dart';
import 'package:angostura_digital/widgets/square_image.dart';
import 'package:angostura_digital/utils/producto_pedido_utils.dart';
import 'package:angostura_digital/services/negocio_ingrediente_service.dart';
import 'package:angostura_digital/utils/entrega_ubicacion_tracker.dart';
import 'package:angostura_digital/utils/envio_distancia_utils.dart';
import 'package:angostura_digital/utils/comision_app_utils.dart';
import 'package:angostura_digital/utils/categorias_negocio.dart';
import 'package:angostura_digital/utils/servicio_cita_utils.dart';
import 'package:angostura_digital/services/notificaciones_pedido_service.dart';
import 'package:angostura_digital/utils/telefono_obligatorio_utils.dart';
import 'package:angostura_digital/utils/telefono_local_utils.dart';
import 'package:angostura_digital/utils/pedido_mostrador_utils.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class CarritoScreen extends StatefulWidget {
  /// Pedido tomado por trabajador/dueño en el local (sin ubicación ni teléfono del cliente).
  final bool modoMostrador;

  const CarritoScreen({super.key, this.modoMostrador = false});

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  final ScrollController _scrollController = ScrollController();
  final EntregaUbicacionTracker _ubicacionTracker = EntregaUbicacionTracker();

  GeoPoint? _coordenadasEntrega;
  GeoPoint? _negocioUbicacionGeo;

  bool _cargandoDatos = true;
  bool _permiteRecoger = false;
  bool _buscandoUbicacion = false;
  List<NegocioIngrediente> _catalogoIngredientes = [];

  double _costoPorKm = 0;
  double _envioMinimo = 0;
  double? _distanciaMaximaKm;
  double? _distanciaKm;
  double? _distanciaKmCobro;
  bool _fueraDeRango = false;
  bool _ubicacionListaConfirmada = false;
  final GlobalKey _productosSectionKey = GlobalKey();

  String _metodoSeleccionado = 'domicilio';

  // Métodos de pago que acepta el negocio y el que eligió el cliente.
  List<String> _metodosPagoNegocio = const ['efectivo'];
  String? _metodoPagoSeleccionado;
  final TextEditingController _pagaConCtrl = TextEditingController();

  ComisionAppConfig _comisionConfig = const ComisionAppConfig();
  double? _ultimoSubtotalComision;

  bool get _envioPorDistancia => _costoPorKm > 0 && _negocioUbicacionGeo != null;
  bool get _domicilioDisponible => _envioPorDistancia;

  String _categoriaNegocio = '';
  bool _telefonoVerificado = false;

  final TextEditingController _clienteNombreCtrl = TextEditingController();
  final TextEditingController _clienteTelefonoCtrl = TextEditingController();
  final TextEditingController _notasMostradorCtrl = TextEditingController();
  String? _errorTelefonoMostrador;

  bool get _esMostrador => widget.modoMostrador;

  @override
  void initState() {
    super.initState();
    if (_esMostrador) {
      _metodoSeleccionado = 'mostrador';
      _ubicacionListaConfirmada = true;
    }
    _cargarDatosIniciales();
    if (!_esMostrador) _actualizarEstadoTelefono();
  }

  Future<void> _actualizarEstadoTelefono() async {
    final ok = await TelefonoObligatorioUtils.tieneTelefonoVerificado();
    if (mounted) setState(() => _telefonoVerificado = ok);
  }

  @override
  void dispose() {
    _ubicacionTracker.dispose();
    _scrollController.dispose();
    _pagaConCtrl.dispose();
    _clienteNombreCtrl.dispose();
    _clienteTelefonoCtrl.dispose();
    _notasMostradorCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    final cart = Provider.of<CartProvider>(context, listen: false);

    if (cart.negocioIdActual != null) {
      final negDoc =
          await FirebaseFirestore.instance.collection('negocios').doc(cart.negocioIdActual).get();
      if (negDoc.exists) {
        final data = negDoc.data()!;
        _permiteRecoger = data['permite_recoger'] ?? false;
        _negocioUbicacionGeo = data['ubicacion_geo'] as GeoPoint?;
        _costoPorKm = (data['costo_por_km'] ?? 0).toDouble();
        _envioMinimo = (data['envio_minimo'] ?? 0).toDouble();
        _distanciaMaximaKm = data['distancia_maxima_km'] != null
            ? (data['distancia_maxima_km'] as num).toDouble()
            : null;
        _comisionConfig = ComisionAppConfig.desdeMap(data);

        final metodos = (data['metodos_pago'] as List?)
                ?.map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const <String>[];
        _metodosPagoNegocio = metodos.isEmpty ? const ['efectivo'] : metodos;
        if (_metodosPagoNegocio.length == 1) {
          _metodoPagoSeleccionado = _metodosPagoNegocio.first;
        }
        _categoriaNegocio = CategoriasNegocio.normalizar(data['categoria']);

        if (_esMostrador) {
          _metodoSeleccionado = 'mostrador';
          _ubicacionListaConfirmada = true;
          cart.establecerLogistica('mostrador', 0);
        } else if (cart.tieneServicioSolicitud) {
          _metodoSeleccionado = 'servicio_solicitud';
        } else if (cart.esCarritoServicios && cart.tieneServicioCita) {
          _metodoSeleccionado = 'cita';
          _ubicacionListaConfirmada = true;
        }
      }

      try {
        _catalogoIngredientes =
            await NegocioIngredienteService.obtener(cart.negocioIdActual!);
      } catch (_) {}
    }

    _recalcularEnvio();
    setState(() => _cargandoDatos = false);
  }

  void _recalcularEnvio() {
    final cart = Provider.of<CartProvider>(context, listen: false);

    if (_metodoSeleccionado == 'cita' ||
        _metodoSeleccionado == 'servicio_solicitud') {
      cart.establecerLogistica(_metodoSeleccionado, 0);
      _aplicarComisionAlCarrito(cart);
      return;
    }

    if (_metodoSeleccionado != 'domicilio') {
      cart.establecerLogistica(_metodoSeleccionado, 0);
      _aplicarComisionAlCarrito(cart);
      return;
    }

    if (_envioPorDistancia &&
        _negocioUbicacionGeo != null &&
        _coordenadasEntrega != null) {
      final resultado = EnvioDistanciaUtils.calcular(
        origenNegocio: _negocioUbicacionGeo!,
        destinoCliente: _coordenadasEntrega!,
        costoPorKm: _costoPorKm,
        envioMinimo: _envioMinimo,
        distanciaMaximaKm: _distanciaMaximaKm,
      );
      final distanciaCambio = _distanciaKm == null ||
          (_distanciaKm! - resultado.distanciaKm).abs() > 0.01;
      final rangoCambio = _fueraDeRango != resultado.fueraDeRango;

      _distanciaKm = resultado.distanciaKm;
      _distanciaKmCobro = resultado.distanciaKmCobro;
      _fueraDeRango = resultado.fueraDeRango;
      cart.establecerLogistica(
        'domicilio',
        resultado.fueraDeRango ? 0 : resultado.costo,
        distanciaKm: resultado.distanciaKm,
      );
      _aplicarComisionAlCarrito(cart);
      if (distanciaCambio || rangoCambio) setState(() {});
      return;
    }

    _distanciaKm = null;
    _distanciaKmCobro = null;
    _fueraDeRango = false;
    cart.establecerLogistica(_metodoSeleccionado, 0);
    _aplicarComisionAlCarrito(cart);
  }

  void _aplicarComisionAlCarrito(CartProvider cart) {
    final monto = ComisionAppUtils.calcularMonto(cart.subtotal, _comisionConfig);
    cart.establecerComisionApp(monto, _comisionConfig.pagadaPor);
  }

  Future<void> _cambiarMetodoEntrega(String metodo) async {
    setState(() {
      _metodoSeleccionado = metodo;
      if (metodo == 'recoger') {
        _ubicacionListaConfirmada = false;
      } else {
        _ubicacionListaConfirmada = false;
      }
    });
    _recalcularEnvio();
  }

  /// Flujo tipo WhatsApp: pide GPS, activa si hace falta, y manda la ubicación
  /// actual directamente (sin mapa ni pin).
  Future<void> _enviarUbicacionActual() async {
    setState(() => _buscandoUbicacion = true);
    final gps = await _ubicacionTracker.obtenerUbicacionPrecisa();
    if (!mounted) return;
    setState(() => _buscandoUbicacion = false);

    if (gps == null) {
      await _ofrecerActivarUbicacion();
      return;
    }

    _coordenadasEntrega = GeoPoint(gps.latitude, gps.longitude);
    _recalcularEnvio();
    if (!mounted) return;

    if (_fueraDeRango) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Estás a ${_distanciaKm?.toStringAsFixed(1) ?? '?'} km — fuera del rango de entrega de este negocio.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _ubicacionListaConfirmada = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ubicación recibida ✓ Revisa tu pedido abajo.'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _productosSectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
          alignment: 0.05,
        );
      }
    });
  }

  Future<void> _ofrecerActivarUbicacion() async {
    final desactivada = _ubicacionTracker.ubicacionDesactivada;
    if (!mounted) return;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(desactivada ? 'Activa tu ubicación' : 'Permite la ubicación'),
        content: Text(
          desactivada
              ? 'Tu teléfono tiene la ubicación (GPS) apagada. Actívala y vuelve a tocar "Enviar mi ubicación".'
              : 'Necesitamos tu permiso de ubicación para llevarte el pedido. Actívalo en los ajustes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
    if (res == true) {
      if (desactivada) {
        await Geolocator.openLocationSettings();
      } else {
        await Geolocator.openAppSettings();
      }
    }
  }

  void _editarUbicacionEntrega() {
    setState(() => _ubicacionListaConfirmada = false);
  }

  String _direccionParaPedido() {
    var base = 'Entrega confirmada en mapa satelital';
    if (_envioPorDistancia && _distanciaKmCobro != null) {
      base = 'Distancia de cobro: ${_distanciaKmCobro!.toStringAsFixed(2)} km\n$base';
    }
    return base;
  }

  Future<String?> _guardarPedidoEnFirebase(BuildContext context, CartProvider cart) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    if (!await TelefonoObligatorioUtils.tieneTelefonoVerificado()) return null;

    if (_metodoSeleccionado == 'domicilio' && _coordenadasEntrega == null) return null;

    final negocioId = cart.negocioIdActual;
    if (negocioId == null) return null;

    String negocioNombre = 'Negocio';
    Map<String, dynamic>? negocioData;
    try {
      final doc = await FirebaseFirestore.instance.collection('negocios').doc(negocioId).get();
      if (doc.exists) {
        negocioData = doc.data();
        negocioNombre = negocioData?['nombre'] ?? 'Local';
      }
    } catch (_) {}

    final config = ComisionAppConfig.desdeMap(negocioData);
    final comisionMonto = ComisionAppUtils.calcularMonto(cart.subtotal, config);

    final listaProductos = cart.items.values.map((i) => i.toPedidoMap()).toList();
    final tieneCita = cart.tieneServicioCita;
    final direccionEntrega = _direccionParaPedido();
    final infoDireccion = _metodoSeleccionado == 'recoger'
        ? 'El cliente pasará a recoger al local.'
        : _metodoSeleccionado == 'cita'
            ? 'Cita en el local del negocio.'
            : _metodoSeleccionado == 'servicio_solicitud'
                ? 'Solicitud de servicio a domicilio. El negocio contactará al cliente.'
                : direccionEntrega;

    final pedidoRef = await FirebaseFirestore.instance.collection('pedidos').add({
      'cliente_id': user.uid,
      'negocio_id': negocioId,
      'negocio_nombre': negocioNombre,
      'productos': listaProductos,
      'subtotal': cart.subtotal,
      'costo_envio': cart.costoEnvio,
      'comision_app': comisionMonto,
      'comision_pagada_por': config.pagadaPor,
      'total': cart.total,
      'estado': 'Pendiente',
      'notas': '',
      'metodo_pago': _metodoPagoSeleccionado ?? 'efectivo',
      if (_metodoPagoSeleccionado == 'efectivo' &&
          (double.tryParse(_pagaConCtrl.text.trim()) ?? 0) > 0) ...{
        'paga_con': double.tryParse(_pagaConCtrl.text.trim()),
        'cambio': ((double.tryParse(_pagaConCtrl.text.trim()) ?? 0) - cart.total),
      },
      'metodo_entrega': _metodoSeleccionado,
      if (cart.esCarritoServicios) 'tipo_negocio': 'servicios',
      if (tieneCita) 'tiene_cita': true,
      'direccion': infoDireccion,
      'ubicacion_geo': (_metodoSeleccionado == 'domicilio' ||
              _metodoSeleccionado == 'servicio_solicitud')
          ? _coordenadasEntrega
          : null,
      if ((_metodoSeleccionado == 'domicilio' ||
              _metodoSeleccionado == 'servicio_solicitud') &&
          _coordenadasEntrega != null) ...{
        'entrega_lat': _coordenadasEntrega!.latitude,
        'entrega_lng': _coordenadasEntrega!.longitude,
        'entrega_confirmada_mapa': true,
        'entrega': {
          'lat': _coordenadasEntrega!.latitude,
          'lng': _coordenadasEntrega!.longitude,
          'confirmada_en_mapa': true,
          if (_distanciaKm != null) 'distancia_km': _distanciaKm,
          if (_distanciaKmCobro != null) 'distancia_cobro_km': _distanciaKmCobro,
        },
      },
      if (_distanciaKm != null) 'distancia_envio_km': _distanciaKm,
      if (_distanciaKmCobro != null) 'distancia_cobro_km': _distanciaKmCobro,
      if (_negocioUbicacionGeo != null) 'negocio_ubicacion_geo': _negocioUbicacionGeo,
      if (_envioPorDistancia) 'modo_envio': 'distancia',
      if (_metodoSeleccionado == 'domicilio' && _envioPorDistancia)
        'envio_config': {
          'costo_por_km': _costoPorKm,
          'envio_minimo': _envioMinimo,
          if (_distanciaMaximaKm != null) 'distancia_maxima_km': _distanciaMaximaKm,
        },
      'fecha': FieldValue.serverTimestamp(),
    });

    return pedidoRef.id;
  }

  Future<String?> _guardarPedidoMostrador(BuildContext context, CartProvider cart) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final negocioId = cart.negocioIdActual;
    if (negocioId == null) return null;

    String negocioNombre = 'Negocio';
    Map<String, dynamic>? negocioData;
    String creadoPorNombre = 'Personal';
    try {
      final doc = await FirebaseFirestore.instance.collection('negocios').doc(negocioId).get();
      if (doc.exists) {
        negocioData = doc.data();
        negocioNombre = negocioData?['nombre'] ?? 'Local';
      }
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (userDoc.exists) {
        creadoPorNombre = (userDoc.data()?['nombre'] ?? creadoPorNombre).toString();
      }
    } catch (_) {}

    final config = ComisionAppConfig.desdeMap(negocioData);
    final comisionMonto = ComisionAppUtils.calcularMonto(cart.subtotal, config);
    final listaProductos = cart.items.values.map((i) => i.toPedidoMap()).toList();

    final clienteNombre = _clienteNombreCtrl.text.trim();
    final clienteTelefono = TelefonoLocalUtils.normalizar(_clienteTelefonoCtrl.text);
    final notas = _notasMostradorCtrl.text.trim();
    if (!TelefonoLocalUtils.esValidoOpcional(_clienteTelefonoCtrl.text)) return null;

    final pedidoRef = await FirebaseFirestore.instance.collection('pedidos').add({
      'es_pedido_mostrador': true,
      'negocio_id': negocioId,
      'negocio_nombre': negocioNombre,
      'creado_por_uid': user.uid,
      'creado_por_nombre': creadoPorNombre,
      if (clienteNombre.isNotEmpty) 'cliente_nombre': clienteNombre,
      if (clienteTelefono.isNotEmpty) 'cliente_telefono': clienteTelefono,
      'productos': listaProductos,
      'subtotal': cart.subtotal,
      'costo_envio': 0,
      'comision_app': comisionMonto,
      'comision_pagada_por': config.pagadaPor,
      'total': cart.total,
      'estado': 'Pendiente',
      'notas': notas,
      'metodo_pago': _metodoPagoSeleccionado ?? 'efectivo',
      if (_metodoPagoSeleccionado == 'efectivo' &&
          (double.tryParse(_pagaConCtrl.text.trim()) ?? 0) > 0) ...{
        'paga_con': double.tryParse(_pagaConCtrl.text.trim()),
        'cambio': ((double.tryParse(_pagaConCtrl.text.trim()) ?? 0) - cart.total),
      },
      'metodo_entrega': 'mostrador',
      'direccion': PedidoMostradorUtils.textoDireccionMostrador(clienteNombre),
      'fecha': FieldValue.serverTimestamp(),
    });

    return pedidoRef.id;
  }

  Future<void> _guardarDireccionClienteTrasPedido() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if ((_metodoSeleccionado == 'domicilio' ||
            _metodoSeleccionado == 'servicio_solicitud') &&
        _coordenadasEntrega != null) {
      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
        'direccion_entrega': 'Confirmada en mapa',
        'coordenadas_entrega': _coordenadasEntrega,
        'entrega_lat': _coordenadasEntrega!.latitude,
        'entrega_lng': _coordenadasEntrega!.longitude,
      }, SetOptions(merge: true));
    }
  }

  void _validarTelefonoMostrador() {
    setState(() {
      _errorTelefonoMostrador =
          TelefonoLocalUtils.mensajeErrorOpcional(_clienteTelefonoCtrl.text);
    });
  }

  Future<void> _intentarConfirmarPedido(BuildContext context, CartProvider cart) async {
    if (_esMostrador) {
      _validarTelefonoMostrador();
      if (_errorTelefonoMostrador != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorTelefonoMostrador!),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }
    if (!_esMostrador && !_telefonoVerificado) {
      final ok = await TelefonoObligatorioUtils.solicitarVerificacion(context);
      if (!mounted) return;
      await _actualizarEstadoTelefono();
      if (!ok) return;
    }
    await _procesarPedido(context, cart);
  }

  Future<void> _procesarPedido(BuildContext context, CartProvider cart) async {
    bool loaderAbierto = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (loaderAbierto && context.mounted) {
        Navigator.pop(context);
        loaderAbierto = false;
      }

      final pedidoId = _esMostrador
          ? await _guardarPedidoMostrador(context, cart)
          : await _guardarPedidoEnFirebase(context, cart);
      if (!_esMostrador) {
        await _guardarDireccionClienteTrasPedido();
        if (pedidoId != null) {
          await NotificacionesPedidoService.solicitarAvisoDueno(pedidoId);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_esMostrador ? 'Pedido registrado en el local.' : '¡Pedido enviado!'),
            backgroundColor: Colors.green,
          ),
        );
        cart.limpiarCarrito();
        if (_esMostrador) {
          Navigator.of(context).pop();
          if (context.mounted) Navigator.of(context).pop();
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (e) {
      if (context.mounted) {
        if (loaderAbierto) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar pedido: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  bool _tieneUbicacionConfirmada() =>
      _ubicacionListaConfirmada && _coordenadasEntrega != null;

  bool _pagoValido(CartProvider cart) {
    if (_metodoPagoSeleccionado == null) return false;
    if (_metodoPagoSeleccionado == 'efectivo') {
      final pagaCon = double.tryParse(_pagaConCtrl.text.trim());
      if (pagaCon != null && pagaCon > 0 && pagaCon < cart.total) return false;
    }
    return true;
  }

  bool _puedePedir(CartProvider cart) {
    if (cart.items.isEmpty) return false;
    if (_esMostrador) {
      return _pagoValido(cart) &&
          TelefonoLocalUtils.esValidoOpcional(_clienteTelefonoCtrl.text);
    }
    if (cart.tieneServicioSolicitud) {
      if (_coordenadasEntrega == null || !_ubicacionListaConfirmada) return false;
    } else if (_metodoSeleccionado == 'domicilio') {
      if (!_tieneUbicacionConfirmada()) return false;
      if (_fueraDeRango) return false;
      if (!_envioPorDistancia) return false;
    }
    return _pagoValido(cart);
  }

  String _obtenerTextoBoton(CartProvider cart) {
    if (cart.items.isEmpty) return 'Carrito vacío';
    if (_esMostrador) {
      if (!TelefonoLocalUtils.esValidoOpcional(_clienteTelefonoCtrl.text)) {
        return 'Teléfono: 10 dígitos';
      }
      if (_metodoPagoSeleccionado == null) return 'Elige cómo va a pagar';
      if (!_pagoValido(cart)) return 'Monto en efectivo insuficiente';
      return 'Registrar pedido';
    }
    if (cart.tieneServicioSolicitud) {
      if (!_ubicacionListaConfirmada) return 'Envía tu ubicación arriba';
    } else if (_metodoSeleccionado == 'domicilio') {
      if (_envioPorDistancia && _negocioUbicacionGeo == null) {
        return 'Local sin GPS configurado';
      }
      if (_fueraDeRango) return 'Fuera del rango de entrega';
      if (!_tieneUbicacionConfirmada()) return 'Marca tu ubicación arriba';
      if (!_envioPorDistancia) return 'Sin envío a domicilio';
    }
    if (_metodoPagoSeleccionado == null) return 'Elige cómo vas a pagar';
    if (!_pagoValido(cart)) return 'Monto en efectivo insuficiente';
    if (!_telefonoVerificado) return 'Confirma tu teléfono';
    return 'Confirmar pedido';
  }

  Widget _indicadorPasosCarrito() {
    final pasoUbicacion = _ubicacionListaConfirmada;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _pasoChip(1, 'Ubicación', activo: !pasoUbicacion, completado: pasoUbicacion),
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: pasoUbicacion ? Colors.green : Colors.grey.shade300,
            ),
          ),
          _pasoChip(2, 'Tu pedido', activo: pasoUbicacion, completado: false),
        ],
      ),
    );
  }

  Widget _pasoChip(int numero, String label, {required bool activo, required bool completado}) {
    final color = completado
        ? Colors.green
        : activo
            ? Colors.blueAccent
            : Colors.grey.shade400;
    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color,
          child: completado
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text(
                  '$numero',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: activo || completado ? FontWeight.bold : FontWeight.normal,
            color: activo || completado ? Colors.black87 : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildResumenUbicacionConfirmada(double costoEnvio) {
    return Card(
      elevation: 0,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Punto de entrega confirmado',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                TextButton(
                  onPressed: _editarUbicacionEntrega,
                  child: const Text('Cambiar'),
                ),
              ],
            ),
            if (_distanciaKmCobro != null) ...[
              const SizedBox(height: 4),
              Text(
                'Distancia: ${_distanciaKmCobro!.toStringAsFixed(2)} km · Envío: \$${costoEnvio.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 14, color: Colors.green.shade900, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPasoUbicacionMapa(double costoEnvio, {bool esServicioDomicilio = false}) {
    final hayProblema =
        _ubicacionTracker.sinPermiso || _ubicacionTracker.ubicacionDesactivada;
    return Card(
      elevation: 0,
      color: _fueraDeRango ? Colors.red.shade50 : Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _fueraDeRango ? Colors.red.shade200 : Colors.blue.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.blue.shade800, size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    esServicioDomicilio
                        ? 'Paso 1: ¿Dónde necesitas el servicio?'
                        : 'Paso 1: ¿Dónde entregamos?',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              esServicioDomicilio
                  ? 'Envía tu ubicación actual. El negocio te llamará o escribirá para acordar día y hora.'
                  : 'Estando en tu casa (en el patio o cerca de la puerta), toca el botón. '
                      'Tardará unos segundos en afinar el GPS para no marcar otra casa.',
              style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.35),
            ),
            if (_envioPorDistancia &&
                _distanciaKmCobro != null &&
                _coordenadasEntrega != null) ...[
              const SizedBox(height: 10),
              Text(
                _fueraDeRango
                    ? 'Estás a ${_distanciaKm!.toStringAsFixed(1)} km — fuera del rango de entrega.'
                    : 'Tu envío (${_distanciaKmCobro!.toStringAsFixed(2)} km): \$${costoEnvio.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _fueraDeRango ? Colors.red.shade800 : Colors.green.shade800,
                ),
              ),
            ],
            if (hayProblema) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _ubicacionTracker.direccionTexto,
                        style: const TextStyle(
                            color: Colors.redAccent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _buscandoUbicacion ? null : _enviarUbicacionActual,
                icon: _buscandoUbicacion
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.my_location, size: 22),
                label: Text(
                  _buscandoUbicacion
                      ? 'Afinando GPS (5–12 s)...'
                      : 'Enviar mi ubicación actual',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Después verás tu pedido para revisarlo',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _encabezadoProductos(CartProvider cart) {
    final n = cart.items.length;
    return KeyedSubtree(
      key: _productosSectionKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.shopping_basket, color: Colors.orange.shade800, size: 22),
              const SizedBox(width: 8),
              Text(
                'Paso 2: Tu pedido ($n ${n == 1 ? 'producto' : 'productos'})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Revisa cantidades y notas antes de confirmar.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _sincronizarComision(CartProvider cart) {
    if (_ultimoSubtotalComision == cart.subtotal) return;
    _ultimoSubtotalComision = cart.subtotal;
    _aplicarComisionAlCarrito(cart);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    _sincronizarComision(cart);
    final bool botonActivo = _puedePedir(cart);
    final bool esServicios = cart.esCarritoServicios;
    final bool necesitaUbicacion = cart.tieneServicioSolicitud;
    final bool mostrarProductos = _esMostrador
        ? true
        : (necesitaUbicacion
            ? _ubicacionListaConfirmada
            : (_metodoSeleccionado == 'recoger' ||
                _metodoSeleccionado == 'cita' ||
                (_metodoSeleccionado == 'domicilio' && _ubicacionListaConfirmada)));
    final bool pasoMapaDomicilio = !_esMostrador &&
        (necesitaUbicacion
            ? !_ubicacionListaConfirmada
            : (_metodoSeleccionado == 'domicilio' &&
                _domicilioDisponible &&
                !_ubicacionListaConfirmada));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _esMostrador ? 'Pedido en local' : 'Tu Pedido',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: globals.colorFondo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _cargandoDatos
          ? const Center(child: CircularProgressIndicator())
          : cart.items.isEmpty
              ? const Center(child: Text('Tu carrito está vacío 🌮', style: TextStyle(fontSize: 18)))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        key: const PageStorageKey<String>('carrito_list'),
                        controller: _scrollController,
                        padding: const EdgeInsets.all(10),
                        children: [
                          if (_esMostrador) _buildMostradorClienteSection(),
                          if (!_esMostrador && !_telefonoVerificado)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.phone_android, color: Colors.orange.shade800),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Verifica tu número de teléfono para poder confirmar el pedido.',
                                      style: TextStyle(
                                        color: Colors.orange.shade900,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (esServicios && cart.tieneServicioCita && !necesitaUbicacion)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.deepPurple.shade100),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.event, color: Colors.deepPurple),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Tus citas son en el local. Revisa fecha y hora abajo.',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!_esMostrador && !esServicios) ...[
                            const Text(
                              '¿Cómo quieres tu pedido?',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            if (_metodoSeleccionado == 'domicilio' && _domicilioDisponible)
                              _indicadorPasosCarrito(),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _MetodoChip(
                                    titulo: 'A domicilio',
                                    icono: Icons.delivery_dining,
                                    seleccionado: _metodoSeleccionado == 'domicilio',
                                    onTap: () => _cambiarMetodoEntrega('domicilio'),
                                  ),
                                ),
                                if (_permiteRecoger) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _MetodoChip(
                                      titulo: 'Recoger',
                                      icono: Icons.storefront,
                                      seleccionado: _metodoSeleccionado == 'recoger',
                                      onTap: () => _cambiarMetodoEntrega('recoger'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                          if (!_esMostrador && necesitaUbicacion) ...[
                            const Text(
                              '¿Dónde necesitas el servicio?',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'El negocio te contactará para coordinar fecha y hora.',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (!_esMostrador && _metodoSeleccionado == 'recoger' && !esServicios)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Pasarás al local por tu pedido. Sin costo de envío.',
                                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                              ),
                            )
                          else if (!_esMostrador && (!esServicios || necesitaUbicacion)) ...[
                            if (!necesitaUbicacion && !_domicilioDisponible)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Este restaurante no tiene entregas a domicilio configuradas.',
                                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              )
                            else ...[
                              if (_envioPorDistancia && _negocioUbicacionGeo == null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'El negocio debe marcar su ubicación GPS en Logística y Envíos.',
                                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              if (_ubicacionListaConfirmada)
                                _buildResumenUbicacionConfirmada(cart.costoEnvio)
                              else
                                _buildPasoUbicacionMapa(cart.costoEnvio, esServicioDomicilio: necesitaUbicacion),
                            ],
                          ],
                          if (pasoMapaDomicilio)
                            Padding(
                              padding: const EdgeInsets.only(top: 16, bottom: 8),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.amber.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.lock_outline, color: Colors.amber.shade900, size: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        necesitaUbicacion
                                            ? 'Tienes ${cart.items.length} servicio(s). Envía tu ubicación para continuar.'
                                            : 'Tienes ${cart.items.length} producto(s) en el carrito. Marca «Entrega aquí» para verlos y confirmar.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.amber.shade900,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (mostrarProductos) ...[
                            const Divider(height: 24),
                            _encabezadoProductos(cart),
                            ...cart.items.values.map((item) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  children: [
                                    SquareImage(
                                      imageUrl: item.fotoUrl,
                                      size: 70,
                                      borderRadius: BorderRadius.circular(8),
                                      placeholder: Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.fastfood, color: Colors.grey),
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.nombre,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (ProductoPedidoUtils.subtituloLinea({
                                                'detalles': item.detalles,
                                                'es_promocion': item.esPromocion,
                                              }) !=
                                              null)
                                            Text(
                                              ProductoPedidoUtils.subtituloLinea({
                                                'detalles': item.detalles,
                                                'es_promocion': item.esPromocion,
                                              })!,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.blueGrey.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          Text(
                                            '\$${item.precio.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (item.esServicio &&
                                              item.tipoServicio == 'cita' &&
                                              item.citaInicio != null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.event,
                                                    size: 16, color: Colors.deepPurple),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    ServicioCitaUtils.formatearCita(
                                                        item.citaInicio!),
                                                    style: const TextStyle(
                                                      color: Colors.deepPurple,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (item.esServicio &&
                                              item.tipoServicio == 'solicitud') ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Solicitud a domicilio',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.orange.shade800,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                          if (_seccionIngredientesItem(cart, item) != null) ...[
                                            const SizedBox(height: 6),
                                            _seccionIngredientesItem(cart, item)!,
                                          ],
                                          if (_puedePersonalizar(item)) ...[
                                            const SizedBox(height: 6),
                                            _botonEditarIngredientes(cart, item),
                                          ],
                                          Row(
                                            children: [
                                              _botonCantidad(Icons.remove, () => cart.decrementarCantidad(item.lineaId)),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 15),
                                                child: Text(
                                                  '${item.cantidad}',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              _botonCantidad(Icons.add, () => _incrementarConStock(cart, item)),
                                              const Spacer(),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                                onPressed: () => cart.eliminarProducto(item.lineaId),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                            const SizedBox(height: 14),
                            _seccionMetodoPago(),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        children: [
                          _filaResumen('Subtotal:', '\$${cart.subtotal.toStringAsFixed(2)}', false),
                          if (!_esMostrador && _metodoSeleccionado == 'domicilio')
                            _filaResumen(
                              _distanciaKmCobro != null
                                  ? 'Envío (${_distanciaKmCobro!.toStringAsFixed(2)} km):'
                                  : 'Envío:',
                              '\$${cart.costoEnvio.toStringAsFixed(0)}',
                              true,
                            ),
                          if (cart.comisionApp > 0 && cart.comisionLaPagaCliente)
                            _filaResumen(
                              'Uso de la app:',
                              '\$${cart.comisionApp.toStringAsFixed(2)}',
                              true,
                            ),
                          const Divider(height: 20, thickness: 2),
                          _filaResumen('Total:', '\$${cart.total.toStringAsFixed(2)}', false, esTotal: true),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: botonActivo ? Colors.blueAccent : Colors.grey,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: botonActivo
                                  ? () => _intentarConfirmarPedido(context, cart)
                                  : null,
                              child: Text(
                                _obtenerTextoBoton(cart),
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

  void _incrementarConStock(CartProvider cart, CartItem item) {
    final stock = item.stockDisponible;
    if (stock != null && cart.cantidadEnCarrito(item.id) >= stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solo hay $stock disponible(s) de ${item.nombre}.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    cart.incrementarCantidad(item.lineaId);
  }

  bool _puedePersonalizar(CartItem item) {
    if (item.esPromocion || item.esServicio) return false;
    return item.ingredientesBase.isNotEmpty || _catalogoIngredientes.isNotEmpty;
  }

  /// Ingredientes que lleva el platillo: base sin los quitados, más los extras.
  List<String> _ingredientesFinales(CartItem item) {
    final extrasNombres = item.extras.map((e) => e.nombre).toSet();
    final base = item.ingredientesBase
        .where((i) => !item.ingredientesQuitados.contains(i))
        .where((i) => !extrasNombres.contains(i))
        .toList();
    final extras = item.extras.map((e) => e.nombre).toList();
    return [...base, ...extras];
  }

  /// Muestra debajo del platillo los ingredientes que lleva (y lo que se quitó).
  /// Toca la caja para abrir el personalizador.
  Widget? _seccionIngredientesItem(CartProvider cart, CartItem item) {
    if (item.esPromocion) return null;
    final lleva = _ingredientesFinales(item);
    if (lleva.isEmpty && item.ingredientesQuitados.isEmpty) return null;

    final extrasNombres = item.extras.map((e) => e.nombre).toSet();
    final puedeEditar = _puedePersonalizar(item);

    final contenido = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lleva.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  'Lleva:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown.shade400,
                  ),
                ),
                const Spacer(),
                if (puedeEditar)
                  Icon(Icons.touch_app,
                      size: 14, color: Colors.deepOrange.shade300),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: lleva.map((ing) {
                final esExtra = extrasNombres.contains(ing);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: esExtra ? Colors.green.shade100 : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: esExtra
                          ? Colors.green.shade400
                          : Colors.orange.shade200,
                    ),
                  ),
                  child: Text(
                    esExtra ? '+ $ing' : ing,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: esExtra
                          ? Colors.green.shade800
                          : Colors.brown.shade700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (item.ingredientesQuitados.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.do_not_disturb_on,
                    size: 14, color: Colors.redAccent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Sin: ${item.ingredientesQuitados.join(', ')}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (!puedeEditar) return contenido;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _personalizarFlujo(cart, item),
      child: contenido,
    );
  }

  String _etiquetaPago(String m) {
    switch (m) {
      case 'efectivo':
        return 'Efectivo';
      case 'tarjeta':
        return 'Tarjeta';
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

  Widget _buildMostradorClienteSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: Colors.indigo.shade700),
              const SizedBox(width: 8),
              Text(
                'Cliente (opcional)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.indigo.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Teléfono opcional: exactamente 10 dígitos. Sin envío a domicilio.',
            style: TextStyle(fontSize: 12, color: Colors.indigo.shade800),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _clienteNombreCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nombre del cliente',
              hintText: 'Ej. Juan, Mesa 3',
              prefixIcon: const Icon(Icons.badge_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _clienteTelefonoCtrl,
            keyboardType: TextInputType.number,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => _validarTelefonoMostrador(),
            decoration: InputDecoration(
              labelText: 'Teléfono (10 dígitos, opcional)',
              hintText: 'Ej. 8441234567',
              counterText: '',
              errorText: _errorTelefonoMostrador,
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notasMostradorCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Notas del pedido',
              hintText: 'Ej. Para llevar, sin picante',
              prefixIcon: const Icon(Icons.notes),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionMetodoPago() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final pagaCon = double.tryParse(_pagaConCtrl.text.trim());
    final total = cart.total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.blueAccent.shade700, size: 22),
            const SizedBox(width: 8),
            Text(
              _esMostrador ? '¿Cómo paga el cliente?' : '¿Cómo vas a pagar?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _metodosPagoNegocio.map((m) {
            final seleccionado = _metodoPagoSeleccionado == m;
            return ChoiceChip(
              avatar: Icon(
                _iconoPago(m),
                size: 18,
                color: seleccionado ? Colors.white : Colors.blueGrey,
              ),
              label: Text(_etiquetaPago(m)),
              labelStyle: TextStyle(
                color: seleccionado ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              selected: seleccionado,
              selectedColor: Colors.blueAccent,
              backgroundColor: Colors.grey.shade100,
              onSelected: (_) => setState(() {
                _metodoPagoSeleccionado = m;
                if (m != 'efectivo') _pagaConCtrl.clear();
              }),
            );
          }).toList(),
        ),
        if (_metodoPagoSeleccionado == 'efectivo') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _pagaConCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _esMostrador
                  ? '¿Con cuánto paga? (para el cambio)'
                  : '¿Con cuánto vas a pagar? (para tu cambio)',
              hintText: 'Ej. 500',
              prefixText: '\$ ',
              prefixIcon: const Icon(Icons.payments, color: Colors.green),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          if (pagaCon != null && pagaCon > 0) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: pagaCon >= total ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: pagaCon >= total ? Colors.green.shade300 : Colors.orange.shade300,
                ),
              ),
              child: Text(
                pagaCon >= total
                    ? 'Tu cambio: \$${(pagaCon - total).toStringAsFixed(2)} (llevamos tu feria)'
                    : 'Debe ser igual o mayor al total (\$${total.toStringAsFixed(2)}).',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: pagaCon >= total ? Colors.green.shade800 : Colors.orange.shade900,
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Si no pones monto, el repartidor podría no llevar cambio.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
        if (_metodoPagoSeleccionado == 'transferencia') ...[
          const SizedBox(height: 8),
          Text(
            'El negocio te compartirá sus datos para la transferencia.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ],
    );
  }

  Widget _botonEditarIngredientes(CartProvider cart, CartItem item) {
    final personalizado = item.tienePersonalizacion;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.deepOrange.shade50,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _personalizarFlujo(cart, item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  personalizado ? Icons.edit : Icons.restaurant_menu,
                  size: 16,
                  color: Colors.deepOrange,
                ),
                const SizedBox(width: 6),
                Text(
                  personalizado ? 'Editar ingredientes' : 'Personalizar a tu gusto',
                  style: const TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Decide qué línea editar: si hay varias unidades, pregunta cuántas
  /// personalizar y separa esas en una línea aparte; si es 1, edita directo.
  Future<void> _personalizarFlujo(CartProvider cart, CartItem item) async {
    var objetivo = item;
    if (item.cantidad > 1) {
      final cuantas = await _preguntarCuantasModificar(item);
      if (cuantas == null) return;
      final objetivoId = cart.separarParaPersonalizar(item.lineaId, cuantas);
      objetivo = cart.items[objetivoId] ?? item;
    }
    if (!mounted) return;
    await _abrirPersonalizacion(cart, objetivo);
  }

  Future<int?> _preguntarCuantasModificar(CartItem item) {
    int seleccion = 1;
    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('¿Cuántas quieres personalizar?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tienes ${item.cantidad} de "${item.nombre}".\n'
                'Las que elijas se editarán por separado; el resto se queda igual.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 34,
                    color: Colors.blueAccent,
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: seleccion > 1
                        ? () => setDialog(() => seleccion--)
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '$seleccion',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    iconSize: 34,
                    color: Colors.blueAccent,
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: seleccion < item.cantidad
                        ? () => setDialog(() => seleccion++)
                        : null,
                  ),
                ],
              ),
              if (seleccion == item.cantidad)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Se modificarán todas.',
                    style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, seleccion),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirPersonalizacion(CartProvider cart, CartItem item) async {
    final quitados = {...item.ingredientesQuitados};
    final extras = <String, double>{for (final e in item.extras) e.nombre: e.precio};

    final opcionesExtra = <String, double>{
      for (final ing in _catalogoIngredientes) ing.nombre: ing.precioExtra,
    };
    for (final e in item.extras) {
      opcionesExtra.putIfAbsent(e.nombre, () => e.precio);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final extraTotal = extras.values.fold(0.0, (s, p) => s + p);
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.82,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Personalizar: ${item.nombre}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: [
                        if (item.ingredientesBase.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Incluye (desmarca lo que NO quieres)',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ),
                          ...item.ingredientesBase.map((ing) {
                            final incluido = !quitados.contains(ing);
                            return CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              activeColor: Colors.green,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: incluido,
                              title: Text(
                                ing,
                                style: TextStyle(
                                  decoration: incluido ? null : TextDecoration.lineThrough,
                                  color: incluido ? Colors.black87 : Colors.grey,
                                ),
                              ),
                              onChanged: (val) {
                                setSheet(() {
                                  if (val == false) {
                                    quitados.add(ing);
                                  } else {
                                    quitados.remove(ing);
                                  }
                                });
                              },
                            );
                          }),
                          const Divider(height: 24),
                        ],
                        if (opcionesExtra.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Agregar extras',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ),
                          ...opcionesExtra.entries.map((op) {
                            final agregado = extras.containsKey(op.key);
                            return CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              activeColor: Colors.green,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: agregado,
                              title: Text(op.key),
                              secondary: Text(
                                op.value > 0 ? '+\$${op.value.toStringAsFixed(2)}' : 'Gratis',
                                style: TextStyle(
                                  color: op.value > 0 ? Colors.green.shade700 : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onChanged: (val) {
                                setSheet(() {
                                  if (val == true) {
                                    extras[op.key] = op.value;
                                  } else {
                                    extras.remove(op.key);
                                  }
                                });
                              },
                            );
                          }),
                        ],
                        if (item.ingredientesBase.isEmpty && opcionesExtra.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Este producto no tiene ingredientes configurados para personalizar.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (extraTotal > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Extras: +\$${extraTotal.toStringAsFixed(2)} por unidad',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        cart.personalizarItem(
                          item.lineaId,
                          quitados: quitados.toList(),
                          extras: extras.entries
                              .map((e) => ExtraIngrediente(nombre: e.key, precio: e.value))
                              .toList(),
                        );
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Guardar cambios',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _botonCantidad(IconData icono, VoidCallback accion) => SizedBox(
        width: 36,
        height: 36,
        child: IconButton(
          onPressed: accion,
          icon: Icon(icono, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );

  Widget _filaResumen(String titulo, String valor, bool esGris, {bool esTotal = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              titulo,
              style: TextStyle(
                fontSize: esTotal ? 20 : 16,
                fontWeight: esTotal ? FontWeight.bold : FontWeight.normal,
                color: esGris ? Colors.grey : Colors.black,
              ),
            ),
            Text(
              valor,
              style: TextStyle(
                fontSize: esTotal ? 20 : 16,
                fontWeight: esTotal ? FontWeight.bold : FontWeight.normal,
                color: esTotal ? Colors.green : Colors.black,
              ),
            ),
          ],
        ),
      );
}

/// Evita que el mapa parpadee o se reinicie al hacer scroll en el carrito.
class _MetodoChip extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final bool seleccionado;
  final VoidCallback onTap;

  const _MetodoChip({
    required this.titulo,
    required this.icono,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionado ? Colors.blue.shade50 : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: seleccionado ? Colors.blueAccent : Colors.grey.shade300,
              width: seleccionado ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icono, color: seleccionado ? Colors.blueAccent : Colors.grey.shade600, size: 28),
              const SizedBox(height: 6),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: seleccionado ? Colors.blue.shade900 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
