import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/role_access.dart';
import '../../core/i18n/locale_controller.dart';
import '../creator/creator_surface.dart';

/// Console de rôle — l'écran qui rend l'application différente selon qui
/// l'utilise.
///
/// Un seul écran, plusieurs visages : le Modérateur y trouve ses
/// signalements, le Formateur TDS et l'Enseignant leur espace créateur, le
/// Tuteur son groupe, l'étudiant une invitation à demander un statut.
///
/// Les entrées dont l'écran n'existe pas encore sont affichées **désactivées
/// et étiquetées**, plutôt que masquées : un rôle voit ainsi l'étendue réelle
/// de ses droits, et personne ne clique dans le vide.
class RoleConsolePage extends ConsumerWidget {
  const RoleConsolePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final acces = RoleAccess.depuis(user);
    final groupes = _groupes(context, acces);

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Mon espace'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _EnTeteRole(acces: acces, nom: user?.displayName ?? ''),
          const SizedBox(height: 24),
          for (final g in groupes) ...[
            _TitreSection(g.titre),
            for (final e in g.entrees) _Entree(entree: e),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }

  /// Construit les sections visibles pour ce rôle.
  List<_Groupe> _groupes(BuildContext context, RoleAccess a) {
    final groupes = <_Groupe>[];

    if (a.peutTraiterSignalements) {
      groupes.add(_Groupe(tr(context, 'Modération'), [
        _E(
          Icons.campaign_outlined,
          tr(context, 'Signalements reçus'),
          tr(context, 'Traiter les problèmes remontés par les étudiants'),
          route: '/app/admin',
        ),
        _E(
          Icons.visibility_off_outlined,
          tr(context, 'Masquer une vidéo'),
          tr(context, 'Depuis la vidéo concernée, via UniTube'),
          route: '/app/search',
        ),
        _E(
          Icons.post_add_outlined,
          tr(context, 'Publier une ressource'),
          tr(context, 'Depuis le canal concerné, bouton + de l\'en-tête'),
          route: '/app',
        ),
      ]));
    }

    if (a.peutCreerContenu) {
      final estTuteur = a.rang == Rang.tuteur;
      final surface = CreatorSurfaceX.depuis(a.rang);
      groupes.add(_Groupe(
        estTuteur ? tr(context, 'Mon groupe') : tr(context, 'Espace créateur'),
        [
          _E(
            Icons.video_call_outlined,
            tr(context, 'Publier une vidéo'),
            tr(context, 'Mise en ligne et métadonnées'),
            route: surface.routePublier,
          ),
          _E(
            Icons.play_circle_outline,
            tr(context, 'Mes vidéos'),
            tr(context, 'Ce que tu as déjà publié'),
            route: surface.routeVideos,
          ),
          _E(
            Icons.insights_outlined,
            tr(context, 'Mes statistiques'),
            tr(context, 'Vues, likes et classement détaillé'),
            route: surface.routeStats,
          ),
          _E(
            Icons.people_outline,
            tr(context, 'Mes abonnés'),
            tr(context, 'Nombre d\'abonnés et engagement'),
            route: surface.routeAbonnes,
          ),
        ],
      ));
    }

    if (a.peutDemanderStatut) {
      groupes.add(_Groupe(tr(context, 'Aller plus loin'), [
        _E(
          Icons.workspace_premium_outlined,
          tr(context, 'Devenir formateur ou enseignant'),
          tr(context, 'Publier tes propres vidéos sur la plateforme'),
          route: '/app/demandes',
        ),
      ]));
    }

    return groupes;
  }
}

class _EnTeteRole extends StatelessWidget {
  const _EnTeteRole({required this.acces, required this.nom});

  final RoleAccess acces;
  final String nom;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: acces.couleur.withValues(alpha: 0.35)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            acces.couleur.withValues(alpha: 0.16),
            acces.couleur.withValues(alpha: 0.03),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: acces.couleur.withValues(alpha: 0.20),
            ),
            child: Icon(acces.icone, color: acces.couleur),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (nom.isNotEmpty)
                  Text(
                    nom,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                const SizedBox(height: 2),
                RoleBadge(acces: acces),
                const SizedBox(height: 8),
                Text(
                  acces.resume,
                  style: TextStyle(fontSize: 13, color: t.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille de rôle, réutilisable partout (profil, en-tête, listes).
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.acces, this.compact = false});

  final RoleAccess acces;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: acces.couleur.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (acces.rang == Rang.enseignant && acces.badgeEnseignant) ...[
            Icon(Icons.verified, size: compact ? 11 : 13, color: acces.couleur),
            const SizedBox(width: 4),
          ],
          Text(
            acces.estEnseignantEnAttente
                ? tr(context, 'Enseignant — en attente')
                : acces.libelle,
            style: TextStyle(
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              color: acces.couleur,
            ),
          ),
        ],
      ),
    );
  }
}

class _Groupe {
  const _Groupe(this.titre, this.entrees);

  final String titre;
  final List<_E> entrees;
}

class _E {
  const _E(this.icone, this.titre, this.sousTitre, {this.route});

  final IconData icone;
  final String titre;
  final String sousTitre;

  /// `null` = écran pas encore développé.
  final String? route;

  bool get disponible => route != null;
}

class _Entree extends StatelessWidget {
  const _Entree({required this.entree});

  final _E entree;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final actif = entree.disponible;

    return Opacity(
      opacity: actif ? 1 : 0.55,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(entree.icone, color: t.textMuted),
          title: Text(
            entree.titre,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            entree.sousTitre,
            style: TextStyle(fontSize: 12, color: t.textMuted),
          ),
          trailing: actif
              ? const Icon(Icons.chevron_right_rounded)
              : Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: t.border),
                  ),
                  child: Text(
                    tr(context, 'À venir'),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: t.textMuted,
                    ),
                  ),
                ),
          onTap: actif ? () => context.push(entree.route!) : null,
        ),
      ),
    );
  }
}

class _TitreSection extends StatelessWidget {
  const _TitreSection(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        texte.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: context.tokens.textMuted,
        ),
      ),
    );
  }
}
