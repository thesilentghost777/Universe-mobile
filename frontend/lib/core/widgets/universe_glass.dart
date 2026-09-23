import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../i18n/locale_controller.dart';

/// Briques « verre + bento » — direction visuelle demandée en complément de
/// [universe_ui.dart] : surfaces en verre dépoli, fond en dégradé animé,
/// boutons qui réagissent au toucher. Extraites de
/// `features/auth/widgets/auth_scaffold.dart` (déjà dans ce langage) pour
/// être réutilisables partout, pas seulement sur les écrans d'authentification.

/// Panneau en verre dépoli : fond translucide teinté, bordure et ombre dans
/// la couleur d'accent. Le flou (`BackdropFilter`) est **optionnel** et
/// coûte cher sur Flutter web — ne le demander que pour les un ou deux blocs
/// hero d'un écran, jamais pour une grille de tuiles.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.accentColor,
    this.blurred = false,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final Color? accentColor;
  final bool blurred;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = accentColor ?? UniverseColors.blue;
    final radius = BorderRadius.circular(borderRadius);

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: t.surface.withValues(alpha: context.isDark ? 0.55 : 0.78),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: context.isDark ? 0.16 : 0.10),
            Colors.transparent,
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );

    if (blurred) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: content,
      );
    }

    return ClipRRect(borderRadius: radius, child: content);
  }
}

/// Fond en dégradé qui dérive lentement — la moitié « gradients animés » du
/// mélange demandé. Pas de flou : deux halos radiaux qui tournent doucement
/// derrière le contenu, coût quasi nul.
class AuraBackground extends StatefulWidget {
  const AuraBackground({super.key, required this.child, this.colors});

  final Widget child;

  /// Couleurs des deux halos. Par défaut le dégradé de marque bleu→violet.
  final List<Color>? colors;

  @override
  State<AuraBackground> createState() => _AuraBackgroundState();
}

class _AuraBackgroundState extends State<AuraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final palette =
        widget.colors ?? [UniverseColors.blue, UniverseColors.violet];
    final c2 = palette.length > 1 ? palette[1] : palette[0];

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: t.canvas),
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final a = _c.value * 2 * math.pi;
            return Stack(
              children: [
                Positioned(
                  top: -90 + 30 * math.sin(a),
                  left: -70 + 50 * math.cos(a),
                  child: _Blob(color: palette.first, size: 260),
                ),
                Positioned(
                  bottom: -110 + 40 * math.cos(a * 0.8),
                  right: -60 + 40 * math.sin(a * 0.8),
                  child: _Blob(color: c2, size: 300),
                ),
              ],
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Le bouton « réactif » demandé : léger zoom arrière au clic, léger zoom
/// avant au survol (souris web/desktop). N'importe quel contenu tappable
/// peut s'en envelopper — c'est la seule brique de micro-interaction.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  bool _hovered = false;

  bool get _interactive => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: _interactive,
      enabled: _interactive,
      child: MouseRegion(
        cursor: _interactive ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) {
          if (_interactive) setState(() => _hovered = true);
        },
        onExit: (_) {
          if (_interactive) setState(() => _hovered = false);
        },
        child: GestureDetector(
          onTapDown: (_) {
            if (_interactive) setState(() => _pressed = true);
          },
          onTapUp: (_) {
            if (_interactive) setState(() => _pressed = false);
          },
          onTapCancel: () {
            if (_interactive) setState(() => _pressed = false);
          },
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.96 : (_hovered ? 1.02 : 1.0),
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Combien de colonnes une tuile occupe dans une grille bento à 2 colonnes.
enum BentoSpan { half, full }

/// Tuile de tableau de bord : icône, titre, sous-titre, en verre, réactive
/// au toucher. Remplace les lignes `Card`/`ListTile` uniformes par des blocs
/// de tailles variées — la moitié « bento grid » du mélange demandé.
class BentoTile extends StatelessWidget {
  const BentoTile({
    super.key,
    required this.icon,
    required this.titre,
    required this.sousTitre,
    this.onTap,
    this.accentColor,
    this.span = BentoSpan.half,
    this.lockedLabel,
  });

  final IconData icon;
  final String titre;
  final String sousTitre;
  final VoidCallback? onTap;
  final Color? accentColor;
  final BentoSpan span;

  /// Texte du badge affiché quand `onTap` est `null` — par défaut « À
  /// venir » ; une fonctionnalité verrouillée en attente d'une validation
  /// (ex. dossier Enseignant) veut un libellé plus précis.
  final String? lockedLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = accentColor ?? UniverseColors.blue;
    final disponible = onTap != null;

    final icone = Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.18),
      ),
      child: Icon(icon, color: accent, size: 19),
    );

    final textes = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titre,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        const SizedBox(height: 3),
        Text(
          sousTitre,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: t.textMuted, height: 1.3),
        ),
        if (!disponible) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: t.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.border),
            ),
            child: Text(
              lockedLabel ?? tr(context, 'À venir'),
              softWrap: true,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: t.textMuted,
              ),
            ),
          ),
        ],
      ],
    );

    final contenu = span == BentoSpan.full
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icone,
              const SizedBox(width: 12),
              Expanded(child: textes),
              if (disponible || lockedLabel != null) ...[
                const SizedBox(width: 8),
                Icon(
                  disponible ? Icons.chevron_right_rounded : Icons.lock_outline_rounded,
                  size: 18,
                  color: t.textMuted,
                ),
              ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icone,
              const SizedBox(height: 12),
              textes,
            ],
          );

    return Pressable(
      onTap: onTap,
      child: GlassSurface(
        accentColor: accent,
        padding: const EdgeInsets.all(14),
        child: contenu,
      ),
    );
  }
}
