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
    final XFile? seleccion =
        await _picker.pickImage(source: source, imageQuality: imageQuality);
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
