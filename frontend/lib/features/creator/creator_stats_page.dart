import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/widgets/universe_glass.dart';
import '../../core/widgets/universe_skeleton.dart';
import '../../shared/models/models.dart';
import 'creator_surface.dart';
import 'video_stats_detail_page.dart';

/// Vue d'ensemble des statistiques du compte créateur — total, puis
/// classement des vidéos par performance (§ retour utilisateur : stats les
/// plus détaillées possible, façon TikTok).
class CreatorStatsPage extends ConsumerStatefulWidget {
  const CreatorStatsPage({super.key, required this.surface});

  final CreatorSurface surface;

  @override
  ConsumerState<CreatorStatsPage> createState() => _CreatorStatsPageState();
}

enum _Periode { sept, trente, tout }

class _CreatorStatsPageState extends ConsumerState<CreatorStatsPage> {
  List<VideoItem> _videos = [];
  bool _loading = true;
  _Periode _periode = _Periode.tout;

  @override
  void initState() {
    super.initState();
    _load();
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
      final miennes = toutes.where((v) => userId != null && v.createurNom != null).toList()
        ..sort((a, b) => b.nombreVues.compareTo(a.nombreVues));
      if (!mounted) return;
      setState(() {
        _videos = miennes;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<VideoItem> get _videosPeriode {
    if (_periode == _Periode.tout) return _videos;
    final jours = _periode == _Periode.sept ? 7 : 30;
    final seuil = DateTime.now().subtract(Duration(days: jours));
    return _videos
        .where((v) => v.createdAt != null && v.createdAt!.isAfter(seuil))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final couleur = widget.surface.couleur;
    final videos = _videosPeriode;
    final totalVues = videos.fold<int>(0, (s, v) => s + v.nombreVues);
    final totalLikes = videos.fold<int>(0, (s, v) => s + v.nombreLikes);
    final maxVues = videos.isEmpty
        ? 0
        : videos.map((v) => v.nombreVues).reduce((a, b) => a > b ? a : b);
    final meilleure = videos.isEmpty ? null : videos.first;

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Mes statistiques'))),
      body: _loading
          ? const ListTileSkeleton(count: 5)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SelecteurPeriode(
                    valeur: _periode,
                    couleur: couleur,
                    onChange: (p) => setState(() => _periode = p),
                  ),
                  const SizedBox(height: 14),
                  if (meilleure != null) ...[
                    _MeilleureVideo(
                      video: meilleure,
                      couleur: couleur,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VideoStatsDetailPage(
                            video: meilleure,
                            couleur: couleur,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Row(
                    children: [
                      _Carte(label: tr(context, 'Vidéos'), valeur: '${videos.length}', couleur: couleur),
                      const SizedBox(width: 10),
                      _Carte(label: tr(context, 'Vues totales'), valeur: '$totalVues', couleur: couleur),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _Carte(label: tr(context, 'Likes totaux'), valeur: '$totalLikes', couleur: couleur),
                      const SizedBox(width: 10),
                      _Carte(
                        label: tr(context, 'Taux d\'engagement'),
                        valeur: totalVues == 0
                            ? '—'
                            : '${((totalLikes / totalVues) * 100).toStringAsFixed(1)} %',
                        couleur: couleur,
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Text(
                    tr(context, 'CLASSEMENT DE TES VIDÉOS'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: t.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (videos.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        tr(context, 'Aucune donnée pour cette période.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.textMuted),
                      ),
                    )
                  else
                    for (var i = 0; i < videos.length; i++)
                      _LigneClassement(
                        rang: i + 1,
                        video: videos[i],
                        couleur: couleur,
                        proportion: maxVues == 0 ? 0 : videos[i].nombreVues / maxVues,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VideoStatsDetailPage(
                              video: videos[i],
                              couleur: couleur,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

/// Filtre de période — purement client (le back ne renvoie pas encore de
/// séries temporelles ; **contrat à transmettre** : `GET
/// /videos/feed?depuis=` + horodatage ISO 8601, pour de vraies statistiques
/// par période).
class _SelecteurPeriode extends StatelessWidget {
  const _SelecteurPeriode({
    required this.valeur,
    required this.couleur,
    required this.onChange,
  });

  final _Periode valeur;
  final Color couleur;
  final ValueChanged<_Periode> onChange;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final labels = {
      _Periode.sept: tr(context, '7 jours'),
      _Periode.trente: tr(context, '30 jours'),
      _Periode.tout: tr(context, 'Tout'),
    };
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          for (final p in _Periode.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChange(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p == valeur ? couleur.withValues(alpha: 0.16) : null,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    labels[p]!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: p == valeur ? couleur : t.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Vidéo la plus vue de la période — mise en avant pour valoriser le
/// contenu qui marche, façon carte « meilleure performance ».
class _MeilleureVideo extends StatelessWidget {
  const _MeilleureVideo({
    required this.video,
    required this.couleur,
    required this.onTap,
  });

  final VideoItem video;
  final Color couleur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                couleur.withValues(alpha: 0.22),
                UniverseColors.violet.withValues(alpha: 0.14),
              ],
            ),
            border: Border.all(color: couleur.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: couleur.withValues(alpha: 0.2),
                ),
                child: Icon(Icons.emoji_events_rounded, color: couleur),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'Meilleure vidéo de la période'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: couleur,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      video.titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${video.vuesLabel} · ${video.nombreLikes} ${tr(context, 'likes')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: couleur),
            ],
          ),
        ),
      ),
    );
  }
}

class _Carte extends StatelessWidget {
  const _Carte({required this.label, required this.valeur, required this.couleur});

  final String label;
  final String valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassSurface(
        accentColor: couleur,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        borderRadius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(valeur,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11.5, color: context.tokens.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _LigneClassement extends StatelessWidget {
  const _LigneClassement({
    required this.rang,
    required this.video,
    required this.couleur,
    required this.proportion,
    required this.onTap,
  });

  final int rang;
  final VideoItem video;
  final Color couleur;

  /// Vues de cette vidéo relatives à la plus vue de la période (0 à 1) —
  /// dessine une barre proportionnelle, plus lisible qu'un simple chiffre
  /// pour comparer les vidéos entre elles d'un coup d'œil.
  final double proportion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: t.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        '$rang',
                        style: TextStyle(fontWeight: FontWeight.w800, color: couleur),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        video.titre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(video.vuesLabel,
                        style: TextStyle(fontSize: 12, color: t.textMuted)),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: t.textMuted, size: 18),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: proportion.clamp(0, 1)),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, __) => LinearProgressIndicator(
                        value: v,
                        minHeight: 5,
                        backgroundColor: t.border,
                        valueColor: AlwaysStoppedAnimation(couleur),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
