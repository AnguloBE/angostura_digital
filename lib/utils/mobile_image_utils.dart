import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:angostura_digital/utils/imagen_plataforma.dart';

/// Utilidades para elegir, recortar y leer imágenes en computadora, Android e iOS.
class MobileImageUtils {
  static final ImagePicker _picker = ImagePicker();

  /// Teléfono o tablet: app nativa, Chrome en Android o Safari en iPhone/iPad.
  static bool get camaraDisponible {
    if (kIsWeb) return esNavegadorMovil;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static List<PlatformUiSettings> cropUiSettings(
    BuildContext context, {
    required String title,
    CropAspectRatioPreset androidPreset = CropAspectRatioPreset.square,
    bool lockAspectRatio = true,
  }) {
    return [
      AndroidUiSettings(
        toolbarTitle: title,
        toolbarColor: Colors.blueAccent,
        toolbarWidgetColor: Colors.white,
        initAspectRatio: androidPreset,
        lockAspectRatio: lockAspectRatio,
      ),
      IOSUiSettings(
        title: title,
        aspectRatioLockEnabled: lockAspectRatio,
        resetAspectRatioEnabled: !lockAspectRatio,
      ),
      if (kIsWeb)
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: _tamanoRecorteWeb(context),
          viewwMode: WebViewMode.mode_1,
          dragMode: WebDragMode.move,
          // Las fotos de la cámara llegan como blob. Si el recortador
          // intenta leerlas otra vez, en el teléfono a veces falla.
          checkCrossOrigin: false,
          checkOrientation: false,
          zoomOnTouch: true,
          zoomOnWheel: true,
          minContainerWidth: 48,
          minContainerHeight: 48,
          translations: WebTranslations(
            title: title,
            rotateLeftTooltip: 'Girar a la izquierda',
            rotateRightTooltip: 'Girar a la derecha',
            cancelButton: 'Cancelar',
            cropButton: 'Recortar',
          ),
          customDialogBuilder: (cropper, initCropper, crop, rotate, scale) {
            return _DialogoRecorte(
              titulo: title,
              cropper: cropper,
              initCropper: initCropper,
              crop: crop,
              rotate: rotate,
              scale: scale,
            );
          },
        ),
    ];
  }

  /// Abre la hoja para tomar o elegir una foto, la recorta y devuelve los bytes.
  ///
  /// En teléfono (incluida la web en Chrome o Safari) ofrece la cámara.
  /// En computadora solo la galería, que es el selector de archivos.
  static Future<Uint8List?> elegirYRecortar({
    required BuildContext context,
    required String cropTitle,
    String galleryLabel = 'Elegir de la galería',
    String cameraLabel = 'Tomar foto',
    CropAspectRatio aspectRatio = const CropAspectRatio(ratioX: 1, ratioY: 1),
    CropAspectRatioPreset androidPreset = CropAspectRatioPreset.square,
    int imageQuality = 70,
    int compressQuality = 50,
    int maxWidth = 600,
    int maxHeight = 600,
  }) {
    final resultado = Completer<Uint8List?>();
    var esperandoFoto = false;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _HojaFoto(
        mostrarCamara: camaraDisponible,
        galleryLabel: galleryLabel,
        cameraLabel: cameraLabel,
        alPulsar: () => esperandoFoto = true,
        alQuedarEnHoja: () {
          esperandoFoto = false;
          if (!sheetContext.mounted && !resultado.isCompleted) {
            resultado.complete(null);
          }
        },
        alTerminar: (bytes) {
          esperandoFoto = false;
          if (!resultado.isCompleted) resultado.complete(bytes);
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
        procesar: (source, alEmpezarProceso) => _tomarRecortar(
          context,
          source: source,
          cropTitle: cropTitle,
          aspectRatio: aspectRatio,
          androidPreset: androidPreset,
          imageQuality: imageQuality,
          compressQuality: compressQuality,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          alEmpezarProceso: alEmpezarProceso,
        ),
      ),
    ).whenComplete(() {
      if (!esperandoFoto && !resultado.isCompleted) {
        resultado.complete(null);
      }
    });

    return resultado.future;
  }

