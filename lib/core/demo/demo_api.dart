import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';

import 'demo_content.dart';
import 'demo_session.dart';

/// Sert toutes les requêtes du client API quand une [DemoSession] est
/// active — le réseau n'est jamais touché, chaque écran reçoit des données
/// fictives cohérentes ([DemoContent]) au format exact du vrai serveur.
///
/// L'état est **mutable en mémoire** : envoyer un message, commenter, liker,
/// publier une ressource ou une vidéo, traiter un signalement ou déposer une
/// demande de statut modifie les données servies ensuite, pour que chaque
/// parcours soit réellement testable de bout en bout. Tout repart de zéro
/// quand l'application (ou la session démo) redémarre.
class DemoApiInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!DemoSession.active) return handler.next(options);

    // Petite latence pour que squelettes et indicateurs restent visibles.
    await Future<void>.delayed(const Duration(milliseconds: 250));

    Object? data;
    try {
      data = _DemoRoutes.repondre(options);
    } catch (_) {
      data = null;
    }
    data ??= options.method == 'GET' ? <dynamic>[] : <String, dynamic>{'ok': true};

    handler.resolve(
      Response(requestOptions: options, statusCode: 200, data: data),
    );
  }
}

/// État mutable du Mode Test, initialisé paresseusement depuis [DemoContent].
class _DemoStore {
  _DemoStore._();

  static int _sequence = 0;
  static String id(String prefixe) => '$prefixe-demo-${++_sequence}';

  static final List<Map<String, dynamic>> videos = [
    for (final v in DemoContent.videos) Map<String, dynamic>.from(v),
  ];

  static final Map<String, List<Map<String, dynamic>>> commentaires = {
    for (final e in DemoContent.commentairesParVideo.entries)
      e.key: [for (final c in e.value) Map<String, dynamic>.from(c)],
  };

  static final Map<String, List<Map<String, dynamic>>> ressources = {
    for (final e in DemoContent.ressourcesParCanal.entries)
      e.key: [for (final r in e.value) Map<String, dynamic>.from(r)],
  };

  static final Map<String, List<Map<String, dynamic>>> messagesRessource = {
    for (final e in DemoContent.messagesParRessource.entries)
      e.key: [for (final m in e.value) Map<String, dynamic>.from(m)],
  };

  static final List<Map<String, dynamic>> conversations = [
    for (final c in DemoContent.conversations) Map<String, dynamic>.from(c),
  ];

  static final Map<String, List<Map<String, dynamic>>> messagesConversation = {
    for (final e in DemoContent.messagesParConversation.entries)
      e.key: [for (final m in e.value) Map<String, dynamic>.from(m)],
  };

  static final List<Map<String, dynamic>> notifications = [
    for (final n in DemoContent.notifications) Map<String, dynamic>.from(n),
  ];

  static final List<Map<String, dynamic>> signalements = [
    for (final s in DemoContent.signalements) Map<String, dynamic>.from(s),
  ];

  static final List<Map<String, dynamic>> demandes = [
    for (final d in DemoContent.demandes) Map<String, dynamic>.from(d),
  ];
}

class _DemoRoutes {
  _DemoRoutes._();

  static String get _moi => DemoSession.userId ?? 'usr-demo-etudiant';

  /// L'utilisateur démo courant, au format `auteur` des messages.
  static Map<String, dynamic> get _moiAuteur {
    final p = DemoSession.profilJson;
    return {
      'id': p['id'],
      'prenom': p['prenom'],
      'nom': p['nom'],
      'rang': p['rang'],
      'photoUrl': p['photoUrl'],
    };
  }

  static String get _maintenant => DateTime.now().toIso8601String();

  static Map<String, dynamic> _corps(RequestOptions o) =>
      o.data is Map ? Map<String, dynamic>.from(o.data as Map) : const {};

  static String? _q(RequestOptions o, String cle) =>
      o.queryParameters[cle]?.toString();

