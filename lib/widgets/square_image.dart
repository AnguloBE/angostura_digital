import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Imagen siempre en contenedor cuadrado (1:1), con [BoxFit.cover].
class SquareImage extends StatelessWidget {
  const SquareImage({
    super.key,
    this.imageUrl,
    this.imageBytes,
    this.size,
    this.borderRadius = BorderRadius.zero,
    this.placeholder,
    this.color,
    this.colorBlendMode,
    this.useCachedNetwork = false,
  });

  final String? imageUrl;
  final Uint8List? imageBytes;
  /// Si se define, cuadrado fijo (ej. 70). Si es null, ocupa el ancho disponible.
  final double? size;
  final BorderRadius borderRadius;
  final Widget? placeholder;
  final Color? color;
  final BlendMode? colorBlendMode;
  final bool useCachedNetwork;

  bool get _hasImage =>
      imageBytes != null || (imageUrl != null && imageUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final Widget child = _hasImage ? _buildImage() : _buildPlaceholder();

    final clipped = ClipRRect(borderRadius: borderRadius, child: child);

    if (size != null) {
      return SizedBox(width: size, height: size, child: clipped);
    }
    return AspectRatio(aspectRatio: 1, child: clipped);
  }

  Widget _buildPlaceholder() {
    return placeholder ??
        Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const Icon(Icons.image, color: Colors.grey, size: 40),
        );
  }

  Widget _buildImage() {
    if (imageBytes != null) {
      return Image.memory(
        imageBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        color: color,
        colorBlendMode: colorBlendMode,
      );
    }

    final url = imageUrl!;
    if (useCachedNetwork) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        color: color,
        colorBlendMode: colorBlendMode,
        placeholder: (_, __) => Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) => _buildPlaceholder(),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      color: color,
      colorBlendMode: colorBlendMode,
      errorBuilder: (_, __, ___) => _buildPlaceholder(),
    );
  }
}

/// Área cuadrada para elegir / previsualizar foto (agregar producto, promoción, etc.).
class SquarePhotoPicker extends StatelessWidget {
  const SquarePhotoPicker({
    super.key,
    this.imageBytes,
    this.imageUrl,
    required this.emptyChild,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.borderColor,
    this.backgroundColor,
  });

  final Uint8List? imageBytes;
  final String? imageUrl;
  final Widget emptyChild;
  final BorderRadius borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;

  bool get _hasImage =>
      imageBytes != null || (imageUrl != null && imageUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.grey.shade200,
          borderRadius: borderRadius,
          border: Border.all(color: borderColor ?? Colors.grey.shade400),
        ),
        clipBehavior: Clip.antiAlias,
        child: _hasImage
            ? SquareImage(
                imageBytes: imageBytes,
                imageUrl: imageUrl,
                borderRadius: borderRadius,
              )
            : emptyChild,
      ),
    );
  }
}
