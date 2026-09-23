import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_erreur.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/universe_skeleton.dart';
import '../../shared/models/models.dart';

/// Détail des statistiques d'une vidéo, façon TikTok Studio — le niveau de
/// détail demandé (§ retour utilisateur). Vues/likes viennent du vrai
/// modèle ; partages, durée moyenne regardée et courbe de rétention viennent
/// de `GET /videos/:id/stats-detaillees` →
/// `{ partages, dureeMoyenneEcouteRatio, courbeRetention: number[] }`.
class VideoStatsDetailPage extends ConsumerStatefulWidget {
  const VideoStatsDetailPage({super.key, required this.video, required this.couleur});

  final VideoItem video;
  final Color couleur;

  @override
  ConsumerState<VideoStatsDetailPage> createState() => _VideoStatsDetailPageState();
}

class _VideoStatsDetailPageState extends ConsumerState<VideoStatsDetailPage> {
  bool _loading = true;
  String? _erreur;
  int? _partages;
  double? _dureeMoyenneEcouteRatio;
  List<double> _courbeRetention = const [];

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
          .get('/videos/${widget.video.id}/stats-detaillees');
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _partages = data['partages'] as int?;
        _dureeMoyenneEcouteRatio = (data['dureeMoyenneEcouteRatio'] as num?)?.toDouble();
        _courbeRetention = ((data['courbeRetention'] as List?) ?? [])
            .map((e) => (e as num).toDouble())
            .toList();
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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final video = widget.video;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Statistiques de la vidéo'))),
      body: _loading
          ? const ListTileSkeleton(count: 4)
          : _erreur != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_erreur!, textAlign: TextAlign.center),
                ))
              : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  video.titre,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                const SizedBox(height: 4),
                if (video.createdAt != null)
                  Text(
                    'Publiée ${ilYA(context, video.createdAt!)}',
                    style: TextStyle(fontSize: 12.5, color: t.textMuted),
                  ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.7,
                  children: [
                    _StatTile(
                      icon: Icons.visibility_outlined,
                      label: tr(context, 'Vues'),
                      valeur: video.vuesLabel.replaceAll(' vues', '').replaceAll(' vue', ''),
                      couleur: widget.couleur,
                    ),
                    _StatTile(
                      icon: Icons.thumb_up_outlined,
                      label: tr(context, 'Likes'),
                      valeur: '${video.nombreLikes}',
                      couleur: widget.couleur,
                    ),
                    _StatTile(
                      icon: Icons.share_outlined,
                      label: tr(context, 'Partages'),
                      valeur: _partages != null ? '$_partages' : '—',
                      couleur: widget.couleur,
                    ),
                    _StatTile(
                      icon: Icons.timer_outlined,
                      label: tr(context, 'Durée moyenne regardée'),
                      valeur: _dureeMoyenneEcouteRatio != null
                          ? '${(_dureeMoyenneEcouteRatio! * 100).toStringAsFixed(0)} %'
                          : '—',
                      couleur: widget.couleur,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  tr(context, 'COURBE DE RÉTENTION'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: t.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(context, 'Pourcentage de spectateurs encore présents au fil de la vidéo.'),
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 140,
                  child: _courbeRetention.isEmpty
                      ? Center(
                          child: Text(
                            tr(context, 'Pas encore assez de données.'),
                            style: TextStyle(fontSize: 12.5, color: t.textMuted),
                          ),
                        )
                      : CustomPaint(
                          size: Size.infinite,
                          painter: _RetentionPainter(
                            valeurs: _courbeRetention,
                            couleur: widget.couleur,
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.valeur,
    required this.couleur,
  });

  final IconData icon;
  final String label;
  final String valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: couleur),
          const SizedBox(height: 6),
          Text(
            valeur,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          Text(label, style: TextStyle(fontSize: 11.5, color: t.textMuted)),
        ],
      ),
    );
  }
}

class _RetentionPainter extends CustomPainter {
  const _RetentionPainter({required this.valeurs, required this.couleur});

  final List<double> valeurs;
  final Color couleur;

  @override
  void paint(Canvas canvas, Size size) {
    if (valeurs.isEmpty) return;
    final trait = Paint()
      ..color = couleur
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final remplissage = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [couleur.withValues(alpha: 0.28), couleur.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final pas = size.width / (valeurs.length - 1).clamp(1, 1 << 30);
    Offset point(int i) =>
        Offset(i * pas, size.height - valeurs[i] * size.height);

    final ligne = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < valeurs.length; i++) {
      final p0 = point(i - 1);
      final p1 = point(i);
      final milieu = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      ligne.quadraticBezierTo(p0.dx, p0.dy, milieu.dx, milieu.dy);
    }
    ligne.lineTo(point(valeurs.length - 1).dx, point(valeurs.length - 1).dy);

    final zone = Path.from(ligne)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(zone, remplissage);
    canvas.drawPath(ligne, trait);
  }

  @override
  bool shouldRepaint(covariant _RetentionPainter oldDelegate) =>
      oldDelegate.valeurs != valeurs || oldDelegate.couleur != couleur;
}
