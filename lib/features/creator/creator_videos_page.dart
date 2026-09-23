import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/role_access.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/services/media_service.dart';
import '../../core/widgets/universe_skeleton.dart';
import '../../core/widgets/universe_ui.dart';
import '../../shared/models/models.dart';
import 'creator_hub_page.dart' show ChannelHeader, chaineBanniereLocaleProvider;
import 'creator_surface.dart';
import 'video_stats_detail_page.dart';

/// « Mes vidéos » — uniquement consultation et statistiques, jamais de
/// publication ici (§ retour utilisateur : le Tuteur en particulier ne
/// doit pas voir de bouton publier sur cet écran).
class CreatorVideosPage extends ConsumerStatefulWidget {
  const CreatorVideosPage({super.key, required this.surface, this.infoBanner});

  final CreatorSurface surface;

  /// Bandeau d'explication optionnel affiché en tête (ex. spécificités du
  /// groupe TDS du Tuteur).
  final String? infoBanner;

  @override
  ConsumerState<CreatorVideosPage> createState() => _CreatorVideosPageState();
}

class _CreatorVideosPageState extends ConsumerState<CreatorVideosPage> {
  List<VideoItem> _videos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _choisirBanniere() async {
    const media = MediaService();
    final res = await media.choisirImage();
    if (!res.estValide) return;
    ref.read(chaineBanniereLocaleProvider.notifier).state = res.octets;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/videos/feed', queryParameters: {'limit': 100});
      final raw = res.data;
      final list =
          raw is List ? raw : ((raw as Map)['items'] ?? raw['data'] ?? []) as List;
      final userId = ref.read(authNotifierProvider).user?.id;
      final toutes =
          list.map((e) => VideoItem.fromJson(e as Map<String, dynamic>)).toList();
      final miennes = toutes.where((v) => _estMienne(v, userId)).toList();
      if (!mounted) return;
      setState(() {
        _videos = miennes;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Le filtrage précis par créateur dépend du rôle : ce filtrage client
  // reste approximatif tant que `/videos/feed` ne propose pas un paramètre
  // `mesVideos=true` (contrat à transmettre).
  bool _estMienne(VideoItem v, String? userId) =>
      userId != null && v.createurNom != null;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final couleur = widget.surface.couleur;
    // Le Tuteur n'a pas de hub créateur dédié (à la différence du Formateur
    // TDS et de l'Enseignant, qui ont déjà leur bannière sur CreatorHubPage)
    // — sa chaîne, et donc sa bannière, se règlent ici.
    final estTuteur = widget.surface == CreatorSurface.tuteur;
    final acces = RoleAccess.depuis(ref.watch(authNotifierProvider).user);
    final user = ref.watch(authNotifierProvider).user;
    final banniere = ref.watch(chaineBanniereLocaleProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Mes vidéos'))),
      body: Column(
        children: [
          if (estTuteur)
            ChannelHeader(
              acces: acces,
              nom: user?.displayName ?? tr(context, 'Mon groupe'),
              photoUrl: user?.photoUrl,
              banniere: banniere,
              onChangerBanniere: _choisirBanniere,
              sousTitre: tr(context, 'Tu publies tes vidéos sous ton groupe TDS.'),
            ),
          Expanded(
            child: _loading
                ? const ListTileSkeleton(count: 5)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _videos.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 60),
                              UniverseEmptyState(
                                icon: Icons.video_library_outlined,
                                title: tr(context, 'Aucune vidéo publiée'),
                                message: tr(context, 'Tes vidéos apparaîtront ici une fois '
                                    'publiées.'),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(14),
                      itemCount: _videos.length + (widget.infoBanner != null ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, indexBrut) {
                        if (widget.infoBanner != null) {
                          if (indexBrut == 0) {
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: couleur.withValues(alpha: 0.08),
                                border: Border.all(color: couleur.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.groups_outlined, color: couleur),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      widget.infoBanner!,
                                      style: TextStyle(fontSize: 12.5, color: t.textMuted),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                        final i = widget.infoBanner != null ? indexBrut - 1 : indexBrut;
                        final v = _videos[i];
                        return Material(
                          color: t.surfaceElevated,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => VideoStatsDetailPage(
                                  video: v,
                                  couleur: couleur,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 68,
                                    height: 44,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      gradient: LinearGradient(
                                        colors: [
                                          couleur.withValues(alpha: 0.7),
                                          UniverseColors.violet
                                              .withValues(alpha: 0.7),
                                        ],
                                      ),
                                    ),
                                    child: const Icon(Icons.play_arrow_rounded,
                                        color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          v.titre,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.visibility_outlined,
                                                size: 13, color: t.textMuted),
                                            const SizedBox(width: 3),
                                            Text(v.vuesLabel,
                                                style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: t.textMuted)),
                                            const SizedBox(width: 10),
                                            Icon(Icons.thumb_up_outlined,
                                                size: 13, color: t.textMuted),
                                            const SizedBox(width: 3),
                                            Text('${v.nombreLikes}',
                                                style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: t.textMuted)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded,
                                      color: t.textMuted),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
