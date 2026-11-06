import 'package:flutter/material.dart';
import 'package:angostura_digital/services/firebase_service.dart';

/// Pide un nombre de usuario. El predeterminado "Usuario" se trata como vacío.
class EditarNombreDialog extends StatefulWidget {
  const EditarNombreDialog({
    super.key,
    required this.nombreActual,
    required this.titulo,
  });

  final String nombreActual;
  final String titulo;

  static bool esGenerico(String? raw) {
    final n = (raw ?? '').trim().toLowerCase();
    return n.isEmpty || n == 'usuario' || n == 'sin nombre' || n == 'invitado';
  }

  static Future<bool> mostrar(
    BuildContext context, {
    String nombreActual = '',
    String titulo = 'Editar nombre',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => EditarNombreDialog(nombreActual: nombreActual, titulo: titulo),
    ).then((v) => v == true);
  }

  @override
  State<EditarNombreDialog> createState() => _EditarNombreDialogState();
}

class _EditarNombreDialogState extends State<EditarNombreDialog> {
  late final TextEditingController _ctrl;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final inicial = EditarNombreDialog.esGenerico(widget.nombreActual)
        ? ''
        : widget.nombreActual.trim();
    _ctrl = TextEditingController(text: inicial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    final error = await AuthService().actualizarNombre(_ctrl.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _guardando = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre de usuario',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _guardando ? null : _guardar(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
          ),
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
