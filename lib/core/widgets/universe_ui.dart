import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show Uint8List;

import '../../app/theme.dart';
import 'universe_glass.dart';

/// Avatar unique pour toute l'app (§7.4) : photo si disponible, sinon
/// initiale sur fond de couleur. `localBytes` prend le pas sur `photoUrl` —
/// c'est l'aperçu immédiat d'une photo tout juste choisie, avant qu'un
/// endpoint d'upload existe côté back (voir `UserProfile.photoUrl`).
class UniverseAvatar extends StatelessWidget {
  const UniverseAvatar({
    super.key,
    required this.initiale,
    this.photoUrl,
    this.localBytes,
    this.radius = 22,
    this.backgroundColor,
  });

  final String initiale;
  final String? photoUrl;
  final Uint8List? localBytes;
  final double radius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? UniverseColors.blue;

    if (localBytes != null) {
      return CircleAvatar(radius: radius, backgroundImage: MemoryImage(localBytes!));
    }
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        backgroundImage: CachedNetworkImageProvider(photoUrl!),
      );
    }
    // Le texte doit rester lisible quel que soit le fond reçu — un fond
    // pâle (ex. `t.surfaceElevated` en mode clair) rendait l'initiale
    // blanche quasi invisible.
    final texteLisible = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : UniverseColors.navy;

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        // Une seule lettre même si l'appelant passe un nom complet.
        initiale.isNotEmpty ? initiale[0].toUpperCase() : '?',
        style: TextStyle(
          color: texteLisible,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}

/// Briques d'interface partagées par toute l'application.
///
/// Avant, chaque écran redéfinissait son propre libellé de section, son propre
/// bouton dégradé, son propre bandeau d'erreur. Résultat : cinq variantes
/// légèrement différentes du même composant. Tout est ici désormais, pour que
/// l'app se ressemble d'un écran à l'autre.

/// Petit titre de section en capitales espacées.
///
/// `UNE SECTION` — 11 px, gras, `letterSpacing` 1.1, couleur atténuée.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.texte, {super.key, this.padding});

  final String texte;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      texte.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: context.tokens.textMuted,
      ),
    );
    return padding == null ? child : Padding(padding: padding!, child: child);
  }
}

/// Ton d'un [UniverseBanner].
enum BannerTone { info, success, warning, danger }

/// Bandeau d'information / erreur / succès — même forme partout.
class UniverseBanner extends StatelessWidget {
  const UniverseBanner(
    this.message, {
    super.key,
    this.tone = BannerTone.info,
    this.action,
  });

