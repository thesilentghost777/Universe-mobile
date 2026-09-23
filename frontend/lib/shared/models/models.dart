import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Statut du dossier de validation Enseignant (§3 du cahier des charges).
///
/// **Contrat à transmettre au back** : le champ `badgeEnseignant` (bool)
/// existant ne distingue pas « en cours d'examen » de « diplôme demandé ».
/// Un futur champ `dossierEnseignant: 'soumis'|'diplome_demande'|'valide'`
/// sur `/auth/me` permettrait d'afficher le bon libellé. En son absence, on
/// déduit une valeur raisonnable depuis `badgeEnseignant`.
enum DossierEnseignantStatut {
  soumis('soumis', 'Dossier en cours d\'examen'),
  diplomeDemande('diplome_demande', 'Diplôme demandé'),
  valide('valide', 'Validé');

  const DossierEnseignantStatut(this.cle, this.libelle);

  final String cle;
  final String libelle;

  static DossierEnseignantStatut depuis(String? cle, {required bool badge}) {
    for (final s in DossierEnseignantStatut.values) {
      if (s.cle == cle) return s;
    }
    return badge ? DossierEnseignantStatut.valide : DossierEnseignantStatut.soumis;
  }
}

class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.email,
    required this.nom,
    required this.prenom,
    required this.rang,
    this.niveauId,
    this.badgeEnseignant = false,
    this.dossierEnseignant,
    this.emailVerifie = true,
    this.photoUrl,
    this.bio,
    this.identifiant,
    this.telephone,
    this.statutCompte = 'actif',
    this.estTuteur = false,
    this.estModerateur = false,
    this.compteCreateurId,
    this.nombreAbonnes = 0,
    this.groupeTdsId,
    this.groupeTdsNom,
  });

  final String id;
  final String email;
  final String nom;
  final String prenom;
  final String rang;
  final String? niveauId;
  final bool badgeEnseignant;

  /// Téléphone au format E.164, renvoyé par `/auth/me` pour un compte OTP.
  final String? telephone;

  /// `actif` | `demo` | `suspendu` — un compte `demo` (formateur TDS ou
  /// enseignant en attente de validation Superadmin) reste limité.
  final String statutCompte;

  /// Tuteur d'un Groupe TDS (flag hors chaîne de rangs, backend `estTuteur`).
  final bool estTuteur;

  /// Qualification modérateur (flag hors chaîne, backend `estModerateur`).
  final bool estModerateur;

  /// Compte créateur (rang >= formateur_tds), renvoyé par `/utilisateurs/:id`.
  final String? compteCreateurId;
  final int nombreAbonnes;

  /// Groupe TDS dont je suis le tuteur (renvoyé par `/utilisateurs/:id`).
  final String? groupeTdsId;
  final String? groupeTdsNom;

  /// Identifiant public choisi à l'inscription — c'est par lui qu'un compte
  /// qui ne te connaît pas encore peut initier une conversation (voir
  /// `ouvrirNouveauMessage`).
  final String? identifiant;

  /// `null` sauf pour un rang `enseignant`.
  final DossierEnseignantStatut? dossierEnseignant;
  final bool emailVerifie;

  /// Photo de profil : `POST /storage/presign/identite` puis
  /// `PATCH /utilisateurs/moi/identite { photoProfilCle }`.
  final String? photoUrl;

  /// Présentation publique : `PATCH /utilisateurs/moi/profil { bio }`,
  /// aussi renvoyée par `GET /utilisateurs/:id`.
  final String? bio;

  String get displayName => '$prenom $nom'.trim();

  bool get needsOnboarding =>
      rang == 'etudiant' && (niveauId == null || niveauId!.isEmpty);

  UserProfile copyWith({String? photoUrl, String? bio}) => UserProfile(
        id: id,
        email: email,
        nom: nom,
        prenom: prenom,
        rang: rang,
        niveauId: niveauId,
        badgeEnseignant: badgeEnseignant,
        dossierEnseignant: dossierEnseignant,
        emailVerifie: emailVerifie,
        photoUrl: photoUrl ?? this.photoUrl,
        bio: bio ?? this.bio,
        identifiant: identifiant,
        telephone: telephone,
        statutCompte: statutCompte,
        estTuteur: estTuteur,
        estModerateur: estModerateur,
        compteCreateurId: compteCreateurId,
        nombreAbonnes: nombreAbonnes,
        groupeTdsId: groupeTdsId,
        groupeTdsNom: groupeTdsNom,
      );

  /// Normalise le rang backend vers le rang d'affichage du front :
  /// - `formateur_tds` → `formateur` ;
  /// - `admin_universite` / `superadmin` → `moderateur` (capacités de
  ///   modération sur mobile, l'administration se fait sur le site web) ;
  /// - un étudiant tuteur d'un Groupe TDS s'affiche comme `tuteur`.
  static String normaliserRang(String? brut, {bool estTuteur = false}) {
    final rang = switch (brut) {
      'formateur_tds' => 'formateur',
      'admin_universite' || 'superadmin' => 'moderateur',
      null || '' => 'etudiant',
      _ => brut,
    };
    if (rang == 'etudiant' && estTuteur) return 'tuteur';
    return rang;
  }

  /// Construit le profil depuis `/auth/me` (AuthUserPublic), éventuellement
  /// fusionné avec `/utilisateurs/:id` (nom, prénom, compte créateur…).
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rangBrut = json['rang'] as String? ?? 'etudiant';
    final estTuteur =
        json['estTuteur'] as bool? ?? json['estTuteurTds'] as bool? ?? false;
    final statutCompte = json['statutCompte'] as String? ?? 'actif';
    final rang = normaliserRang(rangBrut, estTuteur: estTuteur);
    // Backend : le rang `enseignant` n'est attribué qu'après validation du
    // dossier ; un enseignant en attente reste `etudiant` + statut `demo`.
    final badge = json['badgeEnseignant'] as bool? ?? rangBrut == 'enseignant';
    final compteCreateur = json['compteCreateur'] as Map<String, dynamic>?;
    final groupeTds = json['groupeTds'] as Map<String, dynamic>?;
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      prenom: json['prenom'] as String? ?? '',
      rang: rang,
      niveauId: json['niveauId'] as String?,
      badgeEnseignant: badge,
      dossierEnseignant: rang == 'enseignant' || statutCompte == 'demo'
          ? DossierEnseignantStatut.depuis(
              json['dossierEnseignant'] as String?,
              badge: badge,
            )
          : null,
      emailVerifie: json['emailVerifie'] as bool? ?? true,
      photoUrl: json['photoUrl'] as String?,
      bio: json['bio'] as String? ?? compteCreateur?['bio'] as String?,
      identifiant: json['identifiant'] as String?,
      telephone: json['telephone'] as String?,
      statutCompte: statutCompte,
      estTuteur: estTuteur,
      estModerateur: json['estModerateur'] as bool? ?? false,
      compteCreateurId: compteCreateur?['id'] as String?,
      nombreAbonnes: (compteCreateur?['nombreAbonnes'] as num?)?.toInt() ?? 0,
      groupeTdsId: groupeTds?['id'] as String?,
      groupeTdsNom: groupeTds?['nom'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, email, rang, niveauId];
}

