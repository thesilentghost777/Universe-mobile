import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/auth/role_access.dart';

/// D'où l'utilisateur publie/consulte ses vidéos — les trois rôles créateurs
/// partagent les mêmes écrans (publication, mes vidéos, abonnés), seuls
/// l'endpoint et quelques libellés changent.
enum CreatorSurface { tuteur, formateur, enseignant }

extension CreatorSurfaceX on CreatorSurface {
  static CreatorSurface depuis(Rang rang) => switch (rang) {
        Rang.tuteur => CreatorSurface.tuteur,
        Rang.enseignant => CreatorSurface.enseignant,
        _ => CreatorSurface.formateur,
      };

  Color get couleur => switch (this) {
        CreatorSurface.tuteur => const Color(0xFF0AA7F6),
        CreatorSurface.formateur => UniverseColors.blue,
        CreatorSurface.enseignant => UniverseColors.violet,
      };

  String get libelleEspace => switch (this) {
        CreatorSurface.tuteur => 'Mon groupe',
        CreatorSurface.formateur => 'Mon espace créateur',
        CreatorSurface.enseignant => 'Mon espace créateur',
      };

  /// Route de publication (§ retour utilisateur : une vraie page dédiée,
  /// plus un simple formulaire noyé dans le tableau de bord).
  String get routePublier =>
      this == CreatorSurface.tuteur ? '/app/groupe-tds/publier' : '/app/creator/publier';

  String get routeVideos =>
      this == CreatorSurface.tuteur ? '/app/groupe-tds' : '/app/creator/videos';

  String get routeAbonnes =>
      this == CreatorSurface.tuteur ? '/app/groupe-tds/abonnes' : '/app/creator/abonnes';

  String get routeStats =>
      this == CreatorSurface.tuteur ? '/app/groupe-tds/stats' : '/app/creator/stats';

  /// Endpoint de publication. **Contrat existant** : `/videos/tds` attend
  /// `groupeTdsId`, `/videos` attend juste `sourceObjectKey` + métadonnées.
  String get endpointPublication =>
      this == CreatorSurface.tuteur ? '/videos/tds' : '/videos';
}
