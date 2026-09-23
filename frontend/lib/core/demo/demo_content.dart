/// Détecte un compte de test créé par `AuthNotifier.simulerRole()`.
///
/// **Règle absolue** : tout contenu de [DemoContent] ne doit s'afficher que
/// derrière ce garde. Un vrai compte connecté au back (id serveur, jamais
/// préfixé `usr-demo-`) ne doit jamais voir ces données — en cas d'échec
/// réseau réel, l'écran doit afficher son état vide/erreur habituel, pas se
/// rabattre sur ce contenu fictif.
bool estCompteDemo(String? userId) =>
    userId != null && userId.startsWith('usr-demo-');

/// Avatar fictif stable pour une graine donnée (nécessite internet, comme
/// les miniatures YouTube — acceptable pour un APK de test).
String avatarDemo(String graine) => 'https://i.pravatar.cc/150?u=$graine';

/// Contenu riche et cohérent pour le Mode Test : deux universités avec
/// arborescence complète, des canaux avec de vraies discussions (réponses
/// imbriquées comprises), des conversations privées avec historique, un fil
/// UniTube garni de vidéos aux miniatures réelles, une bibliothèque de
/// livres ouvrables, des contacts, notifications, signalements, demandes de
/// statut et statistiques créateur — pour donner l'illusion d'un compte
/// réellement connecté au back, quel que soit le rôle simulé.
///
/// Toutes les données sont des `Map` JSON, au format exact que le vrai
/// serveur renverrait : elles sont servies par `DemoApiInterceptor` qui se
/// substitue au réseau, si bien que chaque écran passe par son parcours de
/// chargement habituel.
class DemoContent {
  const DemoContent._();

  static const uy1 = 'uni-demo-uy1';
  static const udla = 'uni-demo-udla';

  /// PDF public et stable, ouvert quand on télécharge un livre ou un fichier.
  static const urlPdfDemo =
      'https://mozilla.github.io/pdf.js/web/compressed.tracemonkey-pldi-09.pdf';

  static final List<Map<String, dynamic>> universites = [
    {'id': uy1, 'nom': 'Université de Yaoundé I', 'sigle': 'UY1', 'statut': 'actif'},
    {'id': udla, 'nom': 'Université de Douala', 'sigle': 'UD', 'statut': 'actif'},
  ];