class UniversiteItem extends Equatable {
  const UniversiteItem({
    required this.id,
    required this.nom,
    this.sigle,
    this.statut = 'actif',
  });

  final String id;
  final String nom;
  final String? sigle;
  final String statut;

  String get shortLabel {
    if (sigle != null && sigle!.isNotEmpty) return sigle!;
    if (nom.length <= 3) return nom.toUpperCase();
    return nom.substring(0, 3).toUpperCase();
  }

  factory UniversiteItem.fromJson(Map<String, dynamic> json) {
    return UniversiteItem(
      id: json['id'] as String,
      nom: json['nom'] as String? ?? '',
      sigle: json['sigle'] as String?,
      statut: json['statut'] as String? ?? 'actif',
    );
  }

  @override
  List<Object?> get props => [id];
}

class VideoItem extends Equatable {
  const VideoItem({
    required this.id,
    required this.titre,
    this.description,
    this.youtubeId,
    this.urlLecture,
    this.ticketLecture,
    this.pretALire = false,
    this.nombreLikes = 0,
    this.likedByMe = false,
    this.dislikedByMe = false,
    this.abonneParMoi = false,
    this.createurNom,
    this.createurId,
    this.compteCreateurId,
    this.groupeTdsId,
    this.createdAt,
    this.dureeSecondes,
    this.nombreVues = 0,
    this.matiere,
  });

