import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/role_access.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/draggable_ai_fab.dart';
import '../../core/widgets/universe_glass.dart';
import '../../core/widgets/universe_skeleton.dart';
import '../../core/widgets/universe_ui.dart';
import '../../shared/models/models.dart';
import '../creator/creator_surface.dart';

class VideoFeedPage extends ConsumerStatefulWidget {
  const VideoFeedPage({super.key});

  @override
  ConsumerState<VideoFeedPage> createState() => _VideoFeedPageState();
}

class _VideoFeedPageState extends ConsumerState<VideoFeedPage> {
  List<VideoItem> _videos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).get(
        '/videos/feed',
        queryParameters: {'limit': 20},
      );
      final raw = res.data;
      final list = raw is List
          ? raw
          : ((raw as Map)['items'] ?? raw['data'] ?? []) as List;
      setState(() {
        _videos = list
            .map((e) => VideoItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Feed indisponible';
      });
    }
  }

  Future<void> _toggleLike(VideoItem v) async {
    final api = ref.read(apiClientProvider);
    try {
      if (v.likedByMe) {
        await api.delete('/videos/${v.id}/like');
        setState(() {
          _videos = _videos
              .map((x) => x.id == v.id
                  ? x.copyWith(
                      likedByMe: false,
                      nombreLikes: (x.nombreLikes - 1).clamp(0, 1 << 30),
                    )
                  : x)
              .toList();
        });
      } else {
        await api.post('/videos/${v.id}/like');
        setState(() {
          _videos = _videos
              .map((x) => x.id == v.id
                  ? x.copyWith(likedByMe: true, nombreLikes: x.nombreLikes + 1)
                  : x)
              .toList();
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final acces = RoleAccess.depuis(ref.watch(authNotifierProvider).user);
    final peutPublier = acces.peutCreerContenu;
    final destinationPublication =
        CreatorSurfaceX.depuis(acces.rang).routePublier;

    return _contenu(
      context,
      publier: peutPublier && !_loading && _error == null
          ? () => context.push(destinationPublication)
          : null,
    );
  }

  Widget _contenu(BuildContext context, {VoidCallback? publier}) {
    if (_loading) return const VideoFeedSkeleton();
    if (_error != null) {
      return UniverseEmptyState(
        icon: Icons.cloud_off_rounded,
        title: tr(context, 'Feed indisponible'),
        message: tr(context, _error!),
        action: TextButton(
            onPressed: _load, child: Text(tr(context, 'Réessayer'))),
      );
    }
    if (_videos.isEmpty) {
      return UniverseEmptyState(
        icon: Icons.play_circle_outline_rounded,
        title: tr(context, 'Aucune vidéo pour l\'instant'),
        message: tr(context,
            'Rien pour ton niveau pour le moment — explore les canaux '
            'de ton université en attendant.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: UniverseColors.brandGradient,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('UniTube',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            actions: [
              if (publier != null)
                IconButton(
                  tooltip: tr(context, 'Publier une vidéo'),
                  icon: const Icon(Icons.video_call_outlined),
                  onPressed: publier,
                ),
              IconButton(
                tooltip: tr(context, 'Rechercher'),
                icon: const Icon(Icons.search),
                onPressed: () => context.push('/app/search'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: DraggableAiFab.degagement),
            sliver: SliverList.separated(
            itemCount: _videos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final v = _videos[i];
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Pressable(
                  onTap: () => context.push('/app/video/${v.id}', extra: v),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: context.tokens.surface.withValues(
                        alpha: context.isDark ? 0.4 : 0.7,
                      ),
                      border: Border.all(color: context.tokens.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                v.thumbnailUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: v.thumbnailUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) =>
                                            const UniverseSkeleton(height: 200),
                                        errorWidget: (_, __, ___) =>
                                            _MiniatureAbsente(video: v),
                                      )
                                    : _MiniatureAbsente(video: v),
                                if (v.dureeLabel.isNotEmpty)
                                  Positioned(
                                    right: 8,
                                    bottom: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.72),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        v.dureeLabel,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          v.titre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                v.createurNom ?? tr(context, 'Créateur'),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: context.tokens.textMuted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                            if (v.matiere != null) ...[
                              _MatiereChip(label: v.matiere!),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.visibility_outlined,
                                size: 14, color: context.tokens.textMuted),
                            const SizedBox(width: 4),
                            Text(v.vuesLabel,
                                style: TextStyle(
                                    color: context.tokens.textMuted,
                                    fontSize: 12.5)),
                            if (v.createdAt != null) ...[
                              Text(' · ',
                                  style: TextStyle(
                                      color: context.tokens.textMuted,
                                      fontSize: 12.5)),
                              Text(ilYA(context, v.createdAt!),
                                  style: TextStyle(
                                      color: context.tokens.textMuted,
                                      fontSize: 12.5)),
                            ],
                            const Spacer(),
                            IconButton(
                              onPressed: () => _toggleLike(v),
                              icon: Icon(
                                v.likedByMe
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: v.likedByMe
                                    ? UniverseColors.danger
                                    : context.tokens.textMuted,
                                size: 20,
                              ),
                            ),
                            Text('${v.nombreLikes}',
                                style:
                                    TextStyle(color: context.tokens.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          ),
        ],
      ),
    );
  }
}

/// Étiquette de matière/contexte, avec une couleur stable par libellé — c'est
/// ce qui donne au fil son air de vraie chaîne éditorialisée plutôt qu'un
/// flux anonyme monochrome.
class _MatiereChip extends StatelessWidget {
  const _MatiereChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final couleur = UniverseColors.accentFor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: couleur.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: couleur,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Remplace la miniature manquante par un dégradé de marque plutôt qu'un
/// texte technique ("Upload en cours…") — plus soigné, et cohérent que la
/// vidéo soit en cours de traitement ou simplement sans vignette.
class _MiniatureAbsente extends StatelessWidget {
  const _MiniatureAbsente({required this.video});

  final VideoItem video;

  @override
  Widget build(BuildContext context) {
    final couleur = UniverseColors.accentFor(video.matiere ?? video.titre);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [couleur.withValues(alpha: 0.85), UniverseColors.navy],
        ),
      ),
      child: const Center(
        child: Icon(Icons.play_circle_fill_rounded,
            size: 46, color: Colors.white70),
      ),
    );
  }
}

