import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:angostura_digital/utils/encargo_utils.dart';
import 'package:angostura_digital/utils/pedidos_historial_utils.dart';

/// Cuántos pedidos hay que atender ahora y cuántos encargos siguen abiertos.
class AvisoBandeja {
  final int pendientesAhora;
  final int encargosAbiertos;
  final int atrasados;
  final int hoy;
  final int manana;
  final int despues;

  const AvisoBandeja({
    this.pendientesAhora = 0,
    this.encargosAbiertos = 0,
    this.atrasados = 0,
    this.hoy = 0,
    this.manana = 0,
    this.despues = 0,
  });

  static const vacio = AvisoBandeja();

  bool get encargosUrgentes => atrasados > 0 || hoy > 0;

  String get resumenEncargos {
    final partes = <String>[];
    if (atrasados > 0) {
      partes.add(atrasados == 1 ? '1 atrasado' : '$atrasados atrasados');
    }
    if (hoy > 0) partes.add(hoy == 1 ? '1 para hoy' : '$hoy para hoy');
    if (manana > 0) partes.add(manana == 1 ? '1 para mañana' : '$manana para mañana');
    if (despues > 0) partes.add(despues == 1 ? '1 más adelante' : '$despues más adelante');
    if (partes.isEmpty) return 'Sin encargos pendientes';
    return partes.join(' · ');
  }

  static AvisoBandeja desde(Iterable<Map<String, dynamic>> pedidos) {
    var pendientes = 0;
    var abiertos = 0;
    var atrasados = 0;
    var hoy = 0;
    var manana = 0;
    var despues = 0;
    for (final data in pedidos) {
      if (!PedidosHistorialUtils.esPedidoEnVentanaActiva(data)) continue;
      final grupo = EncargoUtils.cuando(data);
      if (grupo != null) {
        abiertos++;
        if (grupo == 'Atrasados') atrasados++;
        if (grupo == 'Hoy') hoy++;
        if (grupo == 'Mañana') manana++;
        if (grupo == 'Más adelante') despues++;
      }
      final esFuturo = grupo == 'Mañana' || grupo == 'Más adelante';
      if (!esFuturo && (data['estado'] ?? '') == 'Pendiente') pendientes++;
    }
    return AvisoBandeja(
      pendientesAhora: pendientes,
      encargosAbiertos: abiertos,
      atrasados: atrasados,
      hoy: hoy,
      manana: manana,
      despues: despues,
    );
  }
}

class AvisoPedidosNegocio extends StatelessWidget {
  final String negocioId;
  final Widget Function(AvisoBandeja aviso) builder;

  const AvisoPedidosNegocio({
    super.key,
    required this.negocioId,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('negocio_id', isEqualTo: negocioId)
          .limit(200)
          .snapshots(),
      builder: (context, snap) {
        final mapas = snap.data?.docs.map((d) => d.data()) ?? const <Map<String, dynamic>>[];
        return builder(AvisoBandeja.desde(mapas));
      },
    );
  }
}
