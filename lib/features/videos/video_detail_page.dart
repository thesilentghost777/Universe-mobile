import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../app/theme.dart';
import '../signalements/signalement_sheet.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/role_access.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_erreur.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/universe_glass.dart';
import '../../core/widgets/universe_skeleton.dart';
import '../../core/widgets/universe_ui.dart';
import '../../shared/models/models.dart';

class VideoDetailPage extends ConsumerStatefulWidget {
  const VideoDetailPage({super.key, required this.video});

  final VideoItem video;

  @override
  ConsumerState<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends ConsumerState<VideoDetailPage> {
  YoutubePlayerController? _yt;
  final _commentCtrl = TextEditingController();
  final _commentFocus = FocusNode();
  List<Map<String, dynamic>> _comments = [];
  bool _loadingComments = true;
  String? _erreurCommentaires;
  late VideoItem _video = widget.video;

  List<VideoItem> _suggestions = [];
  bool _loadingSuggestions = true;

  bool _disliked = false;

  String? get _idYoutubeValide {
    final id = _video.youtubeId;
    if (id == null || id.isEmpty || id.startsWith('pending')) return null;
    return id;
  }

  @override
  void initState() {
    super.initState();
    final id = widget.video.youtubeId;
    // Sur le web, le pont JS de youtube_player_iframe ne s'initialise pas
    // de façon constante selon les navigateurs — on ouvre la vidéo sur
    // YouTube dans un nouvel onglet à la place (voir
    // _MiniatureLectureExterne).
    if (!kIsWeb &&
        id != null &&
        id.isNotEmpty &&
        !id.startsWith('pending')) {
      _yt = YoutubePlayerController.fromVideoId(
        videoId: id,
        autoPlay: false,
        params: const YoutubePlayerParams(showFullscreenButton: true),
      );
    }
    _disliked = widget.video.dislikedByMe;
    _loadComments();
    _chargerSuggestions();
  }

  Future<void> _chargerSuggestions() async {
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/videos/feed', queryParameters: {'limit': 20});
      final raw = res.data;
      final list = raw is List
          ? raw
          : ((raw as Map)['items'] ?? raw['data'] ?? []) as List;
      final toutes =
          list.map((e) => VideoItem.fromJson(e as Map<String, dynamic>)).toList();
      if (!mounted) return;
      setState(() {
        _suggestions = toutes.where((v) => v.id != _video.id).toList();
        _loadingSuggestions = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _loadComments() async {
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/videos/${widget.video.id}/commentaires');
      final list = res.data is List
          ? res.data as List
          : (res.data as Map)['items'] as List? ?? [];
      setState(() {
        _comments = list.cast<Map<String, dynamic>>();
        _loadingComments = false;
        _erreurCommentaires = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingComments = false;
        _erreurCommentaires = ApiErreur.depuis(e).message;
      });
    }
  }

  Future<void> _postComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await ref.read(apiClientProvider).post(
        '/videos/${widget.video.id}/commentaires',
        data: {'contenu': text},
      );
      _commentCtrl.clear();
      await _loadComments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErreur.depuis(e).message)),
      );
    }
  }

  Future<void> _toggleLike() async {
    HapticFeedback.selectionClick();
    final avant = _video;
    setState(() {
      _video = _video.copyWith(
        likedByMe: !avant.likedByMe,
        nombreLikes: avant.likedByMe
            ? avant.nombreLikes - 1
            : avant.nombreLikes + 1,
      );
      if (_video.likedByMe) _disliked = false;
    });
    try {
      final api = ref.read(apiClientProvider);
      if (avant.likedByMe) {
        await api.delete('/videos/${_video.id}/like');
      } else {
        await api.post('/videos/${_video.id}/like');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _video = avant;
          _disliked = avant.dislikedByMe;
        });
      }
    }
  }

  Future<void> _toggleDislike() async {
    HapticFeedback.selectionClick();
    final avant = _video;
    final etaitDislike = _disliked;
    setState(() {
      _disliked = !etaitDislike;
      if (_disliked && _video.likedByMe) {
        _video = _video.copyWith(
          likedByMe: false,
          dislikedByMe: true,
          nombreLikes: _video.nombreLikes - 1,
        );
      } else {
        _video = _video.copyWith(dislikedByMe: _disliked);
      }
    });
    try {
      final api = ref.read(apiClientProvider);
      if (etaitDislike) {
        await api.delete('/videos/${_video.id}/dislike');
      } else {
        await api.post('/videos/${_video.id}/dislike');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _video = avant;
          _disliked = etaitDislike;
        });
      }
    }
  }

  Future<void> _toggleAbonnement() async {
    final compteId = _video.compteCreateurId;
    if (compteId == null) return;
    HapticFeedback.selectionClick();
    final avant = _video;
    setState(() {
      _video = _video.copyWith(abonneParMoi: !avant.abonneParMoi);
    });
    try {
      final api = ref.read(apiClientProvider);
      if (avant.abonneParMoi) {
        await api.delete('/abonnements/$compteId');
      } else {
        await api.post('/abonnements/$compteId');
      }
    } catch (_) {
      if (mounted) setState(() => _video = avant);
    }
  }

  void _partager() {
    Clipboard.setData(
      ClipboardData(text: 'universe://video/${_video.id} — ${_video.titre}'),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr(context, 'Lien copié.'))),
    );
  }

  @override
  void dispose() {
    _yt?.close();
    _commentCtrl.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final abonne = _video.abonneParMoi;
    final couleurMatiere = UniverseColors.accentFor(_video.matiere);

    return Scaffold(
      appBar: AppBar(
        title: const Text('UniTube'),
        actions: [
          // Modération d'urgence : réservée au Modérateur.
          if (RoleAccess.depuis(ref.watch(authNotifierProvider).user)
              .peutMasquerVideo)
            IconButton(
              tooltip: tr(context, 'Masquer cette vidéo'),
              icon: const Icon(Icons.visibility_off_outlined),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(tr(context, 'Masquer cette vidéo ?')),
                    content: Text(
                      tr(context,
                          'Elle disparaîtra des fils et de la recherche. '
                          'Rien n\'est supprimé : le masquage est réversible.'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(tr(context, 'Annuler')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(tr(context, 'Masquer')),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                try {
                  await ref
                      .read(apiClientProvider)
                      .patch('/videos/${_video.id}/masquer');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr(context, 'Vidéo masquée.'))),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tr(context,
                              'Refusé : ce créateur ne relève pas de ton '
                              'université.'),
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          IconButton(
            tooltip: tr(context, 'Signaler cette vidéo'),
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => ouvrirSignalementContenu(
              context,
              type: 'video',
              cibleId: _video.id,
              titreContenu: _video.titre,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Sur un écran large (web/desktop), une largeur plein écran
          // donnerait une vidéo 16:9 démesurément haute et écraserait le
          // reste de la page hors du viewport — on la plafonne donc.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _yt != null
                ? YoutubePlayer(controller: _yt!)
                : (kIsWeb && _idYoutubeValide != null)
                    ? _MiniatureLectureExterne(
                        videoId: _idYoutubeValide!,
                        couleur: couleurMatiere,
                      )
                    : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          couleurMatiere.withValues(alpha: 0.85),
                          UniverseColors.violet.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.hourglass_top_rounded,
                            color: Colors.white, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          tr(context, 'Vidéo en cours de traitement…'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                    _video.titre,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, height: 1.3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      Text(
                        _video.vuesLabel,
                        style: TextStyle(fontSize: 12.5, color: t.textMuted),
                      ),
                      if (_video.createdAt != null) ...[
                        Text(' · ',
                            style: TextStyle(color: t.textMuted)),
                        Text(
                          ilYA(context, _video.createdAt!),
                          style: TextStyle(fontSize: 12.5, color: t.textMuted),
                        ),
                      ],
                      if ((_video.matiere ?? '').isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _MatiereTag(label: _video.matiere!, couleur: couleurMatiere),
                      ],
                    ],
                  ),
                ),
                // Actions façon YouTube : j'aime, ne pas aimer, partager,
                // commenter — scrollable pour rester lisible sur petit écran.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _ActionPill(
                        icon: _video.likedByMe
                            ? Icons.thumb_up_rounded
                            : Icons.thumb_up_outlined,
                        label: '${_video.nombreLikes}',
                        actif: _video.likedByMe,
                        onTap: _toggleLike,
                      ),
                      const SizedBox(width: 8),
                      _ActionPill(
                        icon: _disliked
                            ? Icons.thumb_down_rounded
                            : Icons.thumb_down_outlined,
                        label: '',
                        actif: _disliked,
                        onTap: _toggleDislike,
                      ),
                      const SizedBox(width: 8),
                      _ActionPill(
                        icon: Icons.share_outlined,
                        label: tr(context, 'Partager'),
                        onTap: _partager,
                      ),
                      const SizedBox(width: 8),
                      _ActionPill(
                        icon: Icons.mode_comment_outlined,
                        label: '${_comments.length}',
                        onTap: () => FocusScope.of(context)
                            .requestFocus(_commentFocus),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1),
                ),
                // Chaîne du créateur — identité + abonnement (mocké).
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      UniverseAvatar(
                        initiale: _video.createurNom ?? '?',
                        backgroundColor: couleurMatiere,
                        radius: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _video.createurNom ?? tr(context, 'Créateur UniVerse'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (_video.compteCreateurId != null)
                        OutlinedButton(
                          onPressed: _toggleAbonnement,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: abonne ? t.textMuted : Colors.white,
                            backgroundColor: abonne ? null : UniverseColors.blue,
                            side: abonne
                                ? BorderSide(color: t.border)
                                : BorderSide.none,
                          ),
                          child: Text(abonne ? tr(context, 'Abonné') : tr(context, 'S\'abonner')),
                        ),
                    ],
                  ),
                ),
                if (_video.description != null &&
                    _video.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Text(
                      _video.description!,
                      style: TextStyle(color: t.textMuted, height: 1.4),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Divider(height: 1),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(tr(context, 'Vidéos suggérées'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (_loadingSuggestions)
                  const ListTileSkeleton(count: 3)
                else if (_suggestions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      tr(context, 'Aucune suggestion pour l\'instant.'),
                      style: TextStyle(color: t.textMuted),
                    ),
                  )
                else
                  for (final s in _suggestions.take(10))
                    _CarteSuggestion(
                      video: s,
                      onTap: () => context
                          .pushReplacement('/app/video/${s.id}', extra: s),
                    ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(tr(context, 'Commentaires'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (_loadingComments)
                  const ListTileSkeleton(count: 4)
                else if (_erreurCommentaires != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(_erreurCommentaires!,
                        style: const TextStyle(color: UniverseColors.danger)),
                  )
                else if (_comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(tr(context, 'Sois le premier à commenter.'),
                        style: TextStyle(color: t.textMuted)),
                  )
                else
                  for (final c in _comments) _Commentaire(donnees: c),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: t.surfaceElevated,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: t.border),
                  ),
                  child: TextField(
                    controller: _commentCtrl,
                    focusNode: _commentFocus,
                    decoration: InputDecoration(
                      hintText: tr(context, 'Ajouter un commentaire'),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                    onSubmitted: (_) => _postComment(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _postComment,
                icon: const Icon(Icons.send_rounded),
                color: UniverseColors.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lecture externe (web) — miniature YouTube avec un bouton lecture qui
/// ouvre la vidéo dans un nouvel onglet, plutôt qu'un lecteur intégré. Après
/// plusieurs tentatives d'intégration (pont JS `youtube_player_iframe`, puis
/// un `<iframe>` maison via `HtmlElementView`), toutes deux se sont montrées
/// instables selon le navigateur — cette solution garantit que la vidéo est
/// réellement regardable, quitte à sortir de l'app.
class _MiniatureLectureExterne extends StatelessWidget {
  const _MiniatureLectureExterne({required this.videoId, required this.couleur});

  final String videoId;
  final Color couleur;

  Future<void> _ouvrir(BuildContext context) async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'Impossible d\'ouvrir la vidéo.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _ouvrir(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    couleur.withValues(alpha: 0.85),
                    UniverseColors.violet.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.18)),
          Center(
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.45),
                border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 14),
                const SizedBox(width: 5),
                Text(
                  tr(context, 'Regarder sur YouTube'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.actif = false,
  });

  final IconData icon;
  final String label;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: actif
              ? UniverseColors.blue.withValues(alpha: 0.16)
              : t.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: actif ? UniverseColors.blue : t.textMuted),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: actif ? UniverseColors.blue : t.textPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Carte compacte d'une vidéo suggérée — miniature à gauche, infos à
/// droite, façon « à suivre » YouTube plutôt que la grande carte du fil.
class _CarteSuggestion extends StatelessWidget {
  const _CarteSuggestion({required this.video, required this.onTap});

  final VideoItem video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Pressable(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 130,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      video.thumbnailUrl != null
                          ? CachedNetworkImage(
                              imageUrl: video.thumbnailUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, _) =>
                                  const UniverseSkeleton(height: 80),
                              errorWidget: (_, _, _) => Container(
                                color: UniverseColors.accentFor(video.matiere)
                                    .withValues(alpha: 0.3),
                              ),
                            )
                          : Container(
                              color: UniverseColors.accentFor(video.matiere)
                                  .withValues(alpha: 0.3),
                            ),
                      if (video.dureeLabel.isNotEmpty)
                        Positioned(
                          right: 5,
                          bottom: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              video.dureeLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.titre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.25),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.createurNom ?? tr(context, 'Créateur'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    video.createdAt != null
                        ? '${video.vuesLabel} · ${ilYA(context, video.createdAt!)}'
                        : video.vuesLabel,
                    style: TextStyle(fontSize: 11.5, color: t.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatiereTag extends StatelessWidget {
  const _MatiereTag({required this.label, required this.couleur});

  final String label;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: couleur,
        ),
      ),
    );
  }
}

class _Commentaire extends StatelessWidget {
  const _Commentaire({required this.donnees});

  final Map<String, dynamic> donnees;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = donnees['auteur'] as Map<String, dynamic>?;
    final nom = a != null
        ? '${a['prenom'] ?? ''} ${a['nom'] ?? ''}'.trim()
        : tr(context, 'Anonyme');
    final quand = donnees['createdAt'] is String
        ? DateTime.tryParse(donnees['createdAt'] as String)
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UniverseAvatar(
            initiale: nom.isEmpty ? '?' : nom,
            radius: 15,
            backgroundColor: t.surfaceElevated,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      nom.isEmpty ? tr(context, 'Anonyme') : nom,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    if (quand != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        ilYA(context, quand),
                        style: TextStyle(fontSize: 11, color: t.textMuted),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(donnees['contenu'] as String? ?? ''),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
