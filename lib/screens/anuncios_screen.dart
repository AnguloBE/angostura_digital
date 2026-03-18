import 'package:angostura_digital/widgets/drawer.dart';
import 'package:flutter/material.dart';
import 'package:angostura_digital/globals.dart' as globals;

class AnunciosScreen extends StatelessWidget {
  const AnunciosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anuncios'),
        centerTitle: true,
        backgroundColor: globals.colorFondo,
      ),
      drawer: DrawerPrincipal(),

      body: Padding(padding: EdgeInsets.all(8),
        child: Column(

          children: [
            Text('Aqui apareceran anuncios'),
            Text('Por ejemplo promociones'),
            Text('O nuevos negocios'),
            Text('Cualquier cosa que sea reelevante'),
          ],
        ),
      ),
    );
  }
}