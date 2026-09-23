import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/auth/role_access.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../core/widgets/draggable_ai_fab.dart';
import '../../../core/widgets/universe_glass.dart';
import '../../../core/widgets/universe_ui.dart';
import '../../../shared/models/models.dart';
import '../../creator/creator_surface.dart';
import '../../roles/role_console_page.dart';

/// Tableau de bord d'accueil, propre à chaque rôle.
///
/// L'onglet Accueil ne montre plus la même chose à tout le monde :
///   - **Étudiant** : son espace universitaire (géré ailleurs, pas ici) ;
///   - **Tuteur** : son groupe et la publication de vidéos ;
///   - **Formateur TDS / Enseignant** : son espace créateur (publier, stats) ;
///   - **Modérateur** : sa file de signalements et ses canaux.
///
/// Chaque tableau met en avant **l'action principale du rôle** (le bouton que
/// l'utilisateur cherchait) puis des raccourcis en grille bento, sur un fond
/// en dégradé animé teinté de la couleur du rôle.
class RoleHome extends ConsumerWidget {
  const RoleHome({super.key, required this.acces});

  final RoleAccess acces;

  /// Vrai si ce rôle a un tableau de bord dédié (tout sauf l'étudiant simple).
  static bool aUnTableauDeBord(RoleAccess a) => a.rang != Rang.etudiant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nom = ref.watch(authNotifierProvider).user?.displayName ?? '';

    final Widget body;
    if (acces.estEnseignantEnAttente) {
      body = _EnseignantEnAttente(acces: acces);
    } else if (acces.peutTraiterSignalements) {
      body = _Moderation(acces: acces);
    } else if (acces.rang == Rang.tuteur) {
      body = _Tds(acces: acces);
    } else if (acces.rang == Rang.enseignant) {
      // Interface séparée et simplifiée (§6) : dossier validé, colonne
      // unique de tuiles pleine largeur au lieu de la grille bento à deux
      // colonnes des autres rôles créateurs.
      body = _EnseignantDashboard(acces: acces);
    } else if (acces.peutCreerContenu) {
      body = _Creator(acces: acces);
    } else {
      body = const SizedBox.shrink();
    }

    return AuraBackground(
      colors: [acces.couleur, UniverseColors.violet],
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            12,
            16,
            28 + DraggableAiFab.degagement,
          ),
          children: [
            _Header(acces: acces, nom: nom),
            const SizedBox(height: 20),
            body,
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- En-tête

class _Header extends StatelessWidget {
  const _Header({required this.acces, required this.nom});

  final RoleAccess acces;
  final String nom;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      accentColor: acces.couleur,
      blurred: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: acces.couleur.withValues(alpha: 0.22),
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
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                const SizedBox(height: 4),
                RoleBadge(acces: acces),
                const SizedBox(height: 8),
                Text(
                  acces.resume,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: context.tokens.textMuted,
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

// ------------------------------------------------------ Blocs réutilisables

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.sub,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String sub;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: UniverseColors.brandGradient,
          boxShadow: [
            BoxShadow(
              color: UniverseColors.violet.withValues(alpha: 0.32),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => SectionLabel(
        texte,
        padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
      );
}

/// Ligne de deux tuiles demi-largeur, espacées de 12.
class _BentoRow extends StatelessWidget {
  const _BentoRow({required this.gauche, required this.droite});

  final Widget gauche;
  final Widget droite;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final echelle = MediaQuery.textScalerOf(context).scale(1);
        // Deux tuiles côte à côte coupent le sous-titre dès que la colonne
        // est étroite ou que la police grandit. On empile alors.
        final empile = echelle >= 1.12 || c.maxWidth < 240;
        if (empile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              gauche,
              const SizedBox(height: 12),
              droite,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: gauche),
            const SizedBox(width: 12),
            Expanded(child: droite),
          ],
        );
      },
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: UniverseBanner(texte),
      );
}

// ------------------------------------------------------------- Dashboards

class _Creator extends StatelessWidget {
  const _Creator({required this.acces});

  final RoleAccess acces;

  @override
  Widget build(BuildContext context) {
    final estEnseignant = acces.rang == Rang.enseignant;
    final surface = CreatorSurfaceX.depuis(acces.rang);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PrimaryAction(
          label: tr(context, 'Publier une vidéo'),
          sub: estEnseignant
              ? tr(context, 'Sous ton accréditation d\'enseignant')
              : tr(context, 'Sur ton profil créateur UniVerse'),
          icon: Icons.video_call_rounded,
          onTap: () => context.push(surface.routePublier),
        ),
        _SectionLabel(tr(context, 'Mon espace créateur')),
        _BentoRow(
          gauche: BentoTile(
            icon: Icons.insights_outlined,
            titre: tr(context, 'Mes statistiques'),
            sousTitre: tr(context, 'Vues, likes et classement détaillé'),
            accentColor: acces.couleur,
            onTap: () => context.push(surface.routeStats),
          ),
          droite: BentoTile(
            icon: Icons.people_outline,
            titre: tr(context, 'Mes abonnés'),
            sousTitre: tr(context, 'Suivi de l\'engagement'),
            accentColor: acces.couleur,
            onTap: () => context.push(surface.routeAbonnes),
          ),
        ),
        _InfoBanner(
          estEnseignant
              ? tr(context,
                  'En tant qu\'enseignant, tu peux aussi écrire à n\'importe quel '
                  'compte et tu bénéficies de la fenêtre de réponse de 24 h.')
              : tr(context,
                  'Pense à activer ton compte créateur au premier passage dans '
                  '« Publier une vidéo ».'),
        ),
      ],
    );
  }
}

/// Tableau de bord de l'Enseignant validé (§6) : une seule colonne de
/// tuiles pleine largeur — pas de grille à deux colonnes — pour rester
/// simple à parcourir pour un public plus âgé. Combiné à la typographie
/// agrandie et à la barre de navigation dédiée d'[AppShell].
class _EnseignantDashboard extends StatelessWidget {
  const _EnseignantDashboard({required this.acces});

  final RoleAccess acces;

  @override
  Widget build(BuildContext context) {
    const surface = CreatorSurface.enseignant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PrimaryAction(
          label: tr(context, 'Publier une vidéo'),
          sub: tr(context, 'Sous ton accréditation d\'enseignant'),
          icon: Icons.video_call_rounded,
          onTap: () => context.push(surface.routePublier),
        ),
        _SectionLabel(tr(context, 'Mon espace créateur')),
        BentoTile(
          icon: Icons.insights_outlined,
          titre: tr(context, 'Mes statistiques'),
          sousTitre: tr(context, 'Vues, likes et classement détaillé'),
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
        _InfoBanner(
          tr(context,
              'En tant qu\'enseignant, tu peux aussi écrire à n\'importe quel '
              'compte et tu bénéficies de la fenêtre de réponse de 24 h.'),
        ),
      ],
    );
  }
}

class _Tds extends StatelessWidget {
  const _Tds({required this.acces});

  final RoleAccess acces;

  @override
  Widget build(BuildContext context) {
    const surface = CreatorSurface.tuteur;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PrimaryAction(
          label: tr(context, 'Publier une vidéo'),
          sub: tr(context, 'Téléversement direct pour ton groupe'),
          icon: Icons.video_call_rounded,
          onTap: () => context.push(surface.routePublier),
        ),
        _SectionLabel(tr(context, 'Mon groupe')),
        _BentoRow(
          gauche: BentoTile(
            icon: Icons.play_circle_outline,
            titre: tr(context, 'Mes vidéos'),
            sousTitre: tr(context, 'Ce que tu as déjà publié'),
            accentColor: acces.couleur,
            onTap: () => context.push(surface.routeVideos),
          ),
          droite: BentoTile(
            icon: Icons.insights_outlined,
            titre: tr(context, 'Mes statistiques'),
            sousTitre: tr(context, 'Vues, likes et classement détaillé'),
            accentColor: acces.couleur,
            onTap: () => context.push(surface.routeStats),
          ),
        ),
        const SizedBox(height: 12),
        _BentoRow(
          gauche: BentoTile(
            icon: Icons.people_outline,
            titre: tr(context, 'Mes abonnés'),
            sousTitre: tr(context, 'Suivi de l\'engagement'),
            accentColor: acces.couleur,
            onTap: () => context.push(surface.routeAbonnes),
          ),
          droite: BentoTile(
            icon: Icons.groups_outlined,
            titre: tr(context, 'Accompagnement'),
            sousTitre: tr(context, 'Suivi des étudiants de ton groupe'),
            accentColor: acces.couleur,
          ),
        ),
        _InfoBanner(
          tr(context,
              'Ton groupe est indépendant des universités. Tes vidéos sont '
              'visibles par les étudiants et les modérateurs — pas par les '
              'formateurs TDS ni les enseignants.'),
        ),
      ],
    );
  }
}

