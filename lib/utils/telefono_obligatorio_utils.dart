import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:angostura_digital/widgets/editar_telefono_dialog.dart';

/// El teléfono verificado por SMS es obligatorio para pedir o reservar citas.
class TelefonoObligatorioUtils {
  TelefonoObligatorioUtils._();

  /// `true` si Firebase Auth tiene un número vinculado (verificado por SMS).
  static Future<bool> tieneTelefonoVerificado() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
    } catch (_) {}
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber?.trim();
    return phone != null && phone.isNotEmpty;
  }

  /// Muestra aviso y abre el flujo de verificación SMS. Retorna `true` si quedó verificado.
  static Future<bool> solicitarVerificacion(BuildContext context) async {
    final ya = await tieneTelefonoVerificado();
    if (ya) return true;

    if (!context.mounted) return false;

    final continuar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verifica tu teléfono'),
        content: const Text(
          'Para hacer pedidos o reservar citas necesitamos tu número de celular.\n\n'
          'Te enviaremos un SMS con un código, igual que al registrarte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ahora no'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verificar número'),
          ),
        ],
      ),
    );

    if (continuar != true || !context.mounted) return false;

    final ok = await EditarTelefonoDialog.mostrar(context);
    if (!ok) return false;

    return tieneTelefonoVerificado();
  }
}
