import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../shared/models/models.dart';

/// Les rangs de la chaîne de contenu, du plus bas au plus haut.
///
/// Admin Université et Superadmin ont été retirés du front mobile : cette
/// administration se fait désormais depuis un site web séparé, hors
/// périmètre de cette application. Tuteur et Formateur TDS sont deux rôles
/// réels et distincts (avant, « tuteur » n'était qu'un flag booléen posé sur
/// un étudiant).
enum Rang {
  etudiant('etudiant', 'Étudiant'),
  tuteur('tuteur', 'Tuteur'),
  formateur('formateur', 'Formateur TDS'),
  enseignant('enseignant', 'Enseignant'),
  moderateur('moderateur', 'Modérateur');

  const Rang(this.cle, this.libelle);

  final String cle;
  final String libelle;

  static Rang depuis(String? cle) {
    // Valeurs backend qui n'existent pas telles quelles côté front.
    final normalisee = switch (cle) {
      'formateur_tds' => 'formateur',
      // L'administration se fait sur le site web ; sur mobile, ces comptes
      // disposent des capacités de modération.
      'admin_universite' || 'superadmin' => 'moderateur',
      _ => cle,
    };
    for (final r in Rang.values) {
      if (r.cle == normalisee) return r;
    }
    return Rang.etudiant;
  }

  /// Position dans la chaîne — sert **uniquement** aux capacités qui
  /// s'héritent en montant (signalements, ressources de canal).
  int get niveau => index;
}

/// Comment un utilisateur peut en contacter un autre (matrice §4.2 du CDC).
enum ModeContact {
  /// Conversation classique, bidirectionnelle, sans restriction.
  conversation,

  /// Conversation qui se ferme si l'enseignant ne répond pas sous 24 h.
  fenetreReponse,

  /// Pas de messagerie : uniquement un signalement asynchrone.
  signalement,

  /// Aucun canal de contact.
  interdit,
}

/// Ce qu'un utilisateur a le droit de faire, en un seul endroit.
///
/// Règle structurante du cahier des charges (DV-01) : les **capacités de
/// contenu** ne s'héritent PAS uniformément en montant dans la chaîne — le
/// Modérateur, bien que dernier de la chaîne, ne publie jamais de contenu
/// (il gère uniquement les signalements) — d'où une liste explicite plutôt
/// qu'un simple `>=` pour [peutCreerContenu]. La **messagerie** ne s'hérite
/// jamais non plus — chaque règle se teste au rang exact via
/// [modeContactVers].
class RoleAccess {
  const RoleAccess(this.rang, {this.badgeEnseignant = false, this.dossierEnseignant});

  factory RoleAccess.depuis(UserProfile? user) {
    var rang = Rang.depuis(user?.rang);
    // La qualification modérateur est un flag hors chaîne côté backend
    // (`estModerateur`) : elle donne les capacités de modération quel que
    // soit le rang porté.
    if ((user?.estModerateur ?? false) && rang.niveau < Rang.moderateur.niveau) {
      rang = Rang.moderateur;
    }
    return RoleAccess(
      rang,
      badgeEnseignant: user?.badgeEnseignant ?? false,
      dossierEnseignant: user?.dossierEnseignant,
    );
  }

  final Rang rang;
  final bool badgeEnseignant;

  /// Statut détaillé du dossier — `null` sauf pour un rang `enseignant`.
  final DossierEnseignantStatut? dossierEnseignant;

  /// Le rang **déclaré** (`rang`) peut différer du rang **effectif** : tant
  /// que son dossier n'est pas validé (§3 — processus de validation
  /// Enseignant), un Enseignant reste dans les faits un étudiant en version
  /// limitée. `badgeEnseignant` porte ce statut de validation — c'est lui
  /// que le formulaire d'inscription positionne à `false`, et que l'équipe
  /// bascule à `true` une fois le dossier (diplôme compris) approuvé.
  ///
  /// Toute capacité ou règle de messagerie doit se baser sur [effectif],
  /// jamais sur [rang] directement — sauf l'affichage qui veut explicitement
  /// distinguer « Enseignant en attente » (voir [estEnseignantEnAttente]).
  Rang get effectif =>
      (rang == Rang.enseignant && !badgeEnseignant) ? Rang.etudiant : rang;

  /// Dossier soumis (rang déclaré Enseignant) mais pas encore validé.
  bool get estEnseignantEnAttente => rang == Rang.enseignant && !badgeEnseignant;

  bool _auMoins(Rang minimum) => effectif.niveau >= minimum.niveau;

  // --------------------------------------------------------- Contenu

  /// Publier des vidéos sur un profil créateur (Tuteur, Formateur TDS,
  /// Enseignant validé). Le Modérateur en est explicitement exclu.
  bool get peutCreerContenu =>
      effectif == Rang.tuteur ||
      effectif == Rang.formateur ||
      effectif == Rang.enseignant;

