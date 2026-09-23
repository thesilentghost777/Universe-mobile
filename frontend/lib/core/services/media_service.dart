import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Sélection et validation de fichiers côté client (photo, logo, pièces
/// d'identité) — partagée entre l'inscription (CNI, logo, photo de profil)
/// et les Paramètres (changement de photo de profil).
///
/// **Contrat backend attendu (à transmettre)** — aucun endpoint dédié
/// n'existe encore :
///   1. `POST /storage/presign/upload` — déjà utilisé ailleurs dans l'app
///      (vidéos, livres) : `{ bucket, cle, tailleOctets, contentType }` →
///      `{ url, fields|formData, cle }`. Réutilisable tel quel pour un
///      bucket `profils` (photo, logo) et `documents` (CNI, diplôme) :
///      upload direct vers l'URL présignée, comme pour les vidéos.
///   2. Une fois l'upload fait, la clé retournée (`cle`/`fields.key`) est
///      envoyée dans le payload d'inscription ou de mise à jour de profil
///      (voir `RegistrationService` et `SettingsPage`).
///   3. Codes d'erreur à gérer : 413 (fichier trop lourd côté serveur),
///      415 (type de fichier refusé), 401/403 (session expirée pendant
///      l'upload).
class MediaService {
  const MediaService();

  /// Taille maximale acceptée côté client avant envoi (8 Mo) — évite un
  /// aller-retour réseau pour un fichier que le serveur refuserait de toute
  /// façon.
  static const int tailleMaxOctets = 8 * 1024 * 1024;

  /// Choisit une image (photo de profil, logo). Retourne `null` si
  /// l'utilisateur annule ou si le fichier dépasse la taille autorisée.
  ///
  /// Les octets sont toujours chargés et portés par [MediaPickResult.octets] :
  /// sur le web, `PlatformFile.path` n'existe pas — les octets sont le seul
  /// moyen d'accéder au contenu, que ce soit pour un aperçu (`Image.memory`)
  /// ou pour l'upload (`MultipartFile.fromBytes`). Le plafond de
  /// [tailleMaxOctets] (8 Mo) rend ce chargement négligeable en mémoire.
  Future<MediaPickResult> choisirImage() async {
    return _valider(await FilePicker.pickFile(type: FileType.image));
  }

  /// Choisit une photo ou un PDF — pièce jointe du module IA (§7.5). Pas de
  /// vidéo ici : l'IA ne traite que de l'image et du document.
  Future<MediaPickResult> choisirImageOuPdf() async {
    return _valider(await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf'],
    ));
  }

  /// Choisit un document d'identité (CNI recto-verso, diplôme) — image ou
  /// PDF.
  Future<MediaPickResult> choisirDocument() async {
    return _valider(await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    ));
  }

  Future<MediaPickResult> _valider(PlatformFile? fichier) async {
    if (fichier == null) {
      return const MediaPickResult.annule();
    }
    // `lengthSync` renvoie la taille déjà annoncée par le sélecteur natif,
    // sans lecture disque : elle permet de rejeter un fichier trop lourd
    // sans jamais le charger en mémoire. Quand la plateforme ne l'annonce
    // pas, seule la lecture des octets tranche.
    final tailleAnnoncee = fichier.lengthSync();
    if (tailleAnnoncee != null && tailleAnnoncee > tailleMaxOctets) {
      return MediaPickResult.tropLourd(fichier);
    }
    final octets = await fichier.readAsBytes();
    if (octets.length > tailleMaxOctets) {
      return MediaPickResult.tropLourd(fichier);
    }
    return MediaPickResult.ok(fichier, octets);
  }
}

enum MediaPickStatut { annule, ok, tropLourd }

class MediaPickResult {
  const MediaPickResult._(this.statut, this.fichier, this.octets);

  const MediaPickResult.annule() : this._(MediaPickStatut.annule, null, null);
  const MediaPickResult.ok(PlatformFile f, Uint8List o)
      : this._(MediaPickStatut.ok, f, o);
  const MediaPickResult.tropLourd(PlatformFile f)
      : this._(MediaPickStatut.tropLourd, f, null);

  final MediaPickStatut statut;
  final PlatformFile? fichier;

  /// Contenu du fichier, lu au moment de la sélection. Non `null` dès que
  /// [estValide] l'est.
  final Uint8List? octets;

  bool get estValide => statut == MediaPickStatut.ok;
}