  final String id;
  final String titre;
  final String? description;

  /// Uniquement pour le Mode Test (données fictives) — le vrai backend sert
  /// des flux Drive tickettés, jamais YouTube.
  final String? youtubeId;

  /// URL du flux `GET /videos/:id/stream` (backend). Nécessite le header
  /// `x-lecture-ticket` ([ticketLecture]) ou `?ticket=` en repli.
  final String? urlLecture;
  final String? ticketLecture;

  /// `false` tant que l'upload Google Drive n'est pas terminé côté serveur.
  final bool pretALire;

  final int nombreLikes;
  final bool likedByMe;
  final bool dislikedByMe;
  final bool abonneParMoi;
  final String? createurNom;
  final String? createurId;
  final String? compteCreateurId;
  final String? groupeTdsId;
  final DateTime? createdAt;

  /// Durée de la vidéo, en secondes. **Contrat à transmettre** : aucun champ
  /// n'existe encore côté `/videos/feed` — à calculer côté back au moment de
  /// l'upload (ex. ffprobe) et renvoyer `dureeSecondes` (int).
  final int? dureeSecondes;

  /// Nombre de vues. **Contrat à transmettre** : `/videos/feed` ne renvoie
  /// pas encore ce compteur — `nombreVues` (int), incrémenté côté back à
  /// chaque lecture (comme `nombreLikes` l'est déjà pour les likes).
  final int nombreVues;

  /// Matière/contexte d'origine, pour un fil éditorialisé façon chaîne
  /// pédagogique plutôt qu'un flux anonyme. **Contrat à transmettre** :
  /// libellé de la matière/du canal d'origine, à inclure dans la réponse.
  final String? matiere;

  String get dureeLabel {
    final s = dureeSecondes;
    if (s == null || s <= 0) return '';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  String get vuesLabel {
    if (nombreVues >= 1000000) {
      return '${(nombreVues / 1000000).toStringAsFixed(1)} M vues';
    }
    if (nombreVues >= 1000) {
      return '${(nombreVues / 1000).toStringAsFixed(1)} k vues';
    }
    return '$nombreVues vue${nombreVues > 1 ? 's' : ''}';
  }

  String? get thumbnailUrl => youtubeId == null || youtubeId!.isEmpty
      ? null
      : 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg';

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    // Backend réel : `auteur` {id, nom, prenom, rang} + `groupeTdsNom`.
    // Mode Test : `compteCreateur.utilisateur` ou `groupeTds.nom`.
    final auteur = json['auteur'] as Map<String, dynamic>?;
    final createur = json['compteCreateur'] as Map<String, dynamic>?;
    final user = createur?['utilisateur'] as Map<String, dynamic>?;
    final tds = json['groupeTds'] as Map<String, dynamic>?;
    String? nom;
    String? createurId;
    if (auteur != null) {
      nom = '${auteur['prenom'] ?? ''} ${auteur['nom'] ?? ''}'.trim();
      createurId = auteur['id'] as String?;
    } else if (user != null) {
      nom = '${user['prenom'] ?? ''} ${user['nom'] ?? ''}'.trim();
      createurId = user['id'] as String?;
    } else if (tds != null) {
      nom = tds['nom'] as String?;
    }
    final groupeTdsNom =
        json['groupeTdsNom'] as String? ?? tds?['nom'] as String?;
    return VideoItem(
      id: json['id'] as String,
      titre: json['titre'] as String? ?? '',
      description: json['description'] as String?,
      youtubeId: json['youtubeId'] as String?,
      urlLecture: json['urlLecture'] as String?,
      ticketLecture: json['ticketLecture'] as String?,
      pretALire: json['pretALire'] as bool? ?? json['youtubeId'] != null,
      nombreLikes: (json['nombreLikes'] as num?)?.toInt() ?? 0,
      likedByMe:
          json['aimeParMoi'] as bool? ?? json['likedByMe'] as bool? ?? false,
      dislikedByMe: json['detesteParMoi'] as bool? ??
          json['dislikedByMe'] as bool? ??
          false,
      abonneParMoi: json['abonneParMoi'] as bool? ?? false,
      createurNom: (nom?.isEmpty ?? true) ? groupeTdsNom : nom,
      createurId: createurId,
      compteCreateurId: json['compteCreateurId'] as String? ??
          createur?['id'] as String?,
      groupeTdsId: json['groupeTdsId'] as String? ?? tds?['id'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      dureeSecondes: (json['dureeSecondes'] as num?)?.toInt(),
      nombreVues: (json['nombreVues'] as num?)?.toInt() ?? 0,
      matiere: (json['matiere'] as String?) ?? groupeTdsNom,
    );
  }

  VideoItem copyWith({
    bool? likedByMe,
    bool? dislikedByMe,
    bool? abonneParMoi,
    int? nombreLikes,
  }) {
    return VideoItem(
      id: id,
      titre: titre,
      description: description,
      youtubeId: youtubeId,
      urlLecture: urlLecture,
      ticketLecture: ticketLecture,
      pretALire: pretALire,
      nombreLikes: nombreLikes ?? this.nombreLikes,
      likedByMe: likedByMe ?? this.likedByMe,
      dislikedByMe: dislikedByMe ?? this.dislikedByMe,
      abonneParMoi: abonneParMoi ?? this.abonneParMoi,
      createurNom: createurNom,
      createurId: createurId,
      compteCreateurId: compteCreateurId,
      groupeTdsId: groupeTdsId,
      createdAt: createdAt,
      dureeSecondes: dureeSecondes,
      nombreVues: nombreVues,
      matiere: matiere,
    );
  }

  @override
  List<Object?> get props => [id];
}

class LivreItem extends Equatable {
  const LivreItem({
    required this.id,
    required this.titre,
    this.description,
    this.fichierCle,
    this.auteur,
  });

