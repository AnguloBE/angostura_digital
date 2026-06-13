import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:angostura_digital/utils/pedido_mostrador_utils.dart';
import 'package:angostura_digital/utils/telefono_local_utils.dart';

class EditarPedidoMostradorDialog extends StatefulWidget {
  final String pedidoId;
  final Map<String, dynamic> pedido;

  const EditarPedidoMostradorDialog({
    super.key,
    required this.pedidoId,
    required this.pedido,
  });

  static Future<bool> mostrar(
    BuildContext context, {
    required String pedidoId,
    required Map<String, dynamic> pedido,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => EditarPedidoMostradorDialog(pedidoId: pedidoId, pedido: pedido),
    ).then((v) => v == true);
  }

  @override
  State<EditarPedidoMostradorDialog> createState() =>
      _EditarPedidoMostradorDialogState();
}

class _EditarPedidoMostradorDialogState extends State<EditarPedidoMostradorDialog> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _notasCtrl;
  late final TextEditingController _pagaConCtrl;
  bool _guardando = false;
  String? _errorTelefono;

  List<String> get _metodosPago {
    final metodos = (widget.pedido['metodos_pago_negocio'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>['efectivo', 'tarjeta', 'transferencia'];
    return metodos.isEmpty ? const ['efectivo'] : metodos;
  }

  late String _metodoPago;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(
      text: (widget.pedido['cliente_nombre'] ?? '').toString(),
    );
    _telefonoCtrl = TextEditingController(
      text: TelefonoLocalUtils.soloDigitos(
        (widget.pedido['cliente_telefono'] ?? '').toString(),
      ),
    );
    _notasCtrl = TextEditingController(text: (widget.pedido['notas'] ?? '').toString());
    _pagaConCtrl = TextEditingController(
      text: widget.pedido['paga_con']?.toString() ?? '',
    );
    _metodoPago = (widget.pedido['metodo_pago'] ?? 'efectivo').toString();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _notasCtrl.dispose();
    _pagaConCtrl.dispose();
    super.dispose();
  }

  void _validarTelefono() {
    setState(() {
      _errorTelefono = TelefonoLocalUtils.mensajeErrorOpcional(_telefonoCtrl.text);
    });
  }

  Future<void> _guardar() async {
    _validarTelefono();
    if (_errorTelefono != null) return;

    setState(() => _guardando = true);
    try {
      final nombre = _nombreCtrl.text.trim();
      final telefono = TelefonoLocalUtils.normalizar(_telefonoCtrl.text);
      final notas = _notasCtrl.text.trim();
      final total = (widget.pedido['total'] as num?)?.toDouble() ?? 0;

      final datos = <String, dynamic>{
        'notas': notas,
        'metodo_pago': _metodoPago,
        'direccion': PedidoMostradorUtils.textoDireccionMostrador(nombre),
      };

      if (nombre.isNotEmpty) {
        datos['cliente_nombre'] = nombre;
      } else {
        datos['cliente_nombre'] = FieldValue.delete();
      }

      if (telefono.isNotEmpty) {
        datos['cliente_telefono'] = telefono;
      } else {
        datos['cliente_telefono'] = FieldValue.delete();
      }

      if (_metodoPago == 'efectivo') {
        final pagaCon = double.tryParse(_pagaConCtrl.text.trim());
        if (pagaCon != null && pagaCon > 0) {
          datos['paga_con'] = pagaCon;
          datos['cambio'] = pagaCon - total;
        } else {
          datos['paga_con'] = FieldValue.delete();
          datos['cambio'] = FieldValue.delete();
        }
      } else {
        datos['paga_con'] = FieldValue.delete();
        datos['cambio'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance
          .collection('pedidos')
          .doc(widget.pedidoId)
          .update(datos);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String _etiquetaPago(String m) {
    switch (m) {
      case 'tarjeta':
        return 'Tarjeta';
      case 'transferencia':
        return 'Transferencia';
      default:
        return 'Efectivo';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar pedido en local'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del cliente',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _telefonoCtrl,
              keyboardType: TextInputType.number,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => _validarTelefono(),
              decoration: InputDecoration(
                labelText: 'Teléfono (10 dígitos, opcional)',
                counterText: '',
                errorText: _errorTelefono,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notasCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notas',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Método de pago', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _metodosPago.map((m) {
                return ChoiceChip(
                  label: Text(_etiquetaPago(m)),
                  selected: _metodoPago == m,
                  onSelected: (_) => setState(() => _metodoPago = m),
                );
              }).toList(),
            ),
            if (_metodoPago == 'efectivo') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _pagaConCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Paga con (efectivo)',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _guardando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
