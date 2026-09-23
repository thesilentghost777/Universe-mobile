import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/widgets/universe_glass.dart';
import '../../core/widgets/universe_ui.dart';

/// Carte de section réutilisée par toutes les pages de Paramètres :
/// en-tête clair + contenu groupé en verre.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.titre, required this.enfants});

  final String titre;
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) {
    if (enfants.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(titre, padding: const EdgeInsets.only(bottom: 8, left: 2)),
        GlassSurface(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: enfants),
        ),
      ],
    );
  }
}

/// Une ligne de réglage — icône, titre, sous-titre, chevron ou action.
class SettingsLigne extends StatelessWidget {
  const SettingsLigne({
    super.key,
    required this.icon,
    required this.titre,
    this.sousTitre,
    this.onTap,
    this.trailing,
    this.iconColor,
    this.iconSize = 20,
  });

  final IconData icon;
  final String titre;
  final String? sousTitre;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final echelle = MediaQuery.textScalerOf(context).scale(1);
    return ListTile(
      leading: Icon(icon, size: iconSize, color: iconColor ?? t.textMuted),
      title: Text(
        titre,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: sousTitre == null
          ? null
          : Text(
              sousTitre!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: t.textMuted),
            ),
      // `dense` serre la ligne : à Grande / Très grande le titre et le
      // sous-titre n'ont plus la place et débordent.
      dense: echelle < 1.05,
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right_rounded, color: t.textMuted, size: 20)
              : null),
      onTap: onTap,
    );
  }
}

/// Grande tuile de catégorie sur le nouvel écran d'accueil des Paramètres.
class SettingsCategoryTile extends StatelessWidget {
  const SettingsCategoryTile({
    super.key,
    required this.icon,
    required this.titre,
    required this.sousTitre,
    required this.couleur,
    required this.onTap,
    this.pleineLargeur = false,
  });

  final IconData icon;
  final String titre;
  final String sousTitre;
  final Color couleur;
  final VoidCallback onTap;
  final bool pleineLargeur;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return LayoutBuilder(
      builder: (context, c) {
        // En pleine largeur (ou dès que la tuile a la place), le texte
        // s'aligne à côté de l'icône. En demi-tuile, l'icône reste au-dessus.
        final ligne = pleineLargeur || c.maxWidth >= 240;
        return Material(
          color: t.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.border),
              ),
              child: ligne
                  ? Row(
                      children: [
                        _icone(couleur),
                        const SizedBox(width: 12),
                        Expanded(child: _textes(t)),
                        Icon(Icons.chevron_right_rounded, color: t.textMuted),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _icone(couleur),
                        const SizedBox(height: 12),
                        _textes(t),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _icone(Color couleur) => Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: couleur.withValues(alpha: 0.16),
        ),
        child: Icon(icon, color: couleur, size: 19),
      );

  Widget _textes(UniverseTokens t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(titre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 2),
          Text(
            sousTitre,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: t.textMuted, height: 1.3),
          ),
        ],
      );
}