  static Future<Uint8List?> _tomarRecortar(
    BuildContext context, {
    required ImageSource source,
    required String cropTitle,
    required CropAspectRatio aspectRatio,
    required CropAspectRatioPreset androidPreset,
    required int imageQuality,
    required int compressQuality,
    required int maxWidth,
    required int maxHeight,
    required VoidCallback alEmpezarProceso,
  }) async {
    final XFile? seleccion;
    try {
      // En la web no redimensiona aquí: el navegador a veces deja la foto
      // de la cámara en un formato que el recorte no abre. Se normaliza abajo.
      seleccion = await _picker.pickImage(
        source: source,
        maxWidth: kIsWeb ? null : 1600,
        maxHeight: kIsWeb ? null : 1600,
        imageQuality: kIsWeb ? null : imageQuality,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (e) {
      debugPrint('$e');
      if (!context.mounted) return null;
      _aviso(
        context,
        source == ImageSource.camera
            ? 'No se pudo abrir la cámara. Permite el acceso e inténtalo de nuevo.'
            : 'No se pudieron abrir las fotos. Inténtalo de nuevo.',
      );
      return null;
    }
    if (seleccion == null) return null;

    alEmpezarProceso();
    var ruta = seleccion.path;
    try {
      ruta = await prepararImagenParaRecorte(
        seleccion.path,
        calidad: imageQuality,
      );
      if (!context.mounted) return XFile(ruta).readAsBytes();

      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: ruta,
        aspectRatio: aspectRatio,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: compressQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        uiSettings: cropUiSettings(
          context,
          title: cropTitle,
          androidPreset: androidPreset,
        ),
      );
      if (cropped == null) return null;
      final bytes = await cropped.readAsBytes();
      if (!context.mounted) return bytes.isEmpty ? null : bytes;
      if (bytes.isEmpty) {
        _aviso(context, 'La foto salió vacía. Tómala de nuevo.');
        return null;
      }
      return bytes;
    } catch (e) {
      debugPrint('$e');
      if (context.mounted) {
        _aviso(context, 'No se pudo recortar. Se usó la foto completa.');
      }
      try {
        final bytes = await XFile(ruta).readAsBytes();
        return bytes.isEmpty ? null : bytes;
      } catch (lectura) {
        debugPrint('$lectura');
        if (context.mounted) {
          _aviso(context, 'No se pudo leer la foto. Tómala de nuevo.');
        }
        return null;
      }
    }
  }

  static void _aviso(BuildContext context, String mensaje) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.orange.shade800,
      ),
    );
  }
}

CropperSize _tamanoRecorteWeb(BuildContext context) {
  final lado = _ladoRecorte(MediaQuery.sizeOf(context));
  return CropperSize(width: lado.round(), height: lado.round());
}

/// Lado del visor para que título, foto y botón Recortar quepan en la ventana.
double _ladoRecorte(Size pantalla) {
  final ancho = math.min(pantalla.width - 96, 480.0);
  final alto = pantalla.height - 280;
  return math.min(ancho, alto).clamp(160.0, 420.0);
}

class _DialogoRecorte extends StatefulWidget {
  const _DialogoRecorte({
    required this.titulo,
    required this.cropper,
    required this.initCropper,
    required this.crop,
    required this.rotate,
    required this.scale,
  });

  final String titulo;
  final Widget cropper;
  final void Function() initCropper;
  final Future<String?> Function() crop;
  final void Function(RotationAngle) rotate;
  final void Function(num) scale;

  @override
  State<_DialogoRecorte> createState() => _DialogoRecorteState();
}

class _DialogoRecorteState extends State<_DialogoRecorte> {
  bool _procesando = false;
  bool _listo = false;
  double _escala = 1;

