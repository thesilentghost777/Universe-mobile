import 'package:flutter/material.dart';

import '../../core/auth/role_access.dart';

/// Vers quel bord de l'écran la petite main pointe.
enum PointeurDirection { aucun, gauche, droite, haut, bas }

/// Onglet du footer que cette étape concerne — `demarrerTutoriel` bascule
/// automatiquement dessus en arrivant sur l'étape, pour que le spotlight
/// éclaire la vraie interface plutôt qu'une simple description abstraite.
/// `null` = l'étape ne dépend d'aucun onglet précis (rail, bouton flottant).
enum OngletTutoriel { accueil, biblio, uniTube, messages, parametres }

class EtapeTutoriel {
  const EtapeTutoriel({
    required this.icon,
    required this.titre,
    required this.texte,
    this.pointeur = PointeurDirection.aucun,
    this.onglet,
  });

  final IconData icon;
  final String titre;
  final String texte;
  final PointeurDirection pointeur;
  final OngletTutoriel? onglet;
}

/// Parcours guidé adapté au rôle (§9) — chaque onglet du footer est visité
/// pour de vrai (voir [OngletTutoriel]), pas seulement décrit. La version
/// Enseignant est volontairement plus détaillée et plus lente à lire :
/// public souvent plus âgé, moins familier avec ce genre de parcours à
/// l'écran.
List<EtapeTutoriel> etapesPour(Rang rang) {
  const bienvenue = EtapeTutoriel(
    icon: Icons.waving_hand_rounded,
    titre: 'Bienvenue sur UniVerse !',
    texte: 'On te fait faire le tour complet de l\'application, écran par '
        'écran, avant de te laisser commencer. Tu peux le repasser à tout '
        'moment depuis Paramètres > Aide & Support.',
  );

  const rail = EtapeTutoriel(
    icon: Icons.apartment_rounded,
    titre: 'Tes universités',
    texte: 'Sur le bord gauche, retrouve les universités que tu suis. Le '
        'bouton « + » tout en bas permet d\'en épingler une nouvelle — tu '
        'peux consulter le contenu de n\'importe quelle université, même '
        'celle où tu n\'es pas inscrit.',
    pointeur: PointeurDirection.gauche,
    onglet: OngletTutoriel.accueil,
  );

  const accueilUniTube = EtapeTutoriel(
    icon: Icons.play_circle_rounded,
    titre: 'L\'accueil, c\'est UniTube',
    texte: 'Dès l\'ouverture, tu arrives sur ton fil de vidéos de cours, '
        'trié par ton niveau puis par les créateurs que tu suis. Un bandeau '
        'en haut permet de basculer vers l\'espace universitaire.',
    pointeur: PointeurDirection.haut,
    onglet: OngletTutoriel.accueil,
  );

  const recherche = EtapeTutoriel(
    icon: Icons.search_rounded,
    titre: 'La recherche',
    texte: 'L\'icône en haut à droite ouvre une recherche unifiée : vidéos, '
        'canaux et conversations, avec des suggestions qui apparaissent dès '
        'que tu commences à taper.',
    pointeur: PointeurDirection.haut,
    onglet: OngletTutoriel.accueil,
  );

  const biblio = EtapeTutoriel(
    icon: Icons.menu_book_rounded,
    titre: 'La bibliothèque',
    texte: 'Des livres numériques partagés entre toutes les universités '
        'partenaires. Le champ de recherche en haut te propose des '
        'suggestions au fil de ta frappe, exactement comme sur UniTube.',
    pointeur: PointeurDirection.haut,
    onglet: OngletTutoriel.biblio,
  );

  const messages = EtapeTutoriel(
    icon: Icons.forum_rounded,
    titre: 'Messagerie',
    texte: 'Tes conversations en un coup d\'œil. Le bouton en haut ouvre un '
        'nouveau message : tu peux écrire à quelqu\'un que tu as déjà '
        'croisé, ou à n\'importe qui grâce à son identifiant — la personne '
        'pourra alors t\'accepter ou te bloquer avant d\'échanger.',
    pointeur: PointeurDirection.haut,
    onglet: OngletTutoriel.messages,
  );

  const assistant = EtapeTutoriel(
    icon: Icons.auto_awesome_rounded,
    titre: 'Un assistant toujours disponible',
    texte: 'Le bouton flottant en dégradé ouvre l\'assistant IA — pose-lui '
        'toutes tes questions de cours, où que tu sois dans l\'app.',
    pointeur: PointeurDirection.droite,
  );

  const parametres = EtapeTutoriel(
    icon: Icons.settings_rounded,
    titre: 'Paramètres',
    texte: 'Ton profil, ta confidentialité, tes notifications, l\'apparence '
        'de l\'app et l\'aide sont ici. C\'est aussi là que tu peux repasser '
        'ce tutoriel ou changer la langue de l\'application.',
    onglet: OngletTutoriel.parametres,
  );

  const monEspace = EtapeTutoriel(
    icon: Icons.dashboard_customize_rounded,
    titre: 'Mon espace',
    texte: 'Le bouton coloré tout en bas du rail de gauche regroupe tout ce '
        'qui est propre à ton rôle : publication, statistiques, suivi. Il '
        'est visible depuis n\'importe quel onglet.',
    pointeur: PointeurDirection.gauche,
  );

  final etapesCommunes = [
    bienvenue,
    rail,
    accueilUniTube,
    recherche,
    biblio,
    messages,
  ];

  switch (rang) {
    case Rang.etudiant:
      return [...etapesCommunes, parametres, assistant];

    case Rang.moderateur:
      return [
        ...etapesCommunes,
        parametres,
        const EtapeTutoriel(
          icon: Icons.campaign_rounded,
          titre: 'Signalements',
          texte: 'Depuis « Mon espace », tu traites les signalements des '
              'étudiants et publies les ressources des canaux qui te sont '
              'assignés. Tu ne publies jamais de vidéo toi-même.',
        ),
        monEspace,
        assistant,
      ];

    case Rang.tuteur:
    case Rang.formateur:
      return [
        ...etapesCommunes,
        parametres,
        EtapeTutoriel(
          icon: Icons.video_call_rounded,
          titre: rang == Rang.tuteur ? 'Ton groupe' : 'Ton espace créateur',
          texte: rang == Rang.tuteur
              ? 'Publie tes vidéos et accompagne ton groupe d\'étudiants '
                  'depuis le bouton UniTube du centre, ou depuis « Mon '
                  'espace ». Tu peux aussi personnaliser la bannière de ta '
                  'chaîne.'
              : 'Publie tes vidéos pédagogiques, suis tes statistiques et '
                  'personnalise la bannière de ta chaîne depuis « Mon '
                  'espace ».',
        ),
        monEspace,
        assistant,
      ];

    case Rang.enseignant:
      // Rythme plus lent, plus d'étapes, langage très simple.
      return [
        bienvenue,
        const EtapeTutoriel(
          icon: Icons.badge_rounded,
          titre: 'Ton statut d\'enseignant',
          texte: 'Si ton dossier est encore en cours d\'examen, un bandeau '
              'te l\'indique toujours en haut de l\'accueil, avec ce qu\'il '
              'te reste à faire. Rien à t\'inquiéter, tu peux déjà utiliser '
              'l\'application normalement en attendant.',
          pointeur: PointeurDirection.haut,
          onglet: OngletTutoriel.accueil,
        ),
        rail,
        accueilUniTube,
        recherche,
        biblio,
        messages,
        parametres,
        const EtapeTutoriel(
          icon: Icons.dashboard_customize_rounded,
          titre: 'Mon espace',
          texte: 'Une fois ton dossier validé, retrouve ici la publication '
              'de tes vidéos, tes statistiques et la messagerie ouverte '
              'vers tous les comptes, avec une fenêtre de réponse de 24 h.',
        ),
        assistant,
      ];
  }
}
