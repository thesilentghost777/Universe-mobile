import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_erreur.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/widgets/universe_skeleton.dart';
import '../../core/widgets/universe_ui.dart';
import '../../shared/models/models.dart';
import '../home/app_shell.dart' show pendingCanalNavigationProvider;
import '../home/widgets/canal_rail.dart';
import '../messaging/contacts_store.dart';

/// Recherche unifiée (§ retour utilisateur) : avant, seules les vidéos
/// étaient cherchables (`VideoSearchPage`). Un seul champ de recherche
/// interroge désormais aussi les canaux et les conversations, chacun dans
/// son propre onglet.
class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _CanalResultat {
  const _CanalResultat({
    required this.universiteId,
    required this.universiteNom,
    required this.canal,
  });

  final String universiteId;
  final String universiteNom;
  final CanalRailItem canal;
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _q = TextEditingController();

  bool _loading = false;
  String? _erreur;
  List<VideoItem> _videos = [];
  List<_CanalResultat> _canaux = [];
  List<ConversationItem> _conversations = [];

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _tabs.dispose();
    _q.dispose();
    super.dispose();
  }

  /// Suggestions au fil de la frappe plutôt qu'à la seule validation —
  /// débounce court pour ne pas relancer une recherche à chaque caractère.
  void _rechercherAuFilDeLaFrappe(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _rechercher);
  }

  Future<void> _rechercher() async {
    final motCle = _q.text.trim();
    if (motCle.isEmpty) {
      setState(() {
        _videos = [];
        _canaux = [];
        _conversations = [];
        _erreur = null;
      });
      return;
    }
    setState(() => _loading = true);
    final motCleBas = motCle.toLowerCase();

    try {
      final videos = await _rechercherVideos(motCle);
      final canaux = await _rechercherCanauxReel(motCle);
      final conversations = await _rechercherConversations(motCleBas);
      if (!mounted) return;
      setState(() {
        _videos = videos;
        _canaux = canaux;
        _conversations = conversations;
        _erreur = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = ApiErreur.depuis(e).message;
        _loading = false;
      });
    }
  }

  Future<List<VideoItem>> _rechercherVideos(String motCle) async {
    try {
      final res = await ref.read(apiClientProvider).get(
        '/videos/recherche',
        queryParameters: {'motCle': motCle, 'limit': 30},
      );
      final raw = res.data;
      final list = raw is List ? raw : (raw as Map)['items'] as List? ?? [];
      return list.map((e) => VideoItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ApiErreur.depuis(e);
    }
  }

  /// `GET /recherche/canaux?motCle=&limit=` →
  /// `[{ universiteId, universiteNom, canal: { id, nom, matiere } }]`.
  Future<List<_CanalResultat>> _rechercherCanauxReel(String motCle) async {
    try {
      final res = await ref.read(apiClientProvider).get(
        '/recherche/canaux',
        queryParameters: {'motCle': motCle, 'limit': 30},
      );
      final raw = res.data;
      final list = raw is List ? raw : (raw as Map)['items'] as List? ?? [];
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        final c = m['canal'] as Map<String, dynamic>? ?? m;
        return _CanalResultat(
          universiteId: m['universiteId'] as String? ?? '',
          universiteNom: m['universiteNom'] as String? ?? '',
          canal: CanalRailItem(
            id: c['id'] as String,
            nom: c['nom'] as String? ?? tr(context, 'Canal'),
            matiere: c['matiere'] as String? ?? '',
          ),
        );
      }).toList();
    } catch (e) {
      throw ApiErreur.depuis(e);
    }
  }

  Future<List<ConversationItem>> _rechercherConversations(String motCleBas) async {
    List<ConversationItem> toutes;
    try {
      final res = await ref.read(apiClientProvider).get('/conversations');
      final raw = res.data;
      final list = raw is List ? raw : (raw as Map)['items'] as List? ?? [];
      toutes = list
          .map((e) => ConversationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ApiErreur.depuis(e);
    }
    return toutes
        .where((c) =>
            (c.destinataireNom ?? '').toLowerCase().contains(motCleBas) ||
            (c.dernierMessage ?? '').toLowerCase().contains(motCleBas))
        .toList();
  }

  void _ouvrirCanal(_CanalResultat r) {
    ref.read(pendingCanalNavigationProvider.notifier).state =
        (universiteId: r.universiteId, canalId: r.canal.id);
    context.go('/app');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Recherche')),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: '${tr(context, "Vidéos")}${_videos.isEmpty ? '' : ' (${_videos.length})'}'),
            Tab(text: '${tr(context, "Canaux")}${_canaux.isEmpty ? '' : ' (${_canaux.length})'}'),
            Tab(
              text: '${tr(context, "Messages")}'
                  '${_conversations.isEmpty ? '' : ' (${_conversations.length})'}',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: tr(context, 'Mots-clés, matière, personne…'),
                    ),
                    onChanged: _rechercherAuFilDeLaFrappe,
                    onSubmitted: (_) => _rechercher(),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: tr(context, 'Rechercher'),
                  child: InkWell(
                    onTap: _rechercher,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: UniverseColors.brandGradient,
                      ),
                      child: const Icon(Icons.search_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const ListTileSkeleton(count: 6)
                : _erreur != null
                    ? _videeSiVide(_erreur!)
                    : TabBarView(
                    controller: _tabs,
                    children: [
                      _listeVideos(t),
                      _listeCanaux(t),
                      _listeConversations(t),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _videeSiVide(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );

  Widget _listeVideos(UniverseTokens t) {
    if (_videos.isEmpty) {
      return _videeSiVide(
        _q.text.trim().isEmpty
            ? tr(context, 'Cherche une vidéo par titre ou par matière.')
            : tr(context, 'Aucune vidéo trouvée.'),
      );
    }
    return ListView.builder(
      itemCount: _videos.length,
      itemBuilder: (_, i) {
        final v = _videos[i];
        return ListTile(
          leading: const Icon(Icons.play_circle_outline),
          title: Text(v.titre),
          subtitle: Text(v.createurNom ?? '', style: TextStyle(color: t.textMuted)),
          onTap: () => context.push('/app/video/${v.id}', extra: v),
        );
      },
    );
  }

  Widget _listeCanaux(UniverseTokens t) {
    if (_canaux.isEmpty) {
      return _videeSiVide(
        _q.text.trim().isEmpty
            ? tr(context, 'Cherche un canal par nom ou par matière.')
            : tr(context, 'Aucun canal trouvé.'),
      );
    }
    return ListView.builder(
      itemCount: _canaux.length,
      itemBuilder: (_, i) {
        final r = _canaux[i];
        final couleur = UniverseColors.accentFor(r.canal.matiere);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: couleur.withValues(alpha: 0.18),
            child: Icon(Icons.forum_rounded, color: couleur, size: 18),
          ),
          title: Text(r.canal.nom),
          subtitle: Text('${r.universiteNom} · ${r.canal.matiere}',
              style: TextStyle(color: t.textMuted)),
          onTap: () => _ouvrirCanal(r),
        );
      },
    );
  }

  Widget _listeConversations(UniverseTokens t) {
    if (_conversations.isEmpty) {
      return _videeSiVide(
        _q.text.trim().isEmpty
            ? tr(context, 'Cherche une conversation par personne ou par message.')
            : tr(context, 'Aucune conversation trouvée.'),
      );
    }
    return ListView.builder(
      itemCount: _conversations.length,
      itemBuilder: (_, i) {
        final c = _conversations[i];
        return ListTile(
          leading: UniverseAvatar(
            initiale: (c.destinataireNom ?? '?'),
            photoUrl: c.destinatairePhotoUrl,
            backgroundColor: t.surfaceElevated,
          ),
          title: Text(c.destinataireNom ?? tr(context, 'Conversation')),
          subtitle: Text(
            c.dernierMessage ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: t.textMuted),
          ),
          onTap: () => context.push(
            '/app/conversation/${c.id}',
            extra: c.destinataireId == null
                ? null
                : Contact(
                    id: c.destinataireId!,
                    nom: c.destinataireNom ?? tr(context, 'Utilisateur'),
                    rang: c.destinataireRang,
                    photoUrl: c.destinatairePhotoUrl,
                  ),
          ),
        );
      },
    );
  }
}
