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
            Text('Aqui apareceran anuncios OMG, apoco con un git push se actualiza esta baina?'),
            Text('Por ejemplo promociones, a ver prueba 2, ojala que funcione'),
            Text('O nuevos negocios, que coraje que no se actualiza de volada'),
            Text('Cualquier cosa que sea reelevante, ya estoy arto :c la ultima y nos vamos'),
            Text('Ya funciona, osi osi, que feliz que estoy :D'),
          ],
        ),
      ),
    );
  }
}