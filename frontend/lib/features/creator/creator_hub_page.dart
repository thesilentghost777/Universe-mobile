import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `StateProvider` est déprécié depuis Riverpod 3 et vit désormais dans cet
// import dédié ; il reste pris en charge.
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/role_access.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/services/media_service.dart';
import '../../core/widgets/universe_glass.dart';
import '../../core/widgets/universe_ui.dart';
import '../roles/role_console_page.dart';
import 'creator_surface.dart';

/// Bannière de chaîne choisie localement — aucun endpoint d'upload dédié
/// n'existe encore côté back (même situation que `photoProfilLocaleProvider`
/// pour la photo de profil : contrat à transmettre, `POST
/// /storage/presign/upload` sur un bucket `bannieres` puis `PATCH
/// /comptes-createurs/moi { banniereCle }`).
final chaineBanniereLocaleProvider = StateProvider<Uint8List?>((_) => null);

/// Espace créateur — hub qui mène vers la publication, les statistiques et
/// les abonnés (§ retour utilisateur : ces trois entrées renvoyaient
/// auparavant toutes vers cet unique écran, ce qui n'avait aucun sens).
///
/// Ouvert au Formateur TDS et à l'Enseignant. Le Tuteur a son propre hub
/// (`/app/groupe-tds`), et le Modérateur ne publie jamais de contenu.
class CreatorHubPage extends ConsumerStatefulWidget {
  const CreatorHubPage({super.key});

  @override
  ConsumerState<CreatorHubPage> createState() => _CreatorHubPageState();
}