  final String id;
  final String titre;
  final String? description;
  final String? fichierCle;
  final String? auteur;

  factory LivreItem.fromJson(Map<String, dynamic> json) {
    return LivreItem(
      id: json['id'] as String,
      titre: json['titre'] as String? ?? '',
      description: json['description'] as String?,
      fichierCle: json['fichierCle'] as String?,
      auteur: (json['auteurLivre'] ?? json['auteur']) as String?,
    );
  }

  @override
  List<Object?> get props => [id];
}

class ConversationItem extends Equatable {
  const ConversationItem({
    required this.id,
    this.destinataireId,
    this.destinataireNom,
    this.destinataireRang,
    this.destinatairePhotoUrl,
    this.dernierMessage,
    this.type = 'libre',
    this.statut = 'ouverte',
    this.updatedAt,
    this.nonLus = 0,
  });

  final String id;
  final String? destinataireId;
  final String? destinataireNom;
  final String? destinataireRang;
  final String? destinatairePhotoUrl;
  final String? dernierMessage;
  final String type;
  final String statut;
  final DateTime? updatedAt;

  /// Messages non lus dans cette conversation — champ pressenti côté back
  /// (`nonLus`), absent aujourd'hui : retombe sur 0 tant qu'il n'existe pas.
  final int nonLus;

