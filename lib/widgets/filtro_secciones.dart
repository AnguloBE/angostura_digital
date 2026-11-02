import 'package:flutter/material.dart';

/// Chips horizontales: Todas y cada sección del catálogo.
class FiltroSecciones extends StatelessWidget {
  const FiltroSecciones({
    super.key,
    required this.secciones,
    required this.seleccionada,
    required this.onSeleccionada,
    this.incluirSinSeccion = false,
  });

  final List<String> secciones;
  final String seleccionada;
  final ValueChanged<String> onSeleccionada;
  final bool incluirSinSeccion;

  @override
  Widget build(BuildContext context) {
    final chips = <String>['', ...secciones];
    if (incluirSinSeccion) chips.add('Sin sección');

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final valor = chips[i];
          final activo = seleccionada == valor;
          final texto = valor.isEmpty ? 'Todas' : valor;
          return ChoiceChip(
            label: Text(texto),
            selected: activo,
            showCheckmark: false,
            labelStyle: TextStyle(
              color: activo ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            selectedColor: Colors.blueAccent,
            backgroundColor: Colors.grey.shade100,
            side: BorderSide(color: activo ? Colors.blueAccent : Colors.grey.shade300),
            onSelected: (_) => onSeleccionada(valor),
          );
        },
      ),
    );
  }
}