class _CreatorHubPageState extends ConsumerState<CreatorHubPage> {
  int _mesVideos = 0;
  int _totalLikes = 0;
  bool _loading = true;
  bool _compteActif = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _choisirBanniere() async {
    const media = MediaService();
    final res = await media.choisirImage();
    if (!res.estValide) return;
    ref.read(chaineBanniereLocaleProvider.notifier).state = res.octets;
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/videos/feed', queryParameters: {'limit': 100});
      final raw = res.data;
      final list = raw is List
          ? raw
          : ((raw as Map)['items'] ?? raw['data'] ?? []) as List;
      final userId = ref.read(authNotifierProvider).user?.id;
      final miennes = list.where((v) {
        final createur = (v as Map)['compteCreateur'] as Map?;
        final u = createur?['utilisateur'] as Map?;
        return u?['id'] == userId;
      }).toList();
      final likes = miennes.fold<int>(
        0,
        (s, v) => s + (((v as Map)['nombreLikes'] as num?)?.toInt() ?? 0),
      );
      if (!mounted) return;
      setState(() {
        _mesVideos = miennes.length;
        _totalLikes = likes;
        if (miennes.isNotEmpty) _compteActif = true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _activerCompte() async {
    try {
      await ref.read(apiClientProvider).post('/compte-createur', data: {});
      if (mounted) setState(() => _compteActif = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _compteActif = true;
          _status = tr(context, 'Compte déjà existant, ou rang insuffisant.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final acces = RoleAccess.depuis(ref.watch(authNotifierProvider).user);
    final user = ref.watch(authNotifierProvider).user;
    final banniere = ref.watch(chaineBanniereLocaleProvider);
    final surface = CreatorSurfaceX.depuis(acces.rang);

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Espace créateur'))),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
          children: [
            ChannelHeader(
              acces: acces,
              nom: user?.displayName ?? tr(context, 'Ma chaîne'),
              photoUrl: user?.photoUrl,
              banniere: banniere,
              onChangerBanniere: _choisirBanniere,
              sousTitre: acces.rang == Rang.enseignant
                  ? tr(context, 'Tu publies sous ton accréditation d\'enseignant.')
                  : tr(context, 'Tu publies des vidéos sur ton profil créateur.'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loading)
                    const LinearProgressIndicator()
                  else
                    Row(
                      children: [
                        _StatCard(
                          label: tr(context, 'Vidéos'),
                          valeur: '$_mesVideos',
                          accentColor: acces.couleur,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: tr(context, 'Likes reçus'),
                          valeur: '$_totalLikes',
                          accentColor: acces.couleur,
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  if (!_compteActif) ...[
                    UniverseBanner(
                      tr(context, 'Active ton compte créateur pour que tes vidéos te '
                      'soient attribuées.'),
                      action: TextButton(
                        onPressed: _activerCompte,
                        child: Text(tr(context, 'Activer')),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (_status != null) ...[
                    UniverseBanner(_status!),
                    const SizedBox(height: 20),
                  ],
                  BentoTile(
                    icon: Icons.rocket_launch_outlined,
                    titre: tr(context, 'Publier une vidéo'),
                    sousTitre: tr(context, 'Miniature, matière, visibilité — l\'écran complet'),
                    accentColor: acces.couleur,
                    span: BentoSpan.full,
                    onTap: () => context.push(surface.routePublier),
                  ),
                  const SizedBox(height: 12),
                  BentoTile(
                    icon: Icons.play_circle_outline,
                    titre: tr(context, 'Mes vidéos'),
                    sousTitre: tr(context, 'Ce que tu as déjà publié'),
                    accentColor: acces.couleur,
                    span: BentoSpan.full,
                    onTap: () => context.push(surface.routeVideos),
                  ),
                  const SizedBox(height: 12),
                  BentoTile(
                    icon: Icons.insights_outlined,
                    titre: tr(context, 'Mes statistiques'),
                    sousTitre: tr(context, 'Vues, likes et classement détaillé par vidéo'),
                    accentColor: acces.couleur,
                    span: BentoSpan.full,
                    onTap: () => context.push(surface.routeStats),
                  ),
                  const SizedBox(height: 12),
                  BentoTile(
                    icon: Icons.people_outline,
                    titre: tr(context, 'Mes abonnés'),
                    sousTitre: tr(context, 'Suivi de l\'engagement'),
                    accentColor: acces.couleur,
                    span: BentoSpan.full,
                    onTap: () => context.push(surface.routeAbonnes),
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

/// En-tête façon YouTube Studio : bannière pleine largeur (modifiable),
/// avatar en débord, identité de la chaîne juste en dessous. Public — aussi
/// réutilisé par [CreatorVideosPage] pour le Tuteur, qui n'a pas de hub
/// créateur dédié mais publie tout autant.
class ChannelHeader extends StatelessWidget {
  const ChannelHeader({
    super.key,
    required this.acces,
    required this.nom,
    required this.sousTitre,
    required this.onChangerBanniere,
    this.photoUrl,
    this.banniere,
  });

  final RoleAccess acces;
  final String nom;
  final String sousTitre;
  final String? photoUrl;
  final Uint8List? banniere;
  final VoidCallback onChangerBanniere;

  static const double _hauteurBanniere = 118;
  static const double _rayonAvatar = 34;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: onChangerBanniere,
              child: Container(
                height: _hauteurBanniere,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: banniere == null
                      ? LinearGradient(
                          colors: [
                            acces.couleur.withValues(alpha: 0.55),
                            UniverseColors.violet.withValues(alpha: 0.55),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  image: banniere != null
                      ? DecorationImage(
                          image: MemoryImage(banniere!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Material(
                color: Colors.black.withValues(alpha: 0.45),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onChangerBanniere,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.edit_outlined,
                        size: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: -_rayonAvatar,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.canvas,
                ),
                child: UniverseAvatar(
                  initiale: nom,
                  photoUrl: photoUrl,
                  radius: _rayonAvatar,
                  backgroundColor: acces.couleur,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(16 + _rayonAvatar * 2 + 12, 10, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nom,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 2),
              RoleBadge(acces: acces),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            sousTitre,
            style: TextStyle(fontSize: 12.5, color: t.textMuted),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.valeur,
    required this.accentColor,
  });

  final String label;
  final String valeur;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Expanded(
      child: GlassSurface(
        accentColor: accentColor,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        borderRadius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              valeur,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: t.textMuted)),
          ],
        ),
      ),
    );
  }
}
