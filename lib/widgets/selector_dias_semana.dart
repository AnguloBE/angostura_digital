import 'package:flutter/material.dart';
import 'package:angostura_digital/utils/dias_semana.dart';

/// Chips de lunes a domingo. Ninguno marcado = se muestra todos los días.
class SelectorDiasSemana extends StatelessWidget {
  const SelectorDiasSemana({
    super.key,
    required this.seleccion,
    required this.onChanged,
  });

  final Set<int> seleccion;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Días en que se muestra', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          seleccion.isEmpty
              ? 'Si no marcas días, se ve todos los días.'
              : 'Se repite sola ${DiasSemana.frase(seleccion)}, sin volver a publicarla.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.3),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var d = 1; d <= 7; d++)
              FilterChip(
                label: Text(DiasSemana.corto(d)),
                selected: seleccion.contains(d),
                onSelected: (on) {
                  final next = Set<int>.from(seleccion);
                  if (on) {
                    next.add(d);
                  } else {
                    next.remove(d);
                  }
                  onChanged(next.length >= 7 ? <int>{} : next);
                },
              ),
          ],
        ),
        if (seleccion.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => onChanged(<int>{}),
              child: const Text('Ver todos los días'),
            ),
          ),
      ],
    );
  }
}

Future<DateTime?> elegirFechaLimite(BuildContext context, DateTime? actual) {
  final ahora = DateTime.now();
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  var inicial = actual ?? hoy;
  final inicialDia = DateTime(inicial.year, inicial.month, inicial.day);
  if (inicialDia.isBefore(hoy)) inicial = hoy;
  return showDatePicker(
    context: context,
    initialDate: inicial,
    firstDate: hoy,
    lastDate: hoy.add(const Duration(days: 365 * 3)),
  );
}