  /// Route la requête vers la bonne réponse fictive. Renvoie `null` pour
  /// les chemins inconnus (l'intercepteur sert alors un défaut inoffensif).
  static Object? repondre(RequestOptions o) {
    final m = o.method.toUpperCase();
    final p = o.path;
    final seg = p.split('/').where((s) => s.isNotEmpty).toList();

    // ------------------------------------------------------------- Auth
    if (p == '/auth/me') return DemoSession.profilJson;
    if (p.startsWith('/auth/')) return {'ok': true};
    if (m == 'PATCH' && p == '/utilisateurs/moi/niveau') {
      final niveau = _corps(o)['niveauId'] as String?;
      if (niveau != null) DemoSession.definirNiveau(niveau);
      return {'ok': true};
    }
    if (m == 'GET' && seg.length == 2 && seg[0] == 'utilisateurs') {
      final id = seg[1];
      if (id == _moi) return DemoSession.profilJson;
      return DemoContent.profils[id] ?? {'id': id, 'prenom': 'Utilisateur', 'nom': 'UniVerse', 'rang': 'etudiant'};
    }

    // ------------------------------------------------------ Universités
    if (m == 'GET' && p == '/universites') return DemoContent.universites;
    if (m == 'GET' && seg.length == 3 && seg[0] == 'universites' && seg[2] == 'arbre') {
      return DemoContent.arbre(seg[1]);
    }

    // ------------------------------------------------------- Ressources
    if (m == 'GET' && p == '/ressources') {
      final canalId = _q(o, 'canalId') ?? '';
      return _DemoStore.ressources[canalId] ?? const <Map<String, dynamic>>[];
    }
    if (m == 'POST' && p == '/ressources') {
      final corps = _corps(o);
      final canalId = corps['canalId'] as String? ?? '';
      final id = _DemoStore.id('res');
      final ressource = {
        'id': id,
        'titre': corps['titre'] ?? 'Nouvelle ressource',
        'type': corps['type'] ?? 'discussion',
      };
      _DemoStore.ressources.putIfAbsent(canalId, () => []).insert(0, ressource);
      final contenu = (corps['contenu'] as String?)?.trim();
      _DemoStore.messagesRessource[id] = [
        if (contenu != null && contenu.isNotEmpty)
          {
            'id': _DemoStore.id('msg'),
            'contenu': contenu,
            'auteurId': _moi,
            'auteur': _moiAuteur,
            'createdAt': _maintenant,
          },
      ];
      return {'id': id, ...ressource};
    }
    if (seg.length == 3 && seg[0] == 'ressources' && seg[2] == 'messages') {
      final ressourceId = seg[1];
      final fil = _DemoStore.messagesRessource.putIfAbsent(ressourceId, () => []);
      if (m == 'GET') return fil;
      if (m == 'POST') {
        final corps = _corps(o);
        final message = {
          'id': _DemoStore.id('msg'),
          'contenu': corps['contenu'] ?? '',
          'auteurId': _moi,
          'auteur': _moiAuteur,
          if (corps['repondAId'] != null) 'repondA': corps['repondAId'],
          'createdAt': _maintenant,
        };
        fil.add(message);
        return message;
      }
    }

    // ---------------------------------------------------- Conversations
    if (m == 'GET' && p == '/conversations') return _DemoStore.conversations;
    if (m == 'POST' && p == '/conversations') {
      final destinataireId = _corps(o)['destinataireId'] as String?;
      final existante = _DemoStore.conversations.where((c) {
        final parts = c['participants'] as List? ?? const [];
        return parts.any((part) =>
            ((part as Map)['utilisateur'] as Map?)?['id'] == destinataireId);
      }).toList();
      if (existante.isNotEmpty) return {'id': existante.first['id']};

      final profil = DemoContent.profils[destinataireId] ??
          {'id': destinataireId, 'prenom': 'Utilisateur', 'nom': 'UniVerse', 'rang': 'etudiant'};
      final id = _DemoStore.id('conv');
      _DemoStore.conversations.insert(0, {
        'id': id,
        'type': 'libre',
        'statut': 'ouverte',
        'updatedAt': _maintenant,
        'nonLus': 0,
        'participants': [
          {'utilisateur': profil},
        ],
      });
      _DemoStore.messagesConversation[id] = [];
      return {'id': id};
    }
    if (seg.length == 3 && seg[0] == 'conversations' && seg[2] == 'messages') {
      final convId = seg[1];
      final fil = _DemoStore.messagesConversation.putIfAbsent(convId, () => []);
      if (m == 'GET') {
        return [
          for (final msg in fil)
            {...msg, 'auteurId': msg['auteurId'] == '@moi' ? _moi : msg['auteurId']},
        ];
      }
      if (m == 'POST') {
        final corps = _corps(o);
        final contenu = (corps['contenu'] as String?)?.trim() ?? '';
        fil.add({
          'id': _DemoStore.id('msg'),
          'contenu': contenu,
          'auteurId': _moi,
          'lu': true,
          'createdAt': _maintenant,
        });
        // Réponse automatique de l'interlocuteur, pour que la conversation
        // reste vivante (et testable) sans back ni socket.
        final contact = _contactDeConversation(convId);
        if (contact != null) {
          fil.add({
            'id': _DemoStore.id('msg'),
            'contenu': _reponseAuto(contenu),
            'auteurId': contact['id'],
            'auteur': contact,
            'createdAt': _maintenant,
          });
        }
        _majConversation(convId, contact == null ? contenu : _reponseAuto(contenu));
        return {'ok': true};
      }
    }

    // ----------------------------------------------------------- Vidéos
    if (m == 'GET' && p == '/videos/feed') return _videosServies();
    if (m == 'GET' && p == '/videos/recherche') {
      final motCle = (_q(o, 'motCle') ?? '').toLowerCase();
      return _videosServies()
          .where((v) =>
              (v['titre'] as String? ?? '').toLowerCase().contains(motCle) ||
              (v['description'] as String? ?? '').toLowerCase().contains(motCle) ||
              (v['matiere'] as String? ?? '').toLowerCase().contains(motCle))
          .toList();
    }
    if ((m == 'POST') && (p == '/videos' || p == '/videos/tds')) {
      final corps = _corps(o);
      final video = {
        'id': _DemoStore.id('vid'),
        'titre': corps['titre'] ?? 'Nouvelle vidéo',
        'description': corps['description'],
        'youtubeId': 'aqz-KE-bpKQ',
        'nombreLikes': 0,
        'nombreVues': 0,
        'dureeSecondes': 596,
        'matiere': corps['matiere'],
        'createdAt': _maintenant,
        if (p == '/videos/tds')
          'groupeTds': {'nom': 'Groupe TDS — ${_moiAuteur['prenom']} ${_moiAuteur['nom']}'}
        else
          'compteCreateur': {'utilisateur': {'id': '@moi'}},
      };
      _DemoStore.videos.insert(0, video);
      return video;
    }
    if (seg.length == 3 && seg[0] == 'videos') {
      final videoId = seg[1];
      final action = seg[2];
      final video = _DemoStore.videos
          .where((v) => v['id'] == videoId)
          .cast<Map<String, dynamic>?>()
          .firstOrNull;
      switch (action) {
        case 'like':
          if (video != null) {
            final avait = video['likedByMe'] == true;
            if (m == 'POST' && !avait) {
              video['likedByMe'] = true;
              video['nombreLikes'] = (video['nombreLikes'] as int? ?? 0) + 1;
            } else if (m == 'DELETE' && avait) {
              video['likedByMe'] = false;
              video['nombreLikes'] =
                  math.max(0, (video['nombreLikes'] as int? ?? 1) - 1);
            }
          }
          return {'ok': true};
        case 'masquer':
          _DemoStore.videos.removeWhere((v) => v['id'] == videoId);
          return {'ok': true};
        case 'commentaires':
          final fil = _DemoStore.commentaires.putIfAbsent(videoId, () => []);
          if (m == 'GET') return fil;
          if (m == 'POST') {
            final commentaire = {
              'id': _DemoStore.id('com'),
              'contenu': _corps(o)['contenu'] ?? '',
              'auteur': _moiAuteur,
              'createdAt': _maintenant,
            };
            fil.add(commentaire);
            return commentaire;
          }
        case 'stats-detaillees':
          return DemoContent.statsDetaillees(videoId);
      }
    }

    // ------------------------------------------------------ Bibliothèque
    if (m == 'GET' && p == '/livres') {
      final motCle = (_q(o, 'motCle') ?? '').toLowerCase();
      if (motCle.isEmpty) return DemoContent.livres;
      return DemoContent.livres
          .where((l) =>
              (l['titre'] as String).toLowerCase().contains(motCle) ||
              (l['auteurLivre'] as String? ?? '').toLowerCase().contains(motCle))
          .toList();
    }

    // ---------------------------------------------------------- Stockage
    if (p == '/storage/presign/download') return {'url': DemoContent.urlPdfDemo};
    if (p == '/storage/presign/upload') {
      final cle = _corps(o)['cle'] as String? ?? 'demo/upload.bin';
      // L'URL n'est jamais appelée : les écrans d'upload court-circuitent
      // le dépôt de fichier quand la session démo est active.
      return {
        'url': 'https://demo.universe.invalid/upload',
        'fields': {'key': cle},
      };
    }

    // -------------------------------------------------------- Recherche
    if (m == 'GET' && p == '/recherche/canaux') {
      final motCle = (_q(o, 'motCle') ?? '').toLowerCase();
      return DemoContent.canauxRecherche
          .where((c) =>
              ((c['canal'] as Map)['nom'] as String).toLowerCase().contains(motCle) ||
              ((c['canal'] as Map)['matiere'] as String? ?? '')
                  .toLowerCase()
                  .contains(motCle))
          .toList();
    }

    // ---------------------------------------------------- Notifications
    if (m == 'GET' && p == '/notifications') return _DemoStore.notifications;
    if (m == 'PATCH' && seg.length == 3 && seg[0] == 'notifications' && seg[2] == 'lu') {
      for (final n in _DemoStore.notifications) {
        if (n['id'] == seg[1]) n['lu'] = true;
      }
      return {'ok': true};
    }

    // ----------------------------------------------------- Signalements
    if (m == 'GET' && p == '/signalements/recus') return _DemoStore.signalements;
    if (m == 'PATCH' && seg.length == 3 && seg[0] == 'signalements' && seg[2] == 'statut') {
      final statut = _corps(o)['statut'];
      for (final s in _DemoStore.signalements) {
        if (s['id'] == seg[1]) s['statut'] = statut;
      }
      return {'ok': true};
    }
    if (m == 'POST' && (p == '/signalements/contenu' || p == '/signalements/personne')) {
      final corps = _corps(o);
      _DemoStore.signalements.insert(0, {
        'id': _DemoStore.id('sig'),
        'sujet': corps['motif'] ?? corps['sujet'] ?? 'Signalement',
        'description': corps['description'] ?? corps['details'] ?? '',
        'statut': 'nouveau',
        'gravite': corps['gravite'] ?? 'normale',
        'createdAt': _maintenant,
      });
      return {'ok': true};
    }

    // --------------------------------------------------------- Demandes
    if (m == 'GET' && p == '/demandes-statut/mes-demandes') {
      return _DemoStore.demandes;
    }
    if (m == 'POST' && p == '/demandes-statut') {
      final corps = _corps(o);
      _DemoStore.demandes.insert(0, {
        'id': _DemoStore.id('dem'),
        'type': corps['type'] ?? 'formateur',
        'statut': 'en_attente',
        'message': corps['motif'],
        'createdAt': _maintenant,
      });
      return {'ok': true};
    }

    // --------------------------------------------------------- Créateur
    if (m == 'GET' && p == '/comptes-createurs/moi/abonnes') {
      return DemoContent.abonnes;
    }
    if (m == 'POST' && p == '/compte-createur') return {'ok': true};

    // --------------------------------------------------------------- IA
    if (m == 'POST' && p == '/ai/ask') {
      final corps = _corps(o);
      final question = (corps['question'] ?? corps['message'] ?? corps['prompt'] ?? '')
          .toString();
      return {'reponse': DemoContent.reponseIa(question)};
    }

    return null;
  }

