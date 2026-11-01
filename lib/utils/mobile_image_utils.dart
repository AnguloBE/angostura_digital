import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Utilidades para elegir, recortar y leer imágenes en Android/iOS (y web si aplica).
class MobileImageUtils {
  static final ImagePicker _picker = ImagePicker();

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
          translations: const WebTranslations(
            title: 'Recortar foto',
            rotateLeftTooltip: 'Girar a la izquierda',
            rotateRightTooltip: 'Girar a la derecha',
            cancelButton: 'Cancelar',
            cropButton: 'Recortar',
          ),
          customDialogBuilder: (cropper, initCropper, crop, rotate, scale) {
            return _DialogoRecorte(
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

  static Future<void> showImageSourcePicker(
    BuildContext context, {
    required ValueChanged<ImageSource> onSelected,
    String galleryLabel = 'Elegir de la galería',
    String cameraLabel = 'Tomar foto con la cámara',
  }) {
    return showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(galleryLabel),
              onTap: () {
                Navigator.pop(sheetContext);
                onSelected(ImageSource.gallery);
              },
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(cameraLabel),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onSelected(ImageSource.camera);
                },
              ),
          ],
        ),
      ),
    );
  }

  static Future<Uint8List?> pickCropAndReadBytes({
    required BuildContext context,
    required ImageSource source,
    required String cropTitle,
    CropAspectRatio aspectRatio = const CropAspectRatio(ratioX: 1, ratioY: 1),
    CropAspectRatioPreset androidPreset = CropAspectRatioPreset.square,
    int imageQuality = 70,
    int compressQuality = 50,
    int maxWidth = 600,
    int maxHeight = 600,
  }) async {
    final XFile? seleccion = await _picker.pickImage(
      source: source,
      imageQuality: imageQuality,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (seleccion == null) return null;
    if (!context.mounted) return null;

    final CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: seleccion.path,
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
    return cropped.readAsBytes();
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
    required this.cropper,
    required this.initCropper,
    required this.crop,
    required this.rotate,
    required this.scale,
  });

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
  double _escala = 1;

  @override
  void initState() {
    super.initState();
    widget.initCropper();
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
    final pantalla = MediaQuery.sizeOf(context);
    final lado = _ladoRecorte(pantalla);
    final anchoDialogo = math.min(pantalla.width - 48, lado + 48);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: anchoDialogo,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recortar foto',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                    onPressed: _procesando ? null : _recortar,
                    child: _procesando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Recortar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