  @override
  void initState() {
    super.initState();
    widget.initCropper();
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _listo = true);
    });
  }

  Future<void> _recortar() async {
    if (_procesando) return;
    setState(() => _procesando = true);
    try {
      final resultado = await widget.crop();
      if (!mounted) return;
      Navigator.of(context).pop(resultado);
    } catch (e) {
      debugPrint('$e');
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final altoVentana = media.size.height - media.padding.vertical - media.viewInsets.vertical;
    final anchoVentana = media.size.width - media.padding.horizontal;
    final reserva = altoVentana < 640 ? 210.0 : 260.0;
    final lado = math.min(anchoVentana - 56, altoVentana - reserva).clamp(140.0, 420.0);
    final anchoDialogo = math.min(anchoVentana - 24, lado + 40);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: anchoDialogo, maxHeight: altoVentana - 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.titulo,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Arrastra la foto y pellizca para acercarla.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SizedBox(
                  width: lado,
                  height: lado,
                  child: ClipRect(child: widget.cropper),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Girar a la izquierda',
                      onPressed: () => widget.rotate(RotationAngle.counterClockwise90),
                      icon: const Icon(Icons.rotate_90_degrees_ccw_rounded),
                    ),
                    Expanded(
                      child: Slider(
                        value: _escala,
                        min: 1,
                        max: 3,
                        label: _escala.toStringAsFixed(1),
                        onChanged: (value) {
                          setState(() => _escala = value);
                          widget.scale(value);
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Girar a la derecha',
                      onPressed: () => widget.rotate(RotationAngle.clockwise90),
                      icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                  TextButton(
                    onPressed: _procesando ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: (!_listo || _procesando) ? null : _recortar,
                    child: !_listo || _procesando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Usar foto'),
                  ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HojaFoto extends StatefulWidget {
  const _HojaFoto({
    required this.mostrarCamara,
    required this.galleryLabel,
    required this.cameraLabel,
    required this.alPulsar,
    required this.alQuedarEnHoja,
    required this.alTerminar,
    required this.procesar,
  });

  final bool mostrarCamara;
  final String galleryLabel;
  final String cameraLabel;
  final VoidCallback alPulsar;
  final VoidCallback alQuedarEnHoja;
  final ValueChanged<Uint8List?> alTerminar;
  final Future<Uint8List?> Function(ImageSource source, VoidCallback alEmpezarProceso) procesar;

  @override
  State<_HojaFoto> createState() => _HojaFotoState();
}

class _HojaFotoState extends State<_HojaFoto> {
  bool _preparando = false;
  int _intento = 0;

  Future<void> _elegir(ImageSource source) async {
    if (_preparando) return;
    final intento = ++_intento;
    widget.alPulsar();
    final bytes = await widget.procesar(source, () {
      if (mounted && intento == _intento) setState(() => _preparando = true);
    });
    if (intento != _intento) return;
    if (bytes == null) {
      widget.alQuedarEnHoja();
      if (mounted && _preparando) setState(() => _preparando = false);
      return;
    }
    widget.alTerminar(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_preparando,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _preparando
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Preparando la foto…'),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Agregar foto',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.mostrarCamara
                          ? 'Tómala ahora o elige una que ya tengas.'
                          : 'Elige una foto de tu equipo.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    if (widget.mostrarCamara) ...[
                      FilledButton.icon(
                        onPressed: () => _elegir(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(widget.cameraLabel),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => _elegir(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(widget.galleryLabel),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Icono y texto del recuadro vacío de una foto.
class FotoVacia extends StatelessWidget {
  const FotoVacia({super.key, this.icono = Icons.add_a_photo, this.color});

  final IconData icono;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icono, size: 50, color: color ?? Colors.grey),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            MobileImageUtils.camaraDisponible
                ? 'Tocar para tomar o elegir foto'
                : 'Tocar para agregar foto',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