  // ------------------------------------------------------------- Helpers

  /// Vidéos avec le marqueur `'@moi'` résolu vers le compte démo courant,
  /// pour que « Mes vidéos » et les statistiques créateur soient peuplées
  /// quel que soit le rôle simulé.
  static List<Map<String, dynamic>> _videosServies() {
    return [
      for (final v in _DemoStore.videos)
        () {
          final compte = v['compteCreateur'] as Map?;
          final utilisateur = compte?['utilisateur'] as Map?;
          if (utilisateur?['id'] != '@moi') return v;
          return {
            ...v,
            'compteCreateur': {'utilisateur': _moiAuteur},
          };
        }(),
    ];
  }

  static Map<String, dynamic>? _contactDeConversation(String convId) {
    for (final c in _DemoStore.conversations) {
      if (c['id'] != convId) continue;
      final parts = c['participants'] as List? ?? const [];
      if (parts.isEmpty) return null;
      final u = (parts.first as Map)['utilisateur'] as Map?;
      return u == null ? null : Map<String, dynamic>.from(u);
    }
    return null;
  }

  static void _majConversation(String convId, String dernierMessage) {
    for (final c in _DemoStore.conversations) {
      if (c['id'] == convId) {
        c['dernierMessage'] = dernierMessage;
        c['updatedAt'] = _maintenant;
        c['nonLus'] = 0;
      }
    }
  }

  static String _reponseAuto(String message) {
    if (message.endsWith('?')) {
      return 'Bonne question — je te réponds en détail ce soir. '
          '(réponse automatique du Mode Test)';
    }
    return 'Bien reçu, merci ! (réponse automatique du Mode Test)';
  }
}
