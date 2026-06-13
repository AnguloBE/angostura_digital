import 'package:cloud_firestore/cloud_firestore.dart';



/// Acumulación y reversión de comisión: Cloud Functions (pedidos).

/// Pagos: el admin crea un doc en comision_pagos y la función ajusta el saldo.

class NegocioComisionService {

  static final _db = FirebaseFirestore.instance;



  /// Registra un pago; [onComisionPagoRegistrado] actualiza saldo y último pago.

  static Future<void> registrarPago({

    required String negocioId,

    required double monto,

  }) async {

    if (monto <= 0) {

      throw ArgumentError('El monto del pago debe ser mayor a cero.');

    }

    await _db.collection('negocios').doc(negocioId).collection('comision_pagos').add({

      'monto': double.parse(monto.toStringAsFixed(2)),

      'creado_en': FieldValue.serverTimestamp(),

    });

  }

}

