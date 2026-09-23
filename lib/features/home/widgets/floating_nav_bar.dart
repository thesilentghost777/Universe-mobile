import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/universe_ui.dart';

class NavItem {
  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge = 0,
    this.prominent = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Pastille de compteur (0 = aucune).
  final int badge;

  /// Onglet central mis en avant (bouton surélevé, dégradé de marque) —
  /// réservé au Tuteur, pour qui UniTube reste un onglet à part (§5.2).
  final bool prominent;
}

/// Barre du bas flottante — détachée du bord de l'écran, posée sur le contenu.
///
/// Les notes demandaient qu'elle « ressorte » au lieu d'être collée en bas :
/// d'où la marge, le coin très arrondi et l'ombre portée.
///
/// Hauteur totale à réserver sous le contenu : [reservedHeight].
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const double _barHeight = 64;
  static const double _bottomMargin = 12;

  /// Hauteur du bandeau. À l'échelle 1 elle reste 64 ; au-dessus, le libellé
  /// (Grande, Très grande, ou police du téléphone) a de la place.
  ///
  /// [facteur] sert quand l'appelant calcule la réserve *avant* d'appliquer
  /// un grossissement (l'interface enseignant multiplie par 1,12).
  static double barHeight(BuildContext context, {double facteur = 1}) {
    final echelle = (MediaQuery.textScalerOf(context).scale(1) * facteur)
        .clamp(1.0, 2.4);
    return _barHeight + 28 * (echelle - 1);
  }

  /// Marge basse à appliquer au contenu pour qu'il ne passe pas sous la barre.
  static double reservedHeight(BuildContext context, {double facteur = 1}) =>
      barHeight(context, facteur: facteur) +
      _bottomMargin +
      MediaQuery.paddingOf(context).bottom +
      12;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, _bottomMargin + safeBottom),
      child: Container(
        height: barHeight(context),
        decoration: BoxDecoration(
          color: t.floatingBar,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(
              color: t.shadow,
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: items[i].prominent
                    ? _ProminentNavButton(
                        item: items[i],
                        selected: i == currentIndex,
                        onTap: () => onSelect(i),
                      )
                    : _NavButton(
                        item: items[i],
                        selected: i == currentIndex,
                        onTap: () => onSelect(i),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Onglet central surélevé, façon bouton d'action — UniTube pour le Tuteur.
class _ProminentNavButton extends StatelessWidget {
  const _ProminentNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Transform.translate(
          offset: const Offset(0, -14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: UniverseColors.brandGradient,
                  boxShadow: [
                    BoxShadow(
                      color: UniverseColors.violet.withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 2),
              UniverseFitLabel(
                item.label,
                alignment: Alignment.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? UniverseColors.blue
                      : context.tokens.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: selected
                    ? UniverseColors.blue.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  selected
                      ? ShaderMask(
                          shaderCallback: (rect) => UniverseColors
                              .brandGradient
                              .createShader(rect),
                          child: Icon(item.activeIcon,
                              size: 22, color: Colors.white),
                        )
                      : Icon(item.icon, size: 22, color: t.textMuted),
                  if (item.badge > 0)
                    Positioned(
                      right: -7,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(minWidth: 15),
                        height: 15,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: UniverseColors.danger,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: t.floatingBar, width: 1.5),
                        ),
                        child: Text(
                          item.badge > 9 ? '9+' : '${item.badge}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: UniverseFitLabel(
                item.label,
                alignment: Alignment.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? UniverseColors.blue : t.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