/// Enseignant dont le dossier n'est pas encore validé (§3) : le compte reste
/// un compte étudiant en version limitée. Le statut du dossier est toujours
/// visible, et les fonctionnalités réservées à l'enseignant sont montrées
/// verrouillées plutôt que masquées, avec une explication de ce qui les
/// débloque — texte simple et rassurant, le public enseignant étant souvent
/// plus âgé et moins familier avec ce genre de parcours.
class _EnseignantEnAttente extends StatelessWidget {
  const _EnseignantEnAttente({required this.acces});

  final RoleAccess acces;

  @override
  Widget build(BuildContext context) {
    final statut = acces.dossierEnseignant ?? DossierEnseignantStatut.soumis;
    final (icone, message) = switch (statut) {
      DossierEnseignantStatut.soumis => (
          Icons.hourglass_top_rounded,
          tr(context,
              'Ton dossier d\'enseignant a bien été reçu. Notre équipe l\'examine '
              'et te répond sous 2 à 3 jours ouvrables. Tu peux continuer à '
              'utiliser l\'application comme un étudiant en attendant.'),
        ),
      DossierEnseignantStatut.diplomeDemande => (
          Icons.school_rounded,
          tr(context,
              'Il ne manque plus qu\'une chose : envoie-nous ton diplôme le plus '
              'élevé. Dès qu\'il est reçu et vérifié, ton compte enseignant '
              'sera activé.'),
        ),
      DossierEnseignantStatut.valide => (
          Icons.verified_rounded,
          tr(context, 'Ton dossier est validé.'),
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassSurface(
          accentColor: acces.couleur,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, color: acces.couleur, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, statut.libelle),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: acces.couleur,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: context.tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _SectionLabel(tr(context, 'Fonctionnalités enseignant')),
        _BentoRow(
          gauche: BentoTile(
            icon: Icons.video_call_outlined,
            titre: tr(context, 'Publier une vidéo'),
            sousTitre: tr(context, 'Sous ton accréditation, une fois validée'),
            accentColor: acces.couleur,
            lockedLabel: tr(context, 'Après validation'),
          ),
          droite: BentoTile(
            icon: Icons.forum_outlined,
            titre: tr(context, 'Écrire à tous'),
            sousTitre: tr(context, 'Contacter n\'importe quel compte'),
            accentColor: acces.couleur,
            lockedLabel: tr(context, 'Après validation'),
          ),
        ),
      ],
    );
  }
}

class _Moderation extends StatelessWidget {
  const _Moderation({required this.acces});

  final RoleAccess acces;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PrimaryAction(
          label: tr(context, 'Traiter les signalements'),
          sub: tr(context, 'Problèmes remontés par les étudiants'),
          icon: Icons.campaign_rounded,
          onTap: () => context.push('/app/admin'),
        ),
        _SectionLabel(tr(context, 'Modération')),
        BentoTile(
          icon: Icons.post_add_outlined,
          titre: tr(context, 'Publier une ressource'),
          sousTitre: tr(context, 'Depuis un canal assigné — bouton + de l\'en-tête'),
          accentColor: acces.couleur,
          span: BentoSpan.full,
          onTap: () => context.push('/app/console'),
        ),
        const SizedBox(height: 12),
        BentoTile(
          icon: Icons.rule_folder_outlined,
          titre: tr(context, 'Historique des décisions'),
          sousTitre: tr(context, 'Signalements déjà traités'),
          accentColor: acces.couleur,
          span: BentoSpan.full,
          onTap: () => context.push('/app/admin'),
        ),
        _InfoBanner(
          tr(context,
              'En tant que Modérateur, tu ne publies pas de contenu : tu gères '
              'uniquement les signalements et les ressources des canaux qui te '
              'sont assignés.'),
        ),
      ],
    );
  }
}

