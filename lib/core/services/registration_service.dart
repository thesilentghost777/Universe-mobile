import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import '../api/api_client.dart';
import '../auth/role_access.dart';

/// Inscription alignée sur les contrats réels du backend UniVerse :
///
/// - **Email** → `POST /auth/register` (aucune session ouverte : le compte
///   doit d'abord confirmer son email — jeton envoyé par mail, exposé dans
///   la réponse en développement via `EXPOSE_EMAIL_VERIFICATION_TOKEN`).
/// - **Téléphone** → `POST /auth/otp/send` puis `POST /auth/otp/verify`
///   avec les champs d'identité : le backend crée le compte **et ouvre la
///   session** à la validation du code.
/// - **Google** → `POST /auth/google` avec les champs d'identité : crée le
///   compte et ouvre la session.
///
/// Les pièces d'identité (CNI, photo, logo) sont téléversées **avant**
/// l'inscription via `POST /auth/presign-identite` (public) : le serveur
/// signe une policy MinIO sous `pending/{uuid}/identite/...` et renvoie un
/// `dossierToken` à rejouer pour chaque fichier du même dossier, puis dans
/// le payload d'inscription.
class RegistrationService {
  RegistrationService(this._api);

  final ApiClient _api;

  /// Jeton de dossier renvoyé par le premier presign — chaîné sur les
  /// presigns suivants puis rejoué dans le payload d'inscription.
  String? _dossierToken;

  /// Rôle front → profil d'inscription backend (`rangInscription`).
  static String profilBackend(Rang role) => switch (role) {
        Rang.etudiant => 'etudiant',
        Rang.tuteur => 'tuteur',
        Rang.formateur => 'formateur_tds',
        Rang.enseignant => 'enseignant',
        // Le modérateur ne s'inscrit jamais (qualification attribuée).
        Rang.moderateur => 'etudiant',
      };

  /// Code UI ('M'/'F') → enum backend ('masculin'/'feminin').
  static String? sexeBackend(String? code) => switch (code) {
        'M' || 'masculin' => 'masculin',
        'F' || 'feminin' => 'feminin',
        _ => null,
      };

  /// `YYYY-MM-DD` attendu par le backend.
  static String? dateBackend(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

  static String _contentTypePour(PlatformFile fichier) =>
      switch (fichier.extension?.toLowerCase()) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

  /// Téléverse un fichier d'identité (avant inscription).
  ///
  /// [type] : `cni-recto` | `cni-verso` | `photo-profil` | `logo-formation`.
  /// Retourne la clé MinIO (`pending/{uuid}/identite/...`) à mettre dans le
  /// payload d'inscription.
  Future<String?> televerserIdentite(String type, PlatformFile? fichier) async {
    if (fichier == null) return null;
    final taille = fichier.lengthSync() ?? 0;
    final contentType = _contentTypePour(fichier);
    final presign = await _api.post('/auth/presign-identite', data: {
      'fichier': type,
      'tailleOctets': taille > 0 ? taille : 1,
      'contentType': contentType,
      if (_dossierToken != null) 'dossierToken': _dossierToken,
    });
    final data = Map<String, dynamic>.from(presign.data as Map);
    _dossierToken = data['dossierToken'] as String? ?? _dossierToken;
    final cle = data['cle'] as String;
    await _envoyerVersPolicy(data, fichier, contentType);
    return cle;
  }

  /// Dépose le fichier sur MinIO via la policy POST multipart signée
  /// (`{url, fields}`) renvoyée par le presign.
  Future<void> _envoyerVersPolicy(
    Map<String, dynamic> policy,
    PlatformFile fichier,
    String contentType,
  ) async {
    final url = policy['url'] as String;
    final fields = Map<String, dynamic>.from(policy['fields'] as Map? ?? {});
    final form = FormData.fromMap({
      ...fields,
      'file': fichier.path != null
          ? await MultipartFile.fromFile(
              fichier.path!,
              filename: fichier.name,
              contentType: DioMediaType.parse(contentType),
            )
          : MultipartFile.fromBytes(
              await fichier.readAsBytes(),
              filename: fichier.name,
              contentType: DioMediaType.parse(contentType),
            ),
    });
    await Dio().post(url, data: form);
  }

  /// Champs d'identité communs aux trois canaux d'inscription
  /// (`ChampsIdentiteDto` backend). Les clés `null` sont omises.
  Map<String, dynamic> champsIdentite({
    required Rang role,
    String? sexe,
    DateTime? dateNaissance,
    String? cniRectoCle,
    String? cniVersoCle,
    String? photoProfilCle,
    String? logoFormationCle,
  }) {
    final sexeApi = sexeBackend(sexe);
    final date = dateBackend(dateNaissance);
    return {
      'rangInscription': profilBackend(role),
      if (sexeApi != null) 'sexe': sexeApi,
      if (date != null) 'dateNaissance': date,
      if (cniRectoCle != null) 'cniRectoCle': cniRectoCle,
      if (cniVersoCle != null) 'cniVersoCle': cniVersoCle,
      if (photoProfilCle != null) 'photoProfilCle': photoProfilCle,
      if (logoFormationCle != null) 'logoFormationCle': logoFormationCle,
      if (_dossierToken != null) 'dossierToken': _dossierToken,
    };
  }

  /// Inscription **email** : `POST /auth/register`. Ne connecte pas — le
  /// compte doit confirmer son email. Retourne la réponse serveur
  /// (`{message, email, verificationToken?}`).
  Future<Map<String, dynamic>> inscrireParEmail({
    required String email,
    required String motDePasse,
    required String nom,
    required String prenom,
    required Map<String, dynamic> identite,
  }) async {
    try {
      final res = await _api.post('/auth/register', data: {
        'email': email.trim(),
        'motDePasse': motDePasse,
        'nom': nom,
        if (prenom.trim().isNotEmpty) 'prenom': prenom.trim(),
        ...identite,
      });
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      throw RegistrationException(_messagePour(e));
    }
  }

  static String _messagePour(DioException e) {
    final code = e.response?.statusCode;
    final message = _messageServeur(e);
    return switch (code) {
      400 => message ?? 'Inscription refusée : vérifie les champs saisis.',
      409 => 'Un compte existe déjà avec cet identifiant.',
      429 => 'Trop de tentatives. Patiente une minute avant de réessayer.',
      _ => 'Inscription impossible. Vérifie ta connexion et réessaie.',
    };
  }

  static String? _messageServeur(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final m = data['message'];
      if (m is String && m.trim().isNotEmpty) return m;
      if (m is List && m.isNotEmpty) return m.first.toString();
    }
    return null;
  }
}

class RegistrationException implements Exception {
  const RegistrationException(this.message);
  final String message;
  @override
  String toString() => message;
}