  /// Arborescence Faculté → Filière → Niveau → Matière → Canaux, avec des
  /// ids partout (l'onboarding en a besoin pour choisir un niveau).
  static Map<String, dynamic> arbre(String universiteId) {
    if (universiteId == udla) {
      return {
        'facultes': [
          {
            'id': 'fac-ud-droit',
            'nom': 'Faculté de Droit et Science Politique',
            'filieres': [
              {
                'id': 'fil-ud-affaires',
                'nom': 'Droit des affaires',
                'niveaux': [
                  {
                    'id': 'niv-ud-affaires-l2',
                    'nom': 'Licence 2',
                    'matieres': [
                      {
                        'id': 'mat-ud-civil',
                        'nom': 'Droit civil',
                        'canaux': [
                          {'id': 'canal-droit-civil', 'nom': 'Droit civil — Discussions', 'nombreNonLus': 3},
                          {'id': 'canal-droit-annonces', 'nom': 'Droit civil — Annonces', 'nombreNonLus': 0},
                        ],
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ],
      };
    }
    return {
      'facultes': [
        {
          'id': 'fac-uy1-sciences',
          'nom': 'Faculté des Sciences',
          'filieres': [
            {
              'id': 'fil-uy1-info',
              'nom': 'Informatique',
              'niveaux': [
                {
                  'id': 'niv-uy1-info-l3',
                  'nom': 'Licence 3',
                  'matieres': [
                    {
                      'id': 'mat-uy1-algo',
                      'nom': 'Algorithmique',
                      'canaux': [
                        {'id': 'canal-algo-annonces', 'nom': 'Algorithmique — Annonces', 'nombreNonLus': 1},
                        {'id': 'canal-algo-td', 'nom': 'Algorithmique — TD', 'nombreNonLus': 5},
                      ],
                    },
                    {
                      'id': 'mat-uy1-reseaux',
                      'nom': 'Réseaux',
                      'canaux': [
                        {'id': 'canal-reseaux', 'nom': 'Réseaux — Cours', 'nombreNonLus': 0},
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
        {
          'id': 'fac-uy1-medecine',
          'nom': 'Faculté de Médecine et des Sciences Biomédicales',
          'filieres': [
            {
              'id': 'fil-uy1-medgen',
              'nom': 'Médecine Générale',
              'niveaux': [
                {
                  'id': 'niv-uy1-medgen-l2',
                  'nom': 'Licence 2',
                  'matieres': [
                    {
                      'id': 'mat-uy1-anatomie',
                      'nom': 'Anatomie',
                      'canaux': [
                        {'id': 'canal-anatomie', 'nom': 'Anatomie — Discussions', 'nombreNonLus': 2},
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
      ],
    };
  }

  /// Tous les canaux à plat, au format attendu par `GET /recherche/canaux`.
  static final List<Map<String, dynamic>> canauxRecherche = [
    {'universiteId': uy1, 'universiteNom': 'Université de Yaoundé I', 'canal': {'id': 'canal-algo-annonces', 'nom': 'Algorithmique — Annonces', 'matiere': 'Algorithmique'}},
    {'universiteId': uy1, 'universiteNom': 'Université de Yaoundé I', 'canal': {'id': 'canal-algo-td', 'nom': 'Algorithmique — TD', 'matiere': 'Algorithmique'}},
    {'universiteId': uy1, 'universiteNom': 'Université de Yaoundé I', 'canal': {'id': 'canal-reseaux', 'nom': 'Réseaux — Cours', 'matiere': 'Réseaux'}},
    {'universiteId': uy1, 'universiteNom': 'Université de Yaoundé I', 'canal': {'id': 'canal-anatomie', 'nom': 'Anatomie — Discussions', 'matiere': 'Anatomie'}},
    {'universiteId': udla, 'universiteNom': 'Université de Douala', 'canal': {'id': 'canal-droit-civil', 'nom': 'Droit civil — Discussions', 'matiere': 'Droit civil'}},
    {'universiteId': udla, 'universiteNom': 'Université de Douala', 'canal': {'id': 'canal-droit-annonces', 'nom': 'Droit civil — Annonces', 'matiere': 'Droit civil'}},
  ];

  // ------------------------------------------------------------- Personnes

  static final Map<String, dynamic> _auteurEnseignant = {
    'id': 'usr-demo-auteur-1',
    'prenom': 'Dr. Joseph',
    'nom': 'Ngo',
    'rang': 'enseignant',
    'photoUrl': avatarDemo('joseph-ngo'),
  };
  static final Map<String, dynamic> _auteurTuteur = {
    'id': 'usr-demo-contact-1',
    'prenom': 'Guy',
    'nom': 'Fotso',
    'rang': 'tuteur',
    'photoUrl': avatarDemo('guy-fotso'),
  };
  static final Map<String, dynamic> _auteurEtudiant1 = {
    'id': 'usr-demo-auteur-3',
    'prenom': 'Alex',
    'nom': 'Kamga',
    'rang': 'etudiant',
    'photoUrl': avatarDemo('alex-kamga'),
  };
  static final Map<String, dynamic> _auteurEtudiant2 = {
    'id': 'usr-demo-contact-3',
    'prenom': 'Fatima',
    'nom': 'Bello',
    'rang': 'etudiant',
    'photoUrl': avatarDemo('fatima-bello'),
  };
  static final Map<String, dynamic> _auteurFormatrice = {
    'id': 'usr-demo-contact-4',
    'prenom': 'Sarah',
    'nom': 'Mballa',
    'rang': 'formateur',
    'photoUrl': avatarDemo('sarah-mballa'),
  };
  static final Map<String, dynamic> _auteurModerateur = {
    'id': 'usr-demo-auteur-6',
    'prenom': 'Cyrille',
    'nom': 'Nkoulou',
    'rang': 'moderateur',
    'photoUrl': avatarDemo('cyrille-nkoulou'),
  };

  /// Profils consultables (`GET /utilisateurs/:id`), avec bio.
  static final Map<String, Map<String, dynamic>> profils = {
    for (final (auteur, bio) in [
      (_auteurEnseignant, 'Enseignant-chercheur en informatique à l\'UY1. Je publie mes cours et corrections sur UniTube.'),
      (_auteurTuteur, 'Tuteur du groupe Algorithmique L3. Disponible en semaine après 17 h.'),
      (_auteurEtudiant1, 'Étudiant en L3 Informatique — fan de compétitions de programmation.'),
      (_auteurEtudiant2, 'L3 Info — j\'aime bien réviser en groupe, écris-moi !'),
      (_auteurFormatrice, 'Formatrice TDS. Nouvelles vidéos chaque vendredi sur ma chaîne.'),
      (_auteurModerateur, 'Modérateur UniVerse pour l\'UY1.'),
    ])
      auteur['id'] as String: {...auteur, 'bio': bio},
  };

  /// Carnet d'adresses pré-rempli du Mode Test (l'app le construit
  /// normalement au fil des lectures : ici on veut pouvoir tester tout de
  /// suite « Nouveau message »).
  static final List<Map<String, dynamic>> contactsCarnet = [
    for (final a in [
      _auteurTuteur,
      _auteurEnseignant,
      _auteurEtudiant2,
      _auteurFormatrice,
      _auteurEtudiant1,
    ])
      {
        'id': a['id'],
        'nom': '${a['prenom']} ${a['nom']}',
        'rang': a['rang'],
        'photoUrl': a['photoUrl'],
      },
  ];

  // ------------------------------------------------------------ Ressources

  static final Map<String, List<Map<String, dynamic>>> ressourcesParCanal = {
    'canal-algo-annonces': [
      {'id': 'res-algo-1', 'titre': 'Rattrapage TD3 déplacé à vendredi', 'type': 'annonce'},
      {'id': 'res-algo-2', 'titre': 'Support de cours — Complexité amortie', 'type': 'cours'},
    ],
    'canal-algo-td': [
      {'id': 'res-algo-td-1', 'titre': 'TD4 — Arbres équilibrés (AVL)', 'type': 'exercice'},
      {'id': 'res-algo-td-2', 'titre': 'Correction TD3', 'type': 'cours'},
      {'id': 'res-algo-td-3', 'titre': 'Question sur la récursivité terminale', 'type': 'discussion'},
    ],
    'canal-reseaux': [
      {'id': 'res-reseaux-1', 'titre': 'Chapitre 4 — Le modèle OSI en pratique', 'type': 'cours'},
      {'id': 'res-reseaux-2', 'titre': 'TP routage — consignes', 'type': 'exercice'},
    ],
    'canal-anatomie': [
      {'id': 'res-anat-1', 'titre': 'Planche annotée — Système cardio-vasculaire', 'type': 'cours'},
      {'id': 'res-anat-2', 'titre': 'QCM blanc — session de révision', 'type': 'exercice'},
    ],
    'canal-droit-civil': [
      {'id': 'res-droit-1', 'titre': 'Fiche d\'arrêt — Cass. civ. 3e, 2019', 'type': 'cours'},
      {'id': 'res-droit-2', 'titre': 'Débat : la réforme du droit des contrats', 'type': 'discussion'},
    ],
    'canal-droit-annonces': [
      {'id': 'res-droit-annonce-1', 'titre': 'Nouvelle date de dépôt du mémoire', 'type': 'annonce'},
    ],
  };

  static String _il(Duration d) =>
      DateTime.now().subtract(d).toIso8601String();

  static final Map<String, List<Map<String, dynamic>>> messagesParRessource = {
    'res-algo-2': [
      {
        'id': 'msg-a1',
        'contenu': 'Voici le support complet sur la complexité amortie, avec '
            'l\'exemple du tableau dynamique traité en cours. Bon courage pour '
            'le TD3 !',
        'auteurId': _auteurEnseignant['id'],
        'auteur': _auteurEnseignant,
        'createdAt': _il(const Duration(days: 1, hours: 3)),
      },
      {
        'id': 'msg-a2',
        'contenu': 'Merci professeur, la partie sur la méthode du potentiel '
            'est beaucoup plus claire maintenant.',
        'auteurId': _auteurEtudiant1['id'],
        'auteur': _auteurEtudiant1,
        'createdAt': _il(const Duration(hours: 2)),
      },
    ],
    'res-algo-td-1': [
      {
        'id': 'msg-b1',
        'contenu': 'TD4 posté : rotations simples et doubles sur AVL, '
            'exercice 3 à rendre avant dimanche minuit.',
        'auteurId': _auteurTuteur['id'],
        'auteur': _auteurTuteur,
        'createdAt': _il(const Duration(days: 2, hours: 5)),
      },
      {
        'id': 'msg-b2',
        'contenu': 'Pour l\'exercice 2, on doit gérer le cas où le facteur '
            'd\'équilibre vaut ±2 des deux côtés en même temps ?',
        'auteurId': _auteurEtudiant2['id'],
        'auteur': _auteurEtudiant2,
        'createdAt': _il(const Duration(hours: 4)),
      },
      {
        'id': 'msg-b3',
        'contenu': 'Ce cas ne peut pas arriver si l\'arbre était équilibré '
            'avant l\'insertion — une seule rotation suffit toujours.',
        'auteurId': _auteurTuteur['id'],
        'auteur': _auteurTuteur,
        'repondA': 'msg-b2',
        'createdAt': _il(const Duration(hours: 3)),
      },
    ],
    'res-algo-td-3': [
      {
        'id': 'msg-b4',
        'contenu': 'Quelqu\'un peut m\'expliquer pourquoi la récursivité '
            'terminale évite le débordement de pile ?',
        'auteurId': _auteurEtudiant1['id'],
        'auteur': _auteurEtudiant1,
        'createdAt': _il(const Duration(hours: 26)),
      },
      {
        'id': 'msg-b5',
        'contenu': 'Parce que l\'appel récursif est la dernière opération : '
            'le compilateur peut réutiliser le même cadre de pile.',
        'auteurId': _auteurTuteur['id'],
        'auteur': _auteurTuteur,
        'repondA': 'msg-b4',
        'createdAt': _il(const Duration(hours: 20)),
      },
    ],
    'res-anat-1': [
      {
        'id': 'msg-c1',
        'contenu': 'Planche mise à jour avec les annotations du grand amphi '
            'de mardi (valves, oreillettes, trajet du sang).',
        'auteurId': _auteurEnseignant['id'],
        'auteur': _auteurEnseignant,
        'createdAt': _il(const Duration(hours: 6)),
      },
    ],
    'res-droit-2': [
      {
        'id': 'msg-d1',
        'contenu': 'Qu\'en pensez-vous : la réforme de 2016 a-t-elle vraiment '
            'clarifié la notion de cause ?',
        'auteurId': _auteurEtudiant1['id'],
        'auteur': _auteurEtudiant1,
        'createdAt': _il(const Duration(days: 1, hours: 1)),
      },
      {
        'id': 'msg-d2',
        'contenu': 'Elle l\'a surtout renommée en "contenu du contrat" — sur '
            'le fond, la jurisprudence antérieure reste largement valable.',
        'auteurId': _auteurEnseignant['id'],
        'auteur': _auteurEnseignant,
        'repondA': 'msg-d1',
        'createdAt': _il(const Duration(minutes: 40)),
      },
    ],
  };

  // -------------------------------------------------------- Conversations

  /// Conversations au format `GET /conversations` (participants imbriqués).
  static final List<Map<String, dynamic>> conversations = [
    {
      'id': 'conv-demo-1',
      'type': 'libre',
      'statut': 'ouverte',
      'updatedAt': _il(const Duration(minutes: 8)),
      'nonLus': 2,
      'participants': [
        {'utilisateur': _auteurTuteur},
      ],
      'dernierMessage': 'Envoie-moi ta copie corrigée dès que possible.',
    },
    {
      'id': 'conv-demo-2',
      'type': 'libre',
      'statut': 'ouverte',
      'updatedAt': _il(const Duration(hours: 3)),
      'nonLus': 0,
      'participants': [
        {'utilisateur': _auteurEnseignant},
      ],
      'dernierMessage': 'Très bien, on se voit à la reprise alors.',
    },
    {
      'id': 'conv-demo-3',
      'type': 'libre',
      'statut': 'ouverte',
      'updatedAt': _il(const Duration(hours: 22)),
      'nonLus': 1,
      'participants': [
        {'utilisateur': _auteurEtudiant2},
      ],
      'dernierMessage': 'T\'as compris l\'exo 4 toi ? 😅',
    },
    {
      'id': 'conv-demo-4',
      'type': 'libre',
      'statut': 'ouverte',
      'updatedAt': _il(const Duration(days: 2)),
      'nonLus': 0,
      'participants': [
        {'utilisateur': _auteurFormatrice},
      ],
      'dernierMessage': 'La prochaine vidéo sort ce vendredi.',
    },
  ];

  /// `'@moi'` est remplacé à la volée par l'id du compte démo courant.
  static final Map<String, List<Map<String, dynamic>>> messagesParConversation = {
    'conv-demo-1': [
      {
        'id': 'm1',
        'contenu': 'Bonsoir, j\'ai une question sur la question 3 du TD4.',
        'auteurId': '@moi',
        'lu': true,
        'createdAt': _il(const Duration(hours: 5)),
      },
      {
        'id': 'm2',
        'contenu': 'Dis-moi tout, je regarde ça avec toi.',
        'auteurId': _auteurTuteur['id'],
        'auteur': _auteurTuteur,
        'createdAt': _il(const Duration(hours: 4, minutes: 58)),
      },
      {
        'id': 'm3',
        'contenu': 'Envoie-moi ta copie corrigée dès que possible.',
        'auteurId': _auteurTuteur['id'],
        'auteur': _auteurTuteur,
        'createdAt': _il(const Duration(minutes: 8)),
      },
    ],
    'conv-demo-2': [
      {
        'id': 'm4',
        'contenu': 'Bonjour professeur, serez-vous présent au rattrapage ?',
        'auteurId': '@moi',
        'lu': true,
        'createdAt': _il(const Duration(hours: 4)),
      },
      {
        'id': 'm5',
        'contenu': 'Oui, je serai là à 8h précises en amphi B.',
        'auteurId': _auteurEnseignant['id'],
        'auteur': _auteurEnseignant,
        'createdAt': _il(const Duration(hours: 3, minutes: 10)),
      },
      {
        'id': 'm6',
        'contenu': 'Très bien, on se voit à la reprise alors.',
        'auteurId': _auteurEnseignant['id'],
        'auteur': _auteurEnseignant,
        'createdAt': _il(const Duration(hours: 3)),
      },
    ],
    'conv-demo-3': [
      {
        'id': 'm7',
        'contenu': 'Salut ! T\'as compris l\'exo 4 toi ? 😅',
        'auteurId': _auteurEtudiant2['id'],
        'auteur': _auteurEtudiant2,
        'createdAt': _il(const Duration(hours: 22)),
      },
    ],
    'conv-demo-4': [
      {
        'id': 'm8',
        'contenu': 'Merci pour la vidéo sur les schémas relationnels !',
        'auteurId': '@moi',
        'lu': true,
        'createdAt': _il(const Duration(days: 2, hours: 1)),
      },
      {
        'id': 'm9',
        'contenu': 'Avec plaisir. La prochaine vidéo sort ce vendredi.',
        'auteurId': _auteurFormatrice['id'],
        'auteur': _auteurFormatrice,
        'createdAt': _il(const Duration(days: 2)),
      },
    ],
  };

  // -------------------------------------------------------------- UniTube

  /// Vidéos du fil, au format `GET /videos/feed`. Les `youtubeId` sont de
  /// vraies vidéos publiques : chaque carte a donc une **vraie miniature**
  /// (`https://img.youtube.com/vi/{id}/hqdefault.jpg`) et se lit dans le
  /// lecteur intégré. `compteCreateur.utilisateur.id == '@moi'` marque les
  /// vidéos qui appartiennent au compte démo courant (espace créateur).
  static final List<Map<String, dynamic>> videos = [
    {
      'id': 'vid-demo-1',
      'titre': 'Les réseaux de neurones — introduction visuelle',
      'description': 'Reprise détaillée du chapitre 4 avec exemples chiffrés '
          'et animations. Prérequis : algèbre linéaire de L2.',
      'youtubeId': 'aircAruvnKk',
      'nombreLikes': 132,
      'nombreVues': 1840,
      'dureeSecondes': 1148,
      'matiere': 'Algorithmique',
      'createdAt': _il(const Duration(days: 1)),
      'compteCreateur': {'utilisateur': _auteurEnseignant},
    },
    {
      'id': 'vid-demo-2',
      'titre': 'TD4 corrigé en direct — Arbres AVL',
      'description': 'Correction pas à pas des 5 exercices, questions en fin '
          'de séance.',
      'youtubeId': 'fNk_zzaMoSs',
      'nombreLikes': 87,
      'nombreVues': 963,
      'dureeSecondes': 1532,
      'matiere': 'Algorithmique',
      'createdAt': _il(const Duration(days: 2)),
      'compteCreateur': {'utilisateur': {'id': '@moi'}},
    },
    {
      'id': 'vid-demo-3',
      'titre': 'Modèle OSI en pratique — capture réseau commentée',
      'description': 'On suit un paquet réel de la couche physique à '
          'l\'application.',
      'youtubeId': 'spUNpyF58BY',
      'nombreLikes': 54,
      'nombreVues': 512,
      'dureeSecondes': 743,
      'likedByMe': true,
      'matiere': 'Réseaux',
      'createdAt': _il(const Duration(days: 3)),
      'compteCreateur': {'utilisateur': _auteurFormatrice},
    },
    {
      'id': 'vid-demo-4',
      'titre': 'Système cardio-vasculaire — planche annotée',
      'description': 'Trajet du sang, valves, et pièges classiques du QCM.',
      'youtubeId': 'WUvTyaaNkzM',
      'nombreLikes': 201,
      'nombreVues': 3120,
      'dureeSecondes': 1284,
      'matiere': 'Anatomie',
      'createdAt': _il(const Duration(days: 4)),
      'compteCreateur': {'utilisateur': _auteurEnseignant},
    },
    {
      'id': 'vid-demo-5',
      'titre': 'Groupe TDS — révisions Réseaux, session 3',
      'description': 'Séance de questions-réponses avant l\'examen blanc.',
      'youtubeId': 'aqz-KE-bpKQ',
      'nombreLikes': 39,
      'nombreVues': 288,
      'dureeSecondes': 2401,
      'matiere': 'Réseaux',
      'createdAt': _il(const Duration(days: 6)),
      'groupeTds': {'nom': 'Groupe TDS — Réseaux L3'},
    },
    {
      'id': 'vid-demo-6',
      'titre': 'Droit des contrats après 2016 : ce qui change vraiment',
      'description': 'Débat entre deux enseignants sur la portée de la '
          'réforme.',
      'youtubeId': 'jNQXAC9IVRw',
      'nombreLikes': 76,
      'nombreVues': 645,
      'dureeSecondes': 1096,
      'matiere': 'Droit civil',
      'createdAt': _il(const Duration(days: 8)),
      'compteCreateur': {'utilisateur': _auteurFormatrice},
    },
    {
      'id': 'vid-demo-7',
      'titre': 'Méthodologie — réussir sa fiche d\'arrêt en 20 minutes',
      'description': 'La structure attendue, les erreurs qui coûtent des '
          'points, et un exemple complet rédigé en direct.',
      'youtubeId': 'aircAruvnKk',
      'nombreLikes': 48,
      'nombreVues': 402,
      'dureeSecondes': 1210,
      'matiere': 'Droit civil',
      'createdAt': _il(const Duration(days: 9)),
      'compteCreateur': {'utilisateur': {'id': '@moi'}},
    },
    {
      'id': 'vid-demo-8',
      'titre': 'Complexité amortie — la méthode du potentiel expliquée',
      'description': 'L\'exemple canonique du tableau dynamique, en partant '
          'de zéro.',
      'youtubeId': 'fNk_zzaMoSs',
      'nombreLikes': 63,
      'nombreVues': 731,
      'dureeSecondes': 914,
      'matiere': 'Algorithmique',
      'createdAt': _il(const Duration(days: 11)),
      'compteCreateur': {'utilisateur': _auteurTuteur},
    },
  ];

  static final Map<String, List<Map<String, dynamic>>> commentairesParVideo = {
    'vid-demo-1': [
      {
        'id': 'com-1',
        'contenu': 'Enfin compris la rétropropagation, merci !',
        'auteur': _auteurEtudiant1,
        'createdAt': _il(const Duration(hours: 5)),
      },
      {
        'id': 'com-2',
        'contenu': 'Le passage sur les fonctions d\'activation est très clair.',
        'auteur': _auteurEtudiant2,
        'createdAt': _il(const Duration(hours: 2)),
      },
    ],
    'vid-demo-2': [
      {
        'id': 'com-3',
        'contenu': 'La double rotation à 12:40 m\'a sauvé pour le partiel 🙏',
        'auteur': _auteurEtudiant2,
        'createdAt': _il(const Duration(days: 1)),
      },
    ],
    'vid-demo-4': [
      {
        'id': 'com-4',
        'contenu': 'Est-ce que la planche est téléchargeable quelque part ?',
        'auteur': _auteurEtudiant1,
        'createdAt': _il(const Duration(days: 2)),
      },
      {
        'id': 'com-5',
        'contenu': 'Oui, dans le canal Anatomie — Discussions.',
        'auteur': _auteurEnseignant,
        'createdAt': _il(const Duration(days: 2)),
      },
    ],
  };

  /// `GET /videos/:id/stats-detaillees` — déterministe par vidéo.
  static Map<String, dynamic> statsDetaillees(String videoId) {
    final graine = videoId.hashCode.abs();
    final partages = 8 + graine % 40;
    final ratio = 0.42 + (graine % 35) / 100;
    final courbe = List<double>.generate(
      12,
      (i) => (1.0 - i * (0.055 + (graine % 4) / 100)).clamp(0.08, 1.0),
    );
    return {
      'partages': partages,
      'dureeMoyenneEcouteRatio': double.parse(ratio.toStringAsFixed(2)),
      'courbeRetention': courbe,
    };
  }

  // ---------------------------------------------------------- Bibliothèque

  static final List<Map<String, dynamic>> livres = [
    {'id': 'liv-1', 'titre': 'Algorithmique avancée', 'auteurLivre': 'T. Cormen', 'description': 'Structures de données, graphes et complexité.', 'fichierCle': 'livres/algorithmique-avancee.pdf'},
    {'id': 'liv-2', 'titre': 'Introduction au droit civil', 'auteurLivre': 'P. Malaurie', 'description': 'Les personnes, les biens, les obligations.', 'fichierCle': 'livres/introduction-droit-civil.pdf'},
    {'id': 'liv-3', 'titre': 'Anatomie humaine — Tome 1', 'auteurLivre': 'H. Rouvière', 'description': 'Tête, cou et tronc, planches en couleurs.', 'fichierCle': 'livres/anatomie-tome-1.pdf'},
    {'id': 'liv-4', 'titre': 'Réseaux informatiques', 'auteurLivre': 'A. Tanenbaum', 'description': 'Du modèle OSI aux architectures cloud.', 'fichierCle': 'livres/reseaux-informatiques.pdf'},
    {'id': 'liv-5', 'titre': 'Analyse mathématique L2', 'auteurLivre': 'J. Dixmier', 'description': 'Suites, séries et fonctions de plusieurs variables.', 'fichierCle': 'livres/analyse-l2.pdf'},
    {'id': 'liv-6', 'titre': 'Physiologie générale', 'auteurLivre': 'L. Sherwood', 'description': 'Des cellules aux systèmes.', 'fichierCle': 'livres/physiologie-generale.pdf'},
    {'id': 'liv-7', 'titre': 'Droit des obligations', 'auteurLivre': 'F. Terré', 'description': 'Contrats, responsabilité, régime général.', 'fichierCle': 'livres/droit-des-obligations.pdf'},
    {'id': 'liv-8', 'titre': 'Bases de données relationnelles', 'auteurLivre': 'G. Gardarin', 'description': 'Modèle relationnel, SQL et optimisation.', 'fichierCle': 'livres/bases-de-donnees.pdf'},
  ];

  // --------------------------------------------------------- Notifications

  static final List<Map<String, dynamic>> notifications = [
    {
      'id': 'notif-1',
      'type': 'nouveau_message_direct',
      'titre': 'Nouveau message de Guy Fotso',
      'lu': false,
      'createdAt': _il(const Duration(minutes: 8)),
    },
    {
      'id': 'notif-2',
      'type': 'reponse_recue',
      'titre': 'Guy Fotso a répondu dans « TD4 — Arbres équilibrés (AVL) »',
      'lu': false,
      'createdAt': _il(const Duration(hours: 3)),
    },
    {
      'id': 'notif-3',
      'type': 'nouvelle_ressource',
      'titre': 'Nouvelle ressource dans Algorithmique — Annonces',
      'lu': false,
      'createdAt': _il(const Duration(hours: 7)),
    },
    {
      'id': 'notif-4',
      'type': 'nouvelle_video_suivie',
      'titre': 'Dr. Joseph Ngo a publié une nouvelle vidéo',
      'lu': true,
      'createdAt': _il(const Duration(days: 1)),
    },
    {
      'id': 'notif-5',
      'type': 'statut_demande',
      'titre': 'Ta demande de statut a été examinée',
      'lu': true,
      'createdAt': _il(const Duration(days: 3)),
    },
  ];

  // -------------------------------------------------------------- Créateur

  /// `GET /comptes-createurs/moi/abonnes` — même format que les
  /// conversations (participants imbriqués).
  static final List<Map<String, dynamic>> abonnes = [
    for (final a in [
      _auteurEtudiant1,
      _auteurEtudiant2,
      _auteurTuteur,
      _auteurModerateur,
      _auteurFormatrice,
    ])
      {
        'id': 'abo-${a['id']}',
        'participants': [
          {'utilisateur': a},
        ],
      },
  ];

  // ---------------------------------------------------------- Signalements

  static final List<Map<String, dynamic>> signalements = [
    {
      'id': 'sig-1',
      'sujet': 'Vidéo signalée : contenu hors sujet',
      'description': 'La vidéo « Droit des contrats après 2016 » contiendrait '
          'un passage publicitaire sans rapport avec le cours.',
      'statut': 'nouveau',
      'gravite': 'normale',
      'createdAt': _il(const Duration(hours: 2)),
    },
    {
      'id': 'sig-2',
      'sujet': 'Propos déplacés dans Algorithmique — TD',
      'description': 'Un étudiant rapporte des moqueries répétées dans le fil '
          'du TD4. Captures d\'écran jointes au dossier.',
      'statut': 'nouveau',
      'gravite': 'urgente',
      'createdAt': _il(const Duration(minutes: 35)),
    },
    {
      'id': 'sig-3',
      'sujet': 'Lien de téléchargement mort',
      'description': 'Le livre « Analyse mathématique L2 » renvoie une erreur '
          '404 au téléchargement.',
      'statut': 'en_cours',
      'gravite': 'normale',
      'createdAt': _il(const Duration(days: 1)),
    },
    {
      'id': 'sig-4',
      'sujet': 'Compte usurpant un enseignant',
      'description': 'Résolu : le compte a été suspendu après vérification '
          'auprès du rectorat.',
      'statut': 'traite',
      'gravite': 'urgente',
      'createdAt': _il(const Duration(days: 4)),
    },
  ];

  // -------------------------------------------------------------- Demandes

  static final List<Map<String, dynamic>> demandes = [
    {
      'id': 'dem-1',
      'type': 'formateur',
      'statut': 'refusee',
      'message': 'Dossier incomplet : joins un exemple de contenu pédagogique '
          'déjà produit, puis dépose une nouvelle demande.',
      'createdAt': _il(const Duration(days: 30)),
    },
  ];

  // -------------------------------------------------------------------- IA

  static String reponseIa(String question) =>
      'Bonne question ! En résumé : « ${question.trim()} » touche à un point '
      'traité dans tes ressources récentes. Regarde le support « Complexité '
      'amortie » dans Algorithmique — Annonces, et la vidéo « TD4 corrigé en '
      'direct » sur UniTube. Si tu veux, pose-moi une question plus précise '
      'sur un exercice.\n\n(Réponse générée par l\'assistant du Mode Test — '
      'aucun serveur n\'a été contacté.)';
}
