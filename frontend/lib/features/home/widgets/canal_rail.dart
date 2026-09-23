import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../core/widgets/universe_skeleton.dart';
import 'canal_rail_item.dart';

export 'canal_rail_item.dart';

/// Colonne des canaux d'une université (§5.1) — organisation type Discord,
/// à côté du rail des universités : icônes rondes, indicateur de messages
/// non lus, accès direct au canal au tap (pas besoin de passer par
/// l'arborescence complète). Compacte par défaut (bande d'icônes),
/// extensible par tap pour afficher les noms complets.
class CanalRail extends StatefulWidget {
  /// Largeur au repos. Le parent réserve cette place ; l'état étendu
  /// déborde par-dessus le contenu au lieu de le comprimer.
  static const double largeurCompacte = 72;

  const CanalRail({
    super.key,
    required this.loading,
    required this.canaux,
    required this.selectedId,
    required this.onSelect,
    required this.bottomInset,
  });

  final bool loading;
  final List<CanalRailItem> canaux;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  /// Hauteur à réserver sous la liste pour la barre de navigation du bas
  /// (variable selon le rôle) — évite qu'elle ne masque les derniers canaux.
  final double bottomInset;

  @override
  State<CanalRail> createState() => _CanalRailState();
}

class _CanalRailState extends State<CanalRail> {
  bool _etendu = false;

  static const double _largeurEtendue = 248;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (!widget.loading && widget.canaux.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: _etendu ? _largeurEtendue : CanalRail.largeurCompacte,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(right: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        right: false,
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Tooltip(
                message: _etendu
                    ? tr(context, 'Réduire les canaux')
                    : tr(context, 'Voir les noms des canaux'),
                child: InkWell(
                  onTap: () => setState(() => _etendu = !_etendu),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      _etendu ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                      color: t.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: widget.loading
                  ? const RailSkeleton()
                  : ListView.builder(
                      padding: EdgeInsets.only(top: 4, bottom: widget.bottomInset),
                      itemCount: widget.canaux.length,
                      itemBuilder: (context, i) {
                        final c = widget.canaux[i];
                        return _CanalRow(
                          canal: c,
                          selected: c.id == widget.selectedId,
                          etendu: _etendu,
                          onTap: () => widget.onSelect(c.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CanalRow extends StatelessWidget {
  const _CanalRow({
    required this.canal,
    required this.selected,
    required this.etendu,
    required this.onTap,
  });

  final CanalRailItem canal;
  final bool selected;
  final bool etendu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final initiale = canal.nom.trim().isNotEmpty ? canal.nom.trim()[0].toUpperCase() : '#';

    final rond = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: selected ? UniverseColors.brandGradient : null,
            color: selected ? null : t.surfaceElevated,
          ),
          child: Text(
            initiale,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : t.textMuted,
            ),
          ),
        ),
        if (canal.nombreNonLus > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              constraints: const BoxConstraints(minWidth: 17),
              height: 17,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: UniverseColors.danger,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: t.surface, width: 2),
              ),
              child: Text(
                canal.nombreNonLus > 99 ? '99+' : '${canal.nombreNonLus}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );

    return Tooltip(
      message: '${canal.matiere} · ${canal.nom}',
      child: Semantics(
        button: true,
        selected: selected,
        label: canal.nom,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                rond,
                if (etendu) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          canal.nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                            color: selected ? t.textPrimary : t.textMuted,
                          ),
                        ),
                        Text(
                          canal.matiere,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10.5, color: t.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
