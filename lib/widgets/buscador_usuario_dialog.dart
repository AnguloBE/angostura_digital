import 'dart:async';

import 'package:flutter/material.dart';
import 'package:angostura_digital/services/usuario_busqueda_service.dart';

/// Diálogo para buscar y elegir un usuario por nombre o dígitos del celular.
class BuscadorUsuarioDialog extends StatefulWidget {
  final String titulo;
  final String? subtitulo;

  const BuscadorUsuarioDialog({
    super.key,
    this.titulo = 'Buscar usuario',
    this.subtitulo,
  });

  static Future<UsuarioBusqueda?> mostrar(
    BuildContext context, {
    String titulo = 'Buscar usuario',
    String? subtitulo,
  }) {
    return showDialog<UsuarioBusqueda>(
      context: context,
      builder: (_) => BuscadorUsuarioDialog(titulo: titulo, subtitulo: subtitulo),
    );
  }

  @override
  State<BuscadorUsuarioDialog> createState() => _BuscadorUsuarioDialogState();
}

class _BuscadorUsuarioDialogState extends State<BuscadorUsuarioDialog> {
  final _busquedaCtrl = TextEditingController();
  Timer? _debounce;
  List<UsuarioBusqueda> _resultados = [];
  bool _buscando = false;
  String _ultimaQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  void _onBusquedaChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _ejecutarBusqueda(value));
  }

  Future<void> _ejecutarBusqueda(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      if (mounted) {
        setState(() {
          _resultados = [];
          _buscando = false;
          _ultimaQuery = q;
        });
      }
      return;
    }

    setState(() {
      _buscando = true;
      _ultimaQuery = q;
    });

    try {
      final lista = await UsuarioBusquedaService.buscar(q);
      if (!mounted || _busquedaCtrl.text.trim() != q) return;
      setState(() {
        _resultados = lista;
        _buscando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.subtitulo != null) ...[
              Text(widget.subtitulo!, style: const TextStyle(fontSize: 13, color: Colors.black87)),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _busquedaCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nombre o últimos dígitos del celular',
                hintText: 'Ej. Juan o 4521',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busquedaCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _busquedaCtrl.clear();
                          setState(() {
                            _resultados = [];
                            _ultimaQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (v) {
                setState(() {});
                _onBusquedaChanged(v);
              },
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildLista()),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      ],
    );
  }

  Widget _buildLista() {
    if (_busquedaCtrl.text.trim().length < 2) {
      return Center(
        child: Text(
          'Escribe al menos 2 letras o dígitos.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_buscando) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_resultados.isEmpty) {
      return Center(
        child: Text(
          'Sin resultados para «$_ultimaQuery».',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      itemCount: _resultados.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final u = _resultados[i];
        return ListTile(
          leading: CircleAvatar(
            child: Text(
              u.nombre.isNotEmpty ? u.nombre[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(u.nombre),
          subtitle: Text('${u.telefonoVisible} · ${u.rol}'),
          trailing: const Icon(Icons.add_circle_outline, color: Colors.green),
          onTap: () => Navigator.pop(context, u),
        );
      },
    );
  }
}
