/// Un canal, aplati depuis l'arbre Faculté → Filière → Niveau → Matière →
/// Canal, pour l'affichage dans le rail.
class CanalRailItem {
  const CanalRailItem({
    required this.id,
    required this.nom,
    required this.matiere,
    this.nombreNonLus = 0,
  });

  final String id;
  final String nom;
  final String matiere;
  final int nombreNonLus;

  /// Reconstruit la liste plate à partir de l'arbre JSON renvoyé par
  /// `/universites/:id/arbre`. `nombreNonLus` est un champ pressenti côté
  /// back (voir §5.1) — absent aujourd'hui, on retombe sur 0.
  static List<CanalRailItem> depuisArbre(Map<String, dynamic>? arbre) {
    if (arbre == null) return [];
    final items = <CanalRailItem>[];
    for (final f in (arbre['facultes'] as List? ?? [])) {
      for (final fil in ((f as Map)['filieres'] as List? ?? [])) {
        for (final n in ((fil as Map)['niveaux'] as List? ?? [])) {
          for (final m in ((n as Map)['matieres'] as List? ?? [])) {
            final nomMatiere = (m as Map)['nom'] as String? ?? '';
            for (final c in (m['canaux'] as List? ?? [])) {
              final canal = c as Map;
              items.add(CanalRailItem(
                id: canal['id'] as String,
                nom: canal['nom'] as String? ?? 'Canal',
                matiere: nomMatiere,
                nombreNonLus: canal['nombreNonLus'] as int? ?? 0,
              ));
            }
          }
        }
      }
    }
    return items;
  }
}
