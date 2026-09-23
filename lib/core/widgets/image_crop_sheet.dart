import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

import '../../app/theme.dart';
import '../i18n/locale_controller.dart';

/// Recadrage + compression d'une photo de profil (§7.4).
///
/// Pas de plugin natif (`image_cropper` demande une configuration Android/
/// iOS/web séparée) : l'utilisateur cadre une zone carrée par pan/zoom dans
/// un cadre fixe, on capture exactement ce qui est affiché
/// (`RenderRepaintBoundary.toImage`, fonctionne à l'identique sur web,
/// mobile et desktop), puis on réencode en JPEG compressé avec le package
/// pur Dart `image`. Retourne `null` si l'utilisateur annule.
Future<Uint8List?> ouvrirRecadrageImage(
  BuildContext context,
  Uint8List bytesOriginaux,
) {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ImageCropDialog(bytes: bytesOriginaux),
  );
}

class _ImageCropDialog extends StatefulWidget {
  const _ImageCropDialog({required this.bytes});

  final Uint8List bytes;

  @override
  State<_ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<_ImageCropDialog> {
  static const double _viewport = 260;

  /// Dimension finale (px) — largement suffisant pour un avatar, garde le
  /// fichier léger.
  static const int _tailleFinale = 512;

  final _boundaryKey = GlobalKey();
  final _transformController = TransformationController();
  bool _traitement = false;

  Future<void> _valider() async {
    setState(() => _traitement = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      // pixelRatio élevé pour garder une image nette malgré le petit cadre.
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = data!.buffer.asUint8List();

      // `compute` isole le décodage/réencodage sur mobile/desktop ; sur le
      // web (pas de vrais isolates) il s'exécute simplement en synchrone.
      final jpegBytes = await compute(_compresser, pngBytes);
      if (mounted) Navigator.of(context).pop(jpegBytes);
    } catch (_) {
      if (mounted) Navigator.of(context).pop(null);
    }
  }

  static Uint8List _compresser(Uint8List pngBytes) {
    final decoded = img.decodePng(pngBytes)!;
    final redimensionne = decoded.width > _tailleFinale
        ? img.copyResize(decoded, width: _tailleFinale)
        : decoded;
    return Uint8List.fromList(img.encodeJpg(redimensionne, quality: 85));
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Dialog(
      backgroundColor: t.surface,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(context, 'Recadrer la photo'),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr(context, 'Pince pour zoomer, glisse pour cadrer.'),
              style: TextStyle(fontSize: 12.5, color: t.textMuted),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: RepaintBoundary(
                key: _boundaryKey,
                child: SizedBox(
                  width: _viewport,
                  height: _viewport,
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 1,
                    maxScale: 4,
                    child: Image.memory(
                      widget.bytes,
                      fit: BoxFit.cover,
                      width: _viewport,
                      height: _viewport,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _traitement ? null : () => Navigator.of(context).pop(),
                    child: Text(tr(context, 'Annuler')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _traitement ? null : _valider,
                    child: _traitement
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(tr(context, 'Valider')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
