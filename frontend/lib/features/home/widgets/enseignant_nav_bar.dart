import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/universe_ui.dart';
import 'floating_nav_bar.dart';

/// Barre de navigation dédiée à l'Enseignant (§6) : interface volontairement
/// séparée de [FloatingNavBar], pensée pour un public plus âgé —
/// zones tactiles plus grandes, libellé TOUJOURS visible et de plus grande
/// taille, contraste fort sur l'onglet actif, pas de bulle flottante ni de
/// geste caché.
class EnseignantNavBar extends StatelessWidget {
  const EnseignantNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const double _barHeight = 86;

  /// Même logique que [FloatingNavBar.barHeight] : la barre grandit avec
  /// la police pour que le libellé reste entier.
  static double barHeight(BuildContext context, {double facteur = 1}) {
    final echelle = (MediaQuery.textScalerOf(context).scale(1) * facteur)
        .clamp(1.0, 2.4);
    return _barHeight + 32 * (echelle - 1);
  }

  static double reservedHeight(BuildContext context, {double facteur = 1}) =>
      barHeight(context, facteur: facteur) +
      MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: reservedHeight(context),
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom,
        top: 10,
        left: 8,
        right: 8,
      ),
      decoration: BoxDecoration(
        color: t.floatingBar,
        border: Border(top: BorderSide(color: t.border, width: 1.4)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _EnseignantTab(
                item: items[i],
                selected: i == currentIndex,
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _EnseignantTab extends StatelessWidget {
  const _EnseignantTab({
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? UniverseColors.violet.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: selected
                ? Border.all(color: UniverseColors.violet, width: 1.6)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.activeIcon : item.icon,
                size: 28,
                color: selected ? UniverseColors.violet : t.textMuted,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: UniverseFitLabel(
                  item.label,
                  alignment: Alignment.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? UniverseColors.violet : t.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