  final String message;
  final BannerTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (couleur, icone) = switch (tone) {
      BannerTone.info => (UniverseColors.blue, Icons.info_outline_rounded),
      BannerTone.success =>
        (UniverseColors.success, Icons.check_circle_outline_rounded),
      BannerTone.warning =>
        (const Color(0xFFF59E0B), Icons.warning_amber_rounded),
      BannerTone.danger =>
        (UniverseColors.danger, Icons.error_outline_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur.withValues(alpha: 0.38)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: couleur, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: context.tokens.textPrimary.withValues(alpha: 0.9),
              ),
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

/// Bouton principal plein largeur, dégradé de marque, état de chargement.
class UniversePrimaryButton extends StatelessWidget {
  const UniversePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final actif = onPressed != null && !loading;
    return Opacity(
      opacity: actif ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: UniverseColors.brandGradient,
          boxShadow: actif
              ? [
                  BoxShadow(
                    color: UniverseColors.violet.withValues(alpha: 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Pressable(
          onTap: actif ? onPressed : null,
          child: SizedBox(
            height: height,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: UniverseIconLabel(
                        icon: icon,
                        label: label,
                        iconSize: 19,
                        gap: 8,
                        iconColor: Colors.white,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Texte qui se réduit pour rester dans son cadre au lieu de déborder
/// (police système agrandie, segments étroits, sigles).
class UniverseFitLabel extends StatelessWidget {
  const UniverseFitLabel(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.textAlign,
    this.alignment = Alignment.centerLeft,
  });

  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(
        text,
        maxLines: maxLines,
        softWrap: maxLines > 1,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}

/// Icône + libellé centrés, le texte se tasse si la rangée est trop étroite.
class UniverseIconLabel extends StatelessWidget {
  const UniverseIconLabel({
    super.key,
    this.icon,
    required this.label,
    this.iconSize = 15,
    this.gap = 4,
    this.iconColor,
    this.style,
  });

  final IconData? icon;
  final String label;
  final double iconSize;
  final double gap;
  final Color? iconColor;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: iconSize, color: iconColor),
          SizedBox(width: gap),
        ],
        Flexible(
          child: UniverseFitLabel(
            label,
            alignment: Alignment.center,
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
      ],
    );
  }
}

/// Rangée de choix (thème, taille du texte, visibilité…).
///
/// [SegmentedButton] déborde dès que les libellés ne tiennent plus sur la
/// largeur — téléphone étroit, ou police Grande / Très grande. Dans ce cas
/// les choix s'empilent, chacun sur toute la largeur, à la taille demandée.
class UniverseSegmentedRow extends StatelessWidget {
  const UniverseSegmentedRow({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
    this.icons,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<IconData>? icons;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (_tientSurUneLigne(context, c.maxWidth)) {
          return SegmentedButton<int>(
            segments: [
              for (var i = 0; i < labels.length; i++)
                ButtonSegment<int>(
                  value: i,
                  icon: _icone(i),
                  label: Text(labels[i]),
                ),
            ],
            selected: {selectedIndex},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onSelect(s.first),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _ChoixLarge(
                label: labels[i],
                icon: icons != null && i < icons!.length ? icons![i] : null,
                actif: i == selectedIndex,
                onTap: () => onSelect(i),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget? _icone(int i) {
    if (icons == null || i >= icons!.length) return null;
    return Icon(icons![i], size: 17);
  }

  bool _tientSurUneLigne(BuildContext context, double largeur) {
    if (!largeur.isFinite) return true;
    final scaler = MediaQuery.textScalerOf(context);
    final style = Theme.of(context).textTheme.labelLarge ??
        const TextStyle(fontSize: 14);
    var total = 0.0;
    for (var i = 0; i < labels.length; i++) {
      final painter = TextPainter(
        text: TextSpan(text: labels[i], style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final avecIcone = icons != null && i < icons!.length;
      total += painter.width + (avecIcone ? 56 : 40);
      painter.dispose();
    }
    return total <= largeur;
  }
}

class _ChoixLarge extends StatelessWidget {
  const _ChoixLarge({
    required this.label,
    required this.actif,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final teinte = actif ? UniverseColors.blue : t.textPrimary;
    return Material(
      color: actif
          ? UniverseColors.blue.withValues(alpha: 0.14)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: actif ? UniverseColors.blue : t.border,
              width: actif ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: teinte),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
                    color: teinte,
                  ),
                ),
              ),
              if (actif)
                const Icon(Icons.check_rounded, size: 18, color: UniverseColors.blue),
            ],
          ),
        ),
      ),
    );
  }
}

/// État vide standard : icône, titre, message, action optionnelle.
class UniverseEmptyState extends StatelessWidget {
  const UniverseEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: t.textMuted),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: t.textMuted, height: 1.4),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Poignée + titre d'une feuille modale (`showModalBottomSheet`).
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.titre, this.sousTitre});

  final String titre;
  final String? sousTitre;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 16),
            decoration: BoxDecoration(
              color: t.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Text(titre, style: Theme.of(context).textTheme.titleLarge),
        if (sousTitre != null) ...[
          const SizedBox(height: 6),
          Text(
            sousTitre!,
            style: TextStyle(fontSize: 13, color: t.textMuted, height: 1.35),
          ),
        ],
      ],
    );
  }
}
