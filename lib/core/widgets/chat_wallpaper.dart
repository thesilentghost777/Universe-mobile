import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Fond de discussion façon WhatsApp (§ retour utilisateur) : avant, les
/// conversations n'avaient aucun fond propre — juste la couleur de fond
/// générique de l'app, ce qui donnait une impression de coquille vide.
///
/// Motif de points très discret + un léger halo de couleur en haut, statique
/// (pas d'animation) pour ne jamais gêner la lecture des bulles qui défilent
/// par-dessus.
class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key, required this.child, this.accentColor});

  final Widget child;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = accentColor ?? UniverseColors.blue;
    final motif = accent.withValues(alpha: context.isDark ? 0.07 : 0.05);
    final halo = accent.withValues(alpha: context.isDark ? 0.14 : 0.08);

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: t.canvas),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.3,
                colors: [halo, Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _MotifPointille(couleur: motif)),
        ),
        child,
      ],
    );
  }
}

class _MotifPointille extends CustomPainter {
  const _MotifPointille({required this.couleur});

  final Color couleur;

  static const double _espacement = 30;
  static const double _rayon = 1.4;

  @override
  void paint(Canvas canvas, Size size) {
    final peinture = Paint()..color = couleur;
    var ligne = 0;
    for (double y = 8; y < size.height; y += _espacement) {
      final decalage = ligne.isOdd ? _espacement / 2 : 0.0;
      for (double x = decalage; x < size.width; x += _espacement) {
        canvas.drawCircle(Offset(x, y), _rayon, peinture);
      }
      ligne++;
    }
  }

  @override
  bool shouldRepaint(covariant _MotifPointille oldDelegate) =>
      oldDelegate.couleur != couleur;
}
