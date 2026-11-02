import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:angostura_digital/utils/seccion_producto_utils.dart';

/// El negocio escribe o elige la sección del producto (Comida, Refrescos…).
class SelectorSeccion extends StatefulWidget {
  const SelectorSeccion({
    super.key,
    required this.negocioId,
    required this.valorInicial,
    required this.onChanged,
  });

  final String negocioId;
  final String valorInicial;
  final ValueChanged<String> onChanged;

  @override
  State<SelectorSeccion> createState() => _SelectorSeccionState();
}

class _SelectorSeccionState extends State<SelectorSeccion> {
  late final TextEditingController _ctrl;
  List<String> _existentes = const [];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.valorInicial.trim());
    _cargar();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('productos')
          .where('negocio_id', isEqualTo: widget.negocioId)
          .get();
      final nombres = seccionesOrdenadas(
        snap.docs.map((d) => d.data()),
      );
      if (!mounted) return;
      setState(() => _existentes = nombres);
    } catch (_) {}
  }

  void _fijar(String valor) {
    final limpio = valor.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (_ctrl.text != limpio) _ctrl.text = limpio;
    widget.onChanged(limpio);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final actual = _ctrl.text.trim().toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sección del menú',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          'Separa el catálogo para que sea más fácil de encontrar. Ej. Comida, Refrescos, Abarrotes.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _ctrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Sección',
            hintText: 'Ej. Refrescos',
            border: const OutlineInputBorder(),
            suffixIcon: _ctrl.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Quitar sección',
                    icon: const Icon(Icons.clear),
                    onPressed: () => _fijar(''),
                  ),
          ),
          onChanged: _fijar,
        ),
        if (_existentes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _existentes)
                ChoiceChip(
                  label: Text(s),
                  selected: actual == s.toLowerCase(),
                  showCheckmark: false,
                  onSelected: (_) => _fijar(s),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