  /// [moiId] permet d'identifier « l'autre » participant quand le backend
  /// renvoie `utilisateurUn` / `utilisateurDeux` (format réel). Le Mode Test
  /// sert un format `participants: [{utilisateur}]` également pris en charge.
  factory ConversationItem.fromJson(Map<String, dynamic> json, {String? moiId}) {
    String? id;
    String? nom;
    String? rang;
    String? photo;

    void lireUtilisateur(Map<String, dynamic> u) {
      id = u['id'] as String?;
      nom = '${u['prenom'] ?? ''} ${u['nom'] ?? ''}'.trim();
      rang = UserProfile.normaliserRang(u['rang'] as String?);
      photo = u['photoUrl'] as String?;
    }

    final un = json['utilisateurUn'] as Map<String, dynamic>?;
    final deux = json['utilisateurDeux'] as Map<String, dynamic>?;
    if (un != null || deux != null) {
      final autre = (un?['id'] == moiId ? deux : un) ?? deux ?? un;
      if (autre != null) lireUtilisateur(autre);
    } else {
      final participants = json['participants'] as List? ?? [];
      if (participants.isNotEmpty) {
        final p = participants.first as Map<String, dynamic>;
        lireUtilisateur(p['utilisateur'] as Map<String, dynamic>? ?? p);
      }
    }
    final msgs = json['messages'] as List?;
    String? last;
    if (msgs != null && msgs.isNotEmpty) {
      last = (msgs.first as Map<String, dynamic>)['contenu'] as String?;
    }
    return ConversationItem(
      id: json['id'] as String,
      destinataireId: id ?? json['destinataireId'] as String?,
      destinataireNom: (nom?.isEmpty ?? true)
          ? json['destinataireNom'] as String?
          : nom,
      destinataireRang: rang ?? json['destinataireRang'] as String?,
      destinatairePhotoUrl: photo ?? json['destinatairePhotoUrl'] as String?,
      dernierMessage: last ?? json['dernierMessage'] as String?,
      type: json['type'] as String? ?? 'libre',
      statut: json['statut'] as String? ?? 'ouverte',
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      nonLus: json['nonLus'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [id];
}

class MessageItem extends Equatable {
  const MessageItem({
    required this.id,
    required this.contenu,
    required this.auteurId,
    this.auteurNom,
    this.auteurRang,
    this.auteurPhotoUrl,
    this.createdAt,
    this.lu = false,
    this.pieceJointeNom,
    this.pieceJointeBytes,
    this.pieceJointeEstImage = true,
  });

  final String id;
  final String contenu;
  final String auteurId;
  final String? auteurNom;
  final String? auteurRang;
  final String? auteurPhotoUrl;
  final DateTime? createdAt;

  /// Pièce jointe (photo ou PDF) — **local uniquement**, aucun endpoint
  /// d'upload de message n'existe encore côté back. Contrat à transmettre :
  /// `POST /storage/presign/upload` sur un bucket `messages`, puis
  /// `pieceJointeCle` dans le payload de `POST .../messages`.
  final String? pieceJointeNom;
  final Uint8List? pieceJointeBytes;
  final bool pieceJointeEstImage;

  bool get aUnePieceJointe => pieceJointeNom != null;

  /// Accusé de lecture. Le GET messages expose `lu` (dérivé de `luAt`) ;
  /// le socket `message_lu` pousse la mise à jour à l'expéditeur.
  final bool lu;

  MessageItem copyWith({bool? lu}) => MessageItem(
        id: id,
        contenu: contenu,
        auteurId: auteurId,
        auteurNom: auteurNom,
        auteurRang: auteurRang,
        auteurPhotoUrl: auteurPhotoUrl,
        createdAt: createdAt,
        lu: lu ?? this.lu,
        pieceJointeNom: pieceJointeNom,
        pieceJointeBytes: pieceJointeBytes,
        pieceJointeEstImage: pieceJointeEstImage,
      );

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    final auteur = json['auteur'] as Map<String, dynamic>?;
    return MessageItem(
      id: json['id'] as String,
      contenu: json['contenu'] as String? ?? '',
      auteurId: json['auteurId'] as String? ?? auteur?['id'] as String? ?? '',
      auteurNom: auteur != null
          ? '${auteur['prenom'] ?? ''} ${auteur['nom'] ?? ''}'.trim()
          : null,
      auteurRang: auteur?['rang'] as String?,
      auteurPhotoUrl: auteur?['photoUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      lu: json['lu'] as bool? ?? json['luAt'] != null,
    );
  }

  @override
  List<Object?> get props => [id];
}

class NotificationItem extends Equatable {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.titre,
    this.lu = false,
    this.createdAt,
  });

  final String id;
  final String type;
  final String titre;
  final bool lu;
  final DateTime? createdAt;

  /// Libellés français des types backend — le serveur ne renvoie que
  /// `type` + `payload`, jamais de titre rédigé.
  static String libellePourType(String type) => switch (type) {
        'nouvelle_ressource' => 'Nouvelle ressource dans un canal suivi',
        'reponse_recue' => 'Nouvelle réponse à ta publication',
        'nouvelle_video_suivie' => 'Nouvelle vidéo d\'un compte suivi',
        'statut_demande' => 'Ta demande de statut a été traitée',
        'nouveau_message_direct' => 'Nouveau message direct',
        'nouveau_signalement' => 'Nouveau signalement reçu',
        'signalement_traite' => 'Ton signalement a été traité',
        _ => 'Notification',
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    return NotificationItem(
      id: json['id'] as String,
      type: type,
      titre: json['titre'] as String? ??
          json['message'] as String? ??
          libellePourType(type),
      lu: json['lu'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [id];
}
