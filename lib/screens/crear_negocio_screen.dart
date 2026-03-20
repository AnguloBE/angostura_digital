import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:angostura_digital/globals.dart' as globals;

class CrearNegocioScreen extends StatefulWidget {
  const CrearNegocioScreen({super.key});

  @override
  State<CrearNegocioScreen> createState() => _CrearNegocioScreenState();
}

class _CrearNegocioScreenState extends State<CrearNegocioScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  
  String _categoriaSeleccionada = 'Restaurante / Comida';
  bool _isLoading = false;

  final List<String> _categorias = [
    'Restaurante / Comida',
    'Abarrotes y Supermercados',
    'Ropa y Accesorios',
    'Servicios Profesionales',
    'Postres y Antojos',
    'Otro'
  ];

  Future<void> _guardarNegocio() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        // Guardamos el negocio en la colección 'negocios'
        await FirebaseFirestore.instance.collection('negocios').add({
          'nombre': _nombreController.text.trim(),
          'descripcion': _descripcionController.text.trim(),
          'categoria': _categoriaSeleccionada,
          'propietario_uid': user.uid,
          'estado': 'pendiente', // ¡Aquí está el Filtro del Jefe!
          'fecha_creacion': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Negocio enviado a revisión. Un administrador lo aprobará pronto.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Regresamos a la pantalla anterior
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Negocio'),
        backgroundColor: globals.colorFondo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ingresa los datos de tu negocio. Una vez enviado, nuestro equipo lo revisará antes de publicarlo en la app.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),
              
              // Campo: Nombre del Negocio
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Negocio',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.storefront),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingresa el nombre.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Campo: Categoría
              DropdownButtonFormField<String>(
                value: _categoriaSeleccionada,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categorias.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _categoriaSeleccionada = val!;
                  });
                },
              ),
              const SizedBox(height: 15),

              // Campo: Descripción
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción breve (Qué vendes)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Agrega una pequeña descripción.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // Botón Guardar
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _guardarNegocio,
                  child: const Text('Enviar para Revisión', style: TextStyle(fontSize: 16)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}