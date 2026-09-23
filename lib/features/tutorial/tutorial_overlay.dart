import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import 'role_tutorial_steps.dart';
import 'tutorial_service.dart';

/// Lance le tutoriel guidé (§9) au-dessus de tout le reste de l'app, et
/// marque le rôle comme vu à la fin (sauf si l'utilisateur ferme en cours
/// de route — il le reverra alors au prochain lancement).
Future<void> demarrerTutoriel(
  BuildContext context, {
  required List<EtapeTutoriel> etapes,
  required String userId,
  required String rang,
  bool lent = false,
  void Function(OngletTutoriel)? onChangerOnglet,
}) async {
  if (etapes.isEmpty) return;
  // Bascule déjà sur l'onglet de la toute première étape avant même
  // d'afficher le voile, pour ne pas montrer un flash de l'ancien onglet.
  if (etapes.first.onglet != null) onChangerOnglet?.call(etapes.first.onglet!);
  await Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, anim, _) => FadeTransition(
        opacity: anim,
        child: _TutorialOverlay(
          etapes: etapes,
          lent: lent,
          onChangerOnglet: onChangerOnglet,
        ),
      ),
    ),
  );
  await const TutorialService().marquerVu(userId, rang);
}

class _TutorialOverlay extends StatefulWidget {
  const _TutorialOverlay({
    required this.etapes,
    required this.lent,
    this.onChangerOnglet,
  });

  final List<EtapeTutoriel> etapes;
  final bool lent;
  final void Function(OngletTutoriel)? onChangerOnglet;

  @override
  State<_TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<_TutorialOverlay> {
  int _index = 0;
  bool _termine = false;

  void _suivant() {
    HapticFeedback.selectionClick();
    if (_index >= widget.etapes.length - 1) {
      setState(() => _termine = true);
    } else {
      setState(() => _index++);
      // Le fond réel (AppShell, non opaque sous ce voile) bascule d'onglet
      // en même temps que la carte — le spotlight éclaire ainsi la vraie
      // interface plutôt qu'une simple description abstraite.
      final onglet = widget.etapes[_index].onglet;
      if (onglet != null) widget.onChangerOnglet?.call(onglet);
    }
  }

  void _passer() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    if (_termine) {
      return _EcranFinal(onFermer: () => Navigator.of(context).pop());
    }

    final etape = widget.etapes[_index];
    final dernier = _index == widget.etapes.length - 1;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<double>(
              key: ValueKey('spot-$_index'),
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: widget.lent ? 500 : 320),
              curve: Curves.easeOutCubic,
              builder: (context, t, __) => CustomPaint(
                painter: _SpotlightPainter(
                  direction: etape.pointeur,
                  progression: t,
                  // Une étape qui bascule sur un onglet parle de l'écran
                  // entier (les étagères, le fil de vidéos…) : un voile
                  // sombre qui ne découpe qu'un bord laisserait l'essentiel
                  // masqué et donnerait l'impression que rien ne s'affiche.
                  pleineVue: etape.onglet != null,
                ),
                size: Size.infinite,
              ),
            ),
            if (etape.pointeur != PointeurDirection.aucun)
              _MainAnimee(direction: etape.pointeur, lent: widget.lent),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: _Carte(
                  etape: etape,
                  index: _index,
                  total: widget.etapes.length,
                  dernier: dernier,
                  lent: widget.lent,
                  onSuivant: _suivant,
                  onPasser: _passer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Assombrit tout l'écran sauf une zone approximative (façon spotlight) —
/// bien plus lisible qu'un simple voile uniforme pour montrer *où* regarder.
/// Sans mesure réelle du widget ciblé, la zone est une estimation généreuse
/// du bord concerné (rail à gauche, barre du bas, bouton IA à droite…),
/// assez large pour rester honnête même si la mise en page varie un peu.
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.direction,
    required this.progression,
    this.pleineVue = false,
  });

  final PointeurDirection direction;
  final double progression;

  /// `true` quand l'étape présente un onglet entier plutôt qu'un bouton
  /// précis — le voile reste très léger et laisse tout le contenu réel
  /// visible, au lieu de ne découper qu'un bord de l'écran.
  final bool pleineVue;

  @override
  void paint(Canvas canvas, Size size) {
    if (pleineVue) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: 0.16 * progression),
      );
      return;
    }

    final voile = Paint()..color = Colors.black.withValues(alpha: 0.74);

    if (direction == PointeurDirection.aucun) {
      canvas.drawRect(Offset.zero & size, voile);
      return;
    }

    final Rect zone = switch (direction) {
      PointeurDirection.gauche =>
        Rect.fromLTWH(-40, 0, size.width * 0.22 + 40, size.height),
      PointeurDirection.droite => Rect.fromCircle(
          center: Offset(size.width - 44, size.height - 210),
          radius: 76,
        ),
      PointeurDirection.bas =>
        Rect.fromLTWH(0, size.height - 128, size.width, 128 + 40),
      PointeurDirection.haut => Rect.fromLTWH(0, -20, size.width, 140),
      PointeurDirection.aucun => Rect.zero,
    };

    final rrect = RRect.fromRectAndRadius(
      zone,
      const Radius.circular(28),
    );

    final chemin = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, voile);
    canvas.drawPath(
      chemin,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..color = Colors.black.withValues(alpha: progression),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.direction != direction ||
      oldDelegate.progression != progression ||
      oldDelegate.pleineVue != pleineVue;
}