  /// Publier des ressources dans un canal assigné.
  bool get peutPublierRessource => _auMoins(Rang.moderateur);

  /// Traiter les signalements reçus.
  bool get peutTraiterSignalements => _auMoins(Rang.moderateur);

  /// Masquer une vidéo en urgence — capacité de modération, pas
  /// d'administration (Admin Université a disparu du front).
  bool get peutMasquerVideo => peutTraiterSignalements;

  /// Déposer une demande de promotion. Cible possible : tuteur, formateur
  /// ou modérateur (jamais enseignant — accréditation vérifiée à part dès
  /// l'inscription — ni étudiant, qui n'est pas un objectif de demande).
  /// Un Enseignant n'a plus rien à demander : il est déjà au sommet.
  bool get peutDemanderStatut => rang != Rang.enseignant;

  /// A-t-il une console dédiée à son rôle ?
  bool get aUneConsole => peutCreerContenu || peutTraiterSignalements;

  // ----------------------------------------------------- Messagerie (exact)

  /// Seul l'Enseignant validé peut écrire à n'importe qui sans réciprocité
  /// (EN-3).
  bool get peutEcrireATous => effectif == Rang.enseignant;

  /// Canal de contact autorisé vers un destinataire donné.
  ///
  /// Ne jamais remplacer par une comparaison d'ordre : chaque ligne de la
  /// matrice est une règle explicite.
  ModeContact modeContactVers(Rang destinataire) {
    // L'Enseignant validé initie vers tout le monde, sans restriction
    // (EN-3, EN-4). Non validé, il suit les règles de l'étudiant ci-dessous.
    if (effectif == Rang.enseignant) return ModeContact.conversation;

    if (effectif == Rang.etudiant) {
      return switch (destinataire) {
        Rang.etudiant || Rang.tuteur || Rang.formateur =>
          ModeContact.conversation,
        Rang.enseignant => ModeContact.fenetreReponse,
        Rang.moderateur => ModeContact.signalement,
      };
    }

    // Entre pairs de même rang : conversation libre.
    if (effectif == destinataire) return ModeContact.conversation;

    // Tuteur / Formateur TDS → Étudiant : libre (accompagnement, suivi).
    if ((effectif == Rang.tuteur || effectif == Rang.formateur) &&
        destinataire == Rang.etudiant) {
      return ModeContact.conversation;
    }

    // Le reste n'est pas ouvert par la matrice ; le serveur reste l'autorité.
    return ModeContact.interdit;
  }

  /// Peut-on proposer un bouton « Envoyer un message » vers ce rang ?
  ///
  /// Le CDC (DV-03) exige que l'interface ne propose **même pas** d'ouvrir
  /// une conversation vers un Modérateur — seul le formulaire de
  /// signalement doit être accessible.
  bool peutOuvrirConversationVers(Rang destinataire) =>
      modeContactVers(destinataire) == ModeContact.conversation ||
      modeContactVers(destinataire) == ModeContact.fenetreReponse;

  bool peutSignalerA(Rang destinataire) =>
      modeContactVers(destinataire) == ModeContact.signalement;

  // ------------------------------------------------------------- Affichage

  /// Libellé du rôle tel qu'affiché à l'utilisateur (rang effectif : un
  /// Enseignant en attente de validation s'affiche comme Étudiant — le
  /// bandeau de statut du dossier porte l'information « en cours »).
  String get libelle => effectif.libelle;

  /// Couleur d'accent associée au rôle, pour le badge et les en-têtes.
  Color get couleur => switch (effectif) {
        Rang.etudiant => const Color(0xFF64748B),
        Rang.tuteur => const Color(0xFF0AA7F6),
        Rang.formateur => UniverseColors.blue,
        Rang.enseignant => UniverseColors.violet,
        Rang.moderateur => const Color(0xFF0EA5A5),
      };

  IconData get icone => switch (effectif) {
        Rang.etudiant => Icons.school_outlined,
        Rang.tuteur => Icons.groups_outlined,
        Rang.formateur => Icons.dashboard_customize_outlined,
        Rang.enseignant => Icons.verified_outlined,
        Rang.moderateur => Icons.shield_outlined,
      };

  /// Phrase qui résume le rôle, affichée en tête de console.
  String get resume => switch (effectif) {
        Rang.etudiant => 'Tu consultes les ressources et vidéos de ton niveau.',
        Rang.tuteur =>
          'Tu accompagnes un groupe d\'étudiants et publies tes propres vidéos.',
        Rang.formateur =>
          'Tu publies des vidéos pédagogiques sur ton profil créateur.',
        Rang.enseignant =>
          'Tu publies sous accréditation et peux écrire à n\'importe quel compte.',
        Rang.moderateur =>
          'Tu traites les signalements et publies les ressources des canaux qui te sont assignés.',
      };
}
