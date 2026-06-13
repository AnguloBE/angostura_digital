import 'package:flutter/material.dart';
import 'package:angostura_digital/services/firebase_service.dart';

/// Verifica un número nuevo con SMS y lo vincula a la cuenta actual.
class EditarTelefonoDialog extends StatefulWidget {
  const EditarTelefonoDialog({super.key, this.telefonoActual = ''});

  final String telefonoActual;

  static Future<bool> mostrar(BuildContext context, {String telefonoActual = ''}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditarTelefonoDialog(telefonoActual: telefonoActual),
    ).then((v) => v == true);
  }

  @override
  State<EditarTelefonoDialog> createState() => _EditarTelefonoDialogState();
}

class _EditarTelefonoDialogState extends State<EditarTelefonoDialog> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  String _lada = '+52';
  bool _codeSent = false;
  bool _cargando = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  String get _telefonoCompleto => '$_lada${_phoneCtrl.text.trim()}';

  Future<void> _enviarSms() async {
    if (_phoneCtrl.text.trim().length < 10) {
      _mensaje('Ingresa un número de 10 dígitos.', Colors.orange);
      return;
    }
    setState(() => _cargando = true);
    final ok = await AuthService().enviarCodigoVincularTelefono(_telefonoCompleto);
    if (!mounted) return;
    setState(() {
      _cargando = false;
      if (ok) {
        _codeSent = true;
        _mensaje('SMS enviado a $_telefonoCompleto', Colors.green);
      } else {
        _mensaje('No se pudo enviar el SMS. Revisa el número.', Colors.red);
      }
    });
  }

  Future<void> _confirmarCodigo() async {
    if (_codeCtrl.text.trim().length < 6) {
      _mensaje('Ingresa el código de 6 dígitos.', Colors.orange);
      return;
    }
    setState(() => _cargando = true);
    final error = await AuthService().confirmarVincularTelefono(_codeCtrl.text.trim());
    if (!mounted) return;
    setState(() => _cargando = false);
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      _mensaje(error, Colors.red);
    }
  }

  void _mensaje(String texto, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar teléfono', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Te enviaremos un SMS para confirmar el nuevo número, igual que al registrarte.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            if (widget.telefonoActual.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Actual: ${widget.telefonoActual}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<String>(
                    initialValue: _lada,
                    decoration: const InputDecoration(
                      labelText: 'Lada',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: '+52', child: Text('🇲🇽 +52')),
                      DropdownMenuItem(value: '+1', child: Text('🇺🇸 +1')),
                    ],
                    onChanged: _codeSent
                        ? null
                        : (v) => setState(() => _lada = v ?? '+52'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    enabled: !_codeSent,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: '10 dígitos',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            if (_codeSent) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Código SMS',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _cargando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_codeSent)
          ElevatedButton(
            onPressed: _confirmarCodigo,
            child: const Text('Confirmar'),
          )
        else
          ElevatedButton(
            onPressed: _enviarSms,
            child: const Text('Enviar SMS'),
          ),
      ],
    );
  }
}