class _Carte extends StatelessWidget {
  const _Carte({
    required this.etape,
    required this.index,
    required this.total,
    required this.dernier,
    required this.lent,
    required this.onSuivant,
    required this.onPasser,
  });

  final EtapeTutoriel etape;
  final int index;
  final int total;
  final bool dernier;
  final bool lent;
  final VoidCallback onSuivant;
  final VoidCallback onPasser;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(index),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: lent ? 420 : 260),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: Transform.scale(
            scale: 0.97 + 0.03 * t,
            child: child,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barre de progression fine + compteur, plus lisible que de
            // simples puces pour se situer dans un parcours plus long.
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: (index + 1) / total),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      builder: (context, valeur, _) => LinearProgressIndicator(
                        value: valeur,
                        minHeight: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation(
                          UniverseColors.blue,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${index + 1}/$total',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: UniverseColors.brandGradient,
                  ),
                  child: Icon(etape.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    etape.titre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              etape.texte,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (!dernier)
                  TextButton(
                    onPressed: onPasser,
                    child: Text(
                      'Passer',
                      style:
                          TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: onSuivant,
                  style: FilledButton.styleFrom(
                    backgroundColor: UniverseColors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child: Text(dernier ? 'Terminer' : 'Suivant'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Petite main qui pointe vers le bord de l'écran concerné, avec un
/// battement doux pour attirer l'œil sans être agressive.
class _MainAnimee extends StatefulWidget {
  const _MainAnimee({required this.direction, required this.lent});

  final PointeurDirection direction;
  final bool lent;

  @override
  State<_MainAnimee> createState() => _MainAnimeeState();
}

class _MainAnimeeState extends State<_MainAnimee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.lent ? 1400 : 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (alignment, icon, offsetAxis) = switch (widget.direction) {
      PointeurDirection.gauche => (
          Alignment.centerLeft,
          Icons.back_hand_rounded,
          true
        ),
      PointeurDirection.droite => (
          Alignment.centerRight,
          Icons.back_hand_rounded,
          true
        ),
      PointeurDirection.haut => (
          Alignment.topCenter,
          Icons.back_hand_rounded,
          false
        ),
      PointeurDirection.bas => (
          Alignment.bottomCenter,
          Icons.back_hand_rounded,
          false
        ),
      PointeurDirection.aucun => (
          Alignment.center,
          Icons.back_hand_rounded,
          false
        ),
    };

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final d = 6 * _c.value;
            final offset = offsetAxis ? Offset(d, 0) : Offset(0, d);
            return Transform.translate(offset: offset, child: child);
          },
          child:
              Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 36),
        ),
      ),
    );
  }
}

/// Écran de fin, façon petite célébration — marque vraiment la fin du
/// parcours au lieu de juste disparaître d'un coup.
class _EcranFinal extends StatefulWidget {
  const _EcranFinal({required this.onFermer});

  final VoidCallback onFermer;

  @override
  State<_EcranFinal> createState() => _EcranFinalState();
}

class _EcranFinalState extends State<_EcranFinal> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) widget.onFermer();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.82),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onFermer,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _Confetti(),
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.elasticOut,
                builder: (context, t, child) => Transform.scale(
                  scale: t.clamp(0, 1.2),
                  child: child,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: UniverseColors.brandGradient,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 44),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Tu es prêt !',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Amuse-toi bien sur UniVerse.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Petite pluie de confettis, en Dart pur — pas de dépendance externe pour
/// un effet ponctuel de moins de deux secondes.
class _Confetti extends StatefulWidget {
  const _Confetti();

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  late final List<_Particule> _particules = List.generate(26, (i) {
    final rnd = math.Random(i * 97);
    return _Particule(
      x: rnd.nextDouble(),
      retard: rnd.nextDouble() * 0.3,
      vitesse: 0.7 + rnd.nextDouble() * 0.5,
      derive: (rnd.nextDouble() - 0.5) * 0.3,
      couleur: [
        UniverseColors.blue,
        UniverseColors.violet,
        UniverseColors.teal,
        UniverseColors.amber,
      ][i % 4],
      taille: 6 + rnd.nextDouble() * 5,
      rotation: rnd.nextDouble() * math.pi,
    );
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        painter: _ConfettiPainter(particules: _particules, t: _c.value),
        size: Size.infinite,
      ),
    );
  }
}

class _Particule {
  _Particule({
    required this.x,
    required this.retard,
    required this.vitesse,
    required this.derive,
    required this.couleur,
    required this.taille,
    required this.rotation,
  });

  final double x;
  final double retard;
  final double vitesse;
  final double derive;
  final Color couleur;
  final double taille;
  final double rotation;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.particules, required this.t});

  final List<_Particule> particules;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particules) {
      final local = ((t - p.retard) / (1 - p.retard)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = local * p.vitesse * size.height * 1.1;
      final x = p.x * size.width + p.derive * size.width * local;
      final double opacite = 1 - (local > 0.75 ? (local - 0.75) / 0.25 : 0.0);

      final paint = Paint()
        ..color = p.couleur.withValues(alpha: opacite.clamp(0, 1).toDouble());
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + local * 6);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: p.taille, height: p.taille * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
