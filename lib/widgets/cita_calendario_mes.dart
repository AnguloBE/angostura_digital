import 'package:flutter/material.dart';

/// Calendario mensual cuadrado para elegir un día.
class CitaCalendarioMes extends StatelessWidget {
  const CitaCalendarioMes({
    super.key,
    required this.mesVisible,
    required this.diaSeleccionado,
    required this.diasHabilitados,
    required this.onDiaTap,
    required this.onMesAnterior,
    required this.onMesSiguiente,
    this.primerDiaHabilitado,
    this.ultimoDiaHabilitado,
  });

  final DateTime mesVisible;
  final DateTime? diaSeleccionado;
  final bool Function(DateTime dia) diasHabilitados;
  final ValueChanged<DateTime> onDiaTap;
  final VoidCallback onMesAnterior;
  final VoidCallback onMesSiguiente;
  final DateTime? primerDiaHabilitado;
  final DateTime? ultimoDiaHabilitado;

  static const _meses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  static bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final primeroMes = DateTime(mesVisible.year, mesVisible.month, 1);
    final diasEnMes = DateTime(mesVisible.year, mesVisible.month + 1, 0).day;
    // Lunes = 0 en la fila (weekday 1 -> 0)
    final offset = primeroMes.weekday - 1;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(onPressed: onMesAnterior, icon: const Icon(Icons.chevron_left)),
            Text(
              '${_meses[mesVisible.month - 1]} ${mesVisible.year}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            IconButton(onPressed: onMesSiguiente, icon: const Icon(Icons.chevron_right)),
          ],
        ),
        Row(
          children: ['L', 'M', 'X', 'J', 'V', 'S', 'D']
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemCount: offset + diasEnMes,
          itemBuilder: (_, index) {
            if (index < offset) return const SizedBox.shrink();

            final diaNum = index - offset + 1;
            final dia = DateTime(mesVisible.year, mesVisible.month, diaNum);
            final hoy = DateTime.now();
            final esHoy = _mismoDia(dia, hoy);

            var habilitado = diasHabilitados(dia);
            if (primerDiaHabilitado != null && dia.isBefore(primerDiaHabilitado!)) {
              habilitado = false;
            }
            if (ultimoDiaHabilitado != null && dia.isAfter(ultimoDiaHabilitado!)) {
              habilitado = false;
            }

            final seleccionado =
                diaSeleccionado != null && _mismoDia(dia, diaSeleccionado!);

            Color fondo = Colors.grey.shade100;
            Color texto = Colors.grey.shade400;
            if (habilitado) {
              fondo = seleccionado
                  ? Colors.deepPurple
                  : esHoy
                      ? Colors.deepPurple.shade50
                      : Colors.white;
              texto = seleccionado
                  ? Colors.white
                  : esHoy
                      ? Colors.deepPurple
                      : Colors.black87;
            }

            return Material(
              color: fondo,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: habilitado ? () => onDiaTap(dia) : null,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: seleccionado
                          ? Colors.deepPurple
                          : esHoy && habilitado
                              ? Colors.deepPurple.shade200
                              : Colors.grey.shade300,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$diaNum',
                    style: TextStyle(
                      fontWeight:
                          seleccionado || esHoy ? FontWeight.bold : FontWeight.normal,
                      color: texto,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
