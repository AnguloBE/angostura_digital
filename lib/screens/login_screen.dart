import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:angostura_digital/services/firebase_service.dart'; // Tu ruta al AuthService
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  bool _codeSent = false;
  RecaptchaVerifier? _verifier;

  // Variable para guardar el código de país seleccionado (por defecto México)
  String _selectedCountryCode = '+52';

  // Lista de códigos de país (puedes agregar más si en el futuro se ocupa)
  final List<Map<String, String>> _countryCodes = [
    {'code': '+52', 'name': '🇲🇽 +52'},
    {'code': '+1', 'name': '🇺🇸 +1'},
  ];

  @override
  void initState() {
    super.initState();
    // Al no poner 'container', 'size' ni 'theme', Firebase lo hace INVISIBLE por defecto.
    _verifier = RecaptchaVerifier(
      auth: FirebaseAuthPlatform.instance, 
    );
  }

  void _sendSms() async {
    if (_phoneController.text.isEmpty) return;
    setState(() => _isLoading = true);
    
    // Concatenamos el código de país con el número ingresado
    final String fullPhoneNumber = '$_selectedCountryCode${_phoneController.text.trim()}';
    
    final success = await AuthService().sendCode(fullPhoneNumber, _verifier!);
    
    setState(() {
      _isLoading = false;
      if (success) {
        _codeSent = true;
        _showSuccess('SMS enviado con éxito a $fullPhoneNumber');
      } else {
        _showError('Error al enviar SMS. Verifica el número.');
      }
    });
  }

  void _verifySms() async {
    if (_codeController.text.isEmpty) return;
    setState(() => _isLoading = true);
    
    final user = await AuthService().verifyCode(_codeController.text);
    
    setState(() => _isLoading = false);
    if (user == null) {
      _showError('Código incorrecto');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Icon(Icons.campaign_rounded, size: 80, color: Colors.blueAccent),
              const Text('Angostura Digital', 
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              
              // Fila para el Dropdown del país y el TextField del teléfono
              // Fila para el Dropdown del país y el TextField del teléfono
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120, // Ancho fijo para que no se coma el espacio del teléfono
                    child: DropdownButtonFormField<String>(
                      value: _selectedCountryCode,
                      decoration: const InputDecoration(
                        labelText: 'Lada', // Le ponemos label para que la altura superior cuadre perfecto
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                      ),
                      items: _countryCodes.map((country) {
                        return DropdownMenuItem<String>(
                          value: country['code'],
                          child: Text(country['name']!, style: const TextStyle(fontSize: 16)),
                        );
                      }).toList(),
                      onChanged: _codeSent ? null : (value) {
                        setState(() {
                          _selectedCountryCode = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      enabled: !_codeSent,
                      decoration: const InputDecoration(
                        labelText: 'Número a 10 dígitos',
                        border: OutlineInputBorder(),
                        counterText: '', // ESTO oculta el contador y alinea el borde inferior
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                    ),
                  ),
                ],
              ),

              if (_codeSent) ...[
                const SizedBox(height: 15),
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Código de 6 dígitos',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
              ],

              const SizedBox(height: 25),

              if (_isLoading)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _codeSent ? _verifySms : _sendSms,
                      child: Text(_codeSent ? 'Verificar Código' : 'Enviar SMS'),
                    ),
                  ],
                ),
              const SizedBox(height: 50), 
            ],
          ),
        ),
      ),
    );
  }
}