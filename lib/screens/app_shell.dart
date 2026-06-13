import 'package:flutter/material.dart';
import 'package:angostura_digital/screens/main_navigation.dart';
import 'package:angostura_digital/services/notificaciones_service.dart';

/// Pantalla principal tras iniciar sesión (notificaciones + navegación).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    NotificacionesService.inicializar();
  }

  @override
  Widget build(BuildContext context) {
    return const MainNavigation();
  }
}
