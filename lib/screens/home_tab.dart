import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:angostura_digital/globals.dart' as globals;
import 'package:angostura_digital/widgets/drawer.dart';
import 'package:angostura_digital/screens/menu_negocio_screen.dart';
import 'package:angostura_digital/providers/cart_provider.dart';
import 'package:angostura_digital/widgets/square_image.dart';
import 'package:angostura_digital/utils/producto_pedido_utils.dart';
import 'package:angostura_digital/utils/dias_semana.dart';
import 'package:angostura_digital/widgets/editar_nombre_dialog.dart';
import 'package:angostura_digital/widgets/editar_telefono_dialog.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      drawer: const DrawerPrincipal(),
      appBar: AppBar(
        title: const Text(
          'Promociones en Angostura',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: globals.colorFondo,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const _CuerpoPromos(),
    );
  }
}

class _CuerpoPromos extends StatefulWidget {
  const _CuerpoPromos();

  @override
  State<_CuerpoPromos> createState() => _CuerpoPromosState();
}

class _CuerpoPromosState extends State<_CuerpoPromos> {
  late final Stream<User?> _authStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _anuncios;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _promos;
  String? _perfilUid;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _perfilStream;

  @override
  void initState() {
    super.initState();
    _authStream = FirebaseAuth.instance.userChanges();
    _anuncios = FirebaseFirestore.instance.collection('anuncios').snapshots();
    _promos = FirebaseFirestore.instance
        .collection('promociones')
        .orderBy('fecha_creacion', descending: true)
        .limit(40)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _perfilDe(String uid) {
    if (_perfilUid != uid || _perfilStream == null) {
      _perfilUid = uid;
      _perfilStream = FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots();
    }
    return _perfilStream!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, userSnap) {
        final user = userSnap.data;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _anuncios,
          builder: (context, anSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _promos,
              builder: (context, prSnap) {
                if (user == null || user.isAnonymous) {
                  return _lista(context, anSnap, prSnap, mostrarLogin: true);
                }
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _perfilDe(user.uid),
                  builder: (context, perfilSnap) {
                    final data = perfilSnap.data?.data();
                    final nombre = _nombreVisible(data, user);
                    final pedirNombre = perfilSnap.hasData &&
                        data?['nombre_elegido'] != true &&
                        EditarNombreDialog.esGenerico(nombre);
                    final cargando = _esperando(anSnap) || _esperando(prSnap);
                    if (cargando && !pedirNombre) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _lista(
                      context,
                      anSnap,
                      prSnap,
                      mostrarNombre: pedirNombre,
                      nombreActual: nombre,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  bool _esperando(AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap) {
    return snap.connectionState == ConnectionState.waiting && !snap.hasData && !snap.hasError;
  }

  Widget _lista(
    BuildContext context,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> anSnap,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> prSnap, {
    bool mostrarLogin = false,
    bool mostrarNombre = false,
    String nombreActual = '',
  }) {
    final entradas = <_Entrada>[
      for (final doc in anSnap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
        if (DiasSemana.vigente(doc.data(), ocultarInactivos: true)) _Entrada.anuncio(doc),
      for (final doc in prSnap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
        if (DiasSemana.vigente(doc.data())) _Entrada.promo(doc),
    ];
    entradas.sort((a, b) {
      if (a.destacado != b.destacado) return a.destacado ? -1 : 1;
      return b.fecha.compareTo(a.fecha);
    });

    final usable = MediaQuery.sizeOf(context).width - 32;
    const gap = 16.0;
    const target = 340.0;
    var columns = (usable / target).floor();
    if (columns < 1) columns = 1;
    if (usable < 560) columns = 1;
    final cardWidth = (usable - gap * (columns - 1)) / columns;

    final tarjetas = <Widget>[
      if (mostrarLogin)
        _TarjetaAviso(
          ancho: usable,
          color: Colors.green.shade700,
          icono: Icons.phone_android,
          titulo: 'Inicia sesión con tu número',
          texto: 'Para pedir y ver tus pedidos, entra con tu teléfono. Te llega un SMS con el código.',
          boton: 'Entrar con mi número',
          onTap: () => EditarTelefonoDialog.mostrar(context, ingresar: true),
        ),
      if (mostrarNombre)
        _TarjetaAviso(
          ancho: usable,
          color: Colors.blueAccent.shade700,
          icono: Icons.person,
          titulo: 'Elige tu nombre de usuario',
          texto: 'Así te reconocen los negocios cuando haces un pedido.',
          boton: 'Elegir nombre',
          onTap: () async {
            final ok = await EditarNombreDialog.mostrar(
              context,
              nombreActual: nombreActual,
              titulo: 'Elige tu nombre de usuario',
            );
            if (ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nombre actualizado'), backgroundColor: Colors.green),
              );
            }
          },
        ),
      for (final entrada in entradas)
        if (entrada.esAnuncio)
          _TarjetaAnuncio(ancho: cardWidth, data: entrada.doc.data())
        else
          _TarjetaPromocion(ancho: cardWidth, id: entrada.doc.id, promo: entrada.doc.data()),
    ];

    if (tarjetas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 15),
            const Text(
              'Aún no hay promociones activas.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.start,
          spacing: gap,
          runSpacing: gap,
          children: tarjetas,
        ),
      ),
    );
  }
}

String _nombreVisible(Map<String, dynamic>? data, User user) {
  final enBd = data?['nombre']?.toString().trim() ?? '';
  if (enBd.isNotEmpty) return enBd;
  final enAuth = user.displayName?.trim() ?? '';
  if (enAuth.isNotEmpty) return enAuth;
  return '';
}

class _Entrada {
  _Entrada.anuncio(this.doc) : esAnuncio = true;
  _Entrada.promo(this.doc) : esAnuncio = false;

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool esAnuncio;

  bool get destacado => doc.data()['destacado'] == true;

  DateTime get fecha {
    final f = doc.data()['fecha_creacion'];
    if (f is Timestamp) return f.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _TarjetaAviso extends StatelessWidget {
  const _TarjetaAviso({
    required this.ancho,
    required this.color,
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.boton,
    required this.onTap,
  });

  final double ancho;
  final Color color;
  final IconData icono;
  final String titulo;
  final String texto;
  final String boton;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      child: Card(
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 96,
                width: double.infinity,
                color: color,
                child: Stack(
                  children: [
                    Center(child: Icon(icono, color: Colors.white, size: 42)),
                    Positioned(top: 12, right: 12, child: _etiqueta('ANUNCIO', Colors.black45)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(texto, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.35)),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                        onPressed: onTap,
                        child: Text(boton),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaAnuncio extends StatelessWidget {
  const _TarjetaAnuncio({required this.ancho, required this.data});

  final double ancho;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final titulo = (data['titulo'] ?? 'Aviso').toString();
    final descripcion = (data['descripcion'] ?? '').toString();
    final foto = (data['foto_url'] ?? '').toString();
    final destacado = data['destacado'] == true;
    final cuando = DiasSemana.vigencia(data, sinFecha: 'Visible hasta que lo quiten');

    return SizedBox(
      width: ancho,
      child: Card(
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: destacado ? BorderSide(color: Colors.amber.shade600, width: 2) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _abrir(context, titulo, descripcion, foto, cuando),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (foto.isNotEmpty)
                Stack(
                  children: [
                    SquareImage(
                      imageUrl: foto,
                      placeholder: Container(
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.campaign, size: 50, color: Colors.grey),
                      ),
                    ),
                    ..._marcas(destacado),
                  ],
                )
              else
                Container(
                  height: 96,
                  width: double.infinity,
                  color: Colors.blueGrey.shade700,
                  child: Stack(
                    children: [
                      const Center(child: Icon(Icons.campaign, color: Colors.white, size: 42)),
                      ..._marcas(destacado),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aviso de Angostura',
                      style: TextStyle(fontSize: 14, color: Colors.blueAccent.shade700, fontWeight: FontWeight.w600),
                    ),
                    if (descripcion.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        descripcion,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            cuando,
                            style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _marcas(bool destacado) {
    return [
      if (destacado) Positioned(top: 12, left: 12, child: _estrella()),
      Positioned(top: 12, right: 12, child: _etiqueta('ANUNCIO', Colors.blueGrey.shade800)),
    ];
  }

  void _abrir(BuildContext context, String titulo, String descripcion, String foto, String cuando) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (foto.isNotEmpty) ...[
                SquareImage(imageUrl: foto, size: 220, borderRadius: BorderRadius.circular(12)),
                const SizedBox(height: 12),
              ],
              if (descripcion.isNotEmpty) Text(descripcion, style: const TextStyle(height: 1.35)),
              const SizedBox(height: 8),
              Text(cuando, style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }
}

class _TarjetaPromocion extends StatelessWidget {
  const _TarjetaPromocion({required this.ancho, required this.id, required this.promo});

  final double ancho;
  final String id;
  final Map<String, dynamic> promo;

  @override
  Widget build(BuildContext context) {
    final destacado = promo['destacado'] == true;
    final cuando = DiasSemana.vigencia(promo);
    return SizedBox(
      width: ancho,
      child: Card(
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: destacado ? BorderSide(color: Colors.amber.shade600, width: 2) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _agregar(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SquareImage(
                    imageUrl: promo['foto_url']?.toString(),
                    placeholder: Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image, size: 50, color: Colors.grey),
                    ),
                  ),
                  if (destacado) Positioned(top: 12, left: 12, child: _estrella()),
                  Positioned(top: 12, right: 12, child: _etiqueta('¡OFERTA!', Colors.redAccent)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promo['titulo']?.toString() ?? 'Sin título',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Por: ${promo['nombre_negocio'] ?? 'Negocio local'}',
                      style: TextStyle(fontSize: 14, color: Colors.blueAccent.shade700, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if ((promo['descripcion'] ?? '').toString().isNotEmpty)
                      Text(
                        promo['descripcion'].toString(),
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: Colors.redAccent),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            cuando,
                            style: const TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Precio normal', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(
                              '\$${promo['precio_normal']}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Text('A solo: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
                            Text(
                              '\$${promo['precio_promo']}',
                              style: const TextStyle(fontSize: 26, color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _agregar(BuildContext context) {
    final idNegocio = (promo['negocio_id'] ?? '').toString();
    final nombrePromo = '🔥 ${promo['titulo'] ?? 'Oferta'}';
    final precioPromo = _numero(promo['precio_promo']);
    final fotoPromo = promo['foto_url']?.toString();
    final nombreDelLocal = (promo['nombre_negocio'] ?? 'Negocio').toString();
    final cart = Provider.of<CartProvider>(context, listen: false);

    final agregado = cart.agregarProducto(
      idNegocio,
      id,
      nombrePromo,
      precioPromo,
      fotoPromo,
      detalles: ProductoPedidoUtils.detallesDesdePromocion(promo),
      esPromocion: true,
    );

    if (agregado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Oferta agregada al carrito! 🛒🤤'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MenuNegocioScreen(negocioId: idNegocio, nombreNegocio: nombreDelLocal),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Carrito Ocupado', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Tu carrito tiene productos de otro restaurante. Por políticas de entrega, solo puedes pedir de un local a la vez.\n\n¿Deseas vaciar tu carrito actual y aprovechar esta oferta?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              cart.limpiarCarrito();
              cart.agregarProducto(
                idNegocio,
                id,
                nombrePromo,
                precioPromo,
                fotoPromo,
                detalles: ProductoPedidoUtils.detallesDesdePromocion(promo),
                esPromocion: true,
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Carrito vaciado. Oferta agregada.'), backgroundColor: Colors.green),
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MenuNegocioScreen(negocioId: idNegocio, nombreNegocio: nombreDelLocal),
                ),
              );
            },
            child: const Text('Sí, vaciar y agregar'),
          ),
        ],
      ),
    );
  }
}

double _numero(dynamic valor) {
  if (valor is num) return valor.toDouble();
  return double.tryParse('${valor ?? ''}') ?? 0;
}

Widget _etiqueta(String texto, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
    ),
    child: Text(
      texto,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12),
    ),
  );
}

Widget _estrella() {
  return Container(
    padding: const EdgeInsets.all(6),
    decoration: const BoxDecoration(
      color: Color(0xFFF9A825),
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
    ),
    child: const Icon(Icons.star_rounded, color: Colors.white, size: 18),
  );
}
