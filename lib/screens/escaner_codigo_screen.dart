import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Pantalla que abre la cámara para leer un código de barras / QR.
///
/// Devuelve el código leído con `Navigator.pop(context, codigo)`.
class EscanerCodigoScreen extends StatefulWidget {
  const EscanerCodigoScreen({super.key, this.titulo = 'Escanear código'});

  final String titulo;

  /// Abre el escáner y devuelve el código leído (o null si se canceló).
  static Future<String?> escanear(BuildContext context, {String? titulo}) {
    return Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => EscanerCodigoScreen(
          titulo: titulo ?? 'Escanear código',
        ),
      ),
    );
  }

  @override
  State<EscanerCodigoScreen> createState() => _EscanerCodigoScreenState();
}

class _EscanerCodigoScreenState extends State<EscanerCodigoScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.qrCode,
    ],
  );
  bool _yaDetectado = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_yaDetectado) return;
    final codigo = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.trim().isNotEmpty, orElse: () => null);
    if (codigo == null) return;
    _yaDetectado = true;
    Navigator.pop(context, codigo.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.titulo),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.no_photography,
                          color: Colors.white70, size: 60),
                      const SizedBox(height: 16),
                      Text(
                        'No se pudo abrir la cámara.\n${error.errorDetails?.message ?? ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Marco guía
          Container(
            width: 250,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.greenAccent, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Text(
              'Apunta la cámara al código de barras del producto',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
