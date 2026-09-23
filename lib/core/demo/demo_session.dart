import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/models.dart';
import 'demo_content.dart';

/// Session du Mode Test — un compte simulé pour un rôle donné, sans aucun
/// appel réseau.
///
/// Quand elle est active, `DemoApiInterceptor` intercepte toutes les
/// requêtes du client API et les sert depuis [DemoContent] : chaque écran
/// suit son parcours de chargement habituel, mais aucune donnée réelle ne
/// circule. Le socket, lui, ne se connecte jamais (aucun jeton stocké).
///
/// La session survit au redémarrage de l'application (clé
/// [_clePrefs] dans les SharedPreferences) jusqu'à la déconnexion.
class DemoSession {
  DemoSession._();

  static const _clePrefs = 'universe_demo_role';

  /// Les rôles simulables, dans l'ordre d'affichage du sélecteur.
  /// `enseignant_attente` simule un enseignant dont le dossier n'est pas
  /// encore validé (compte étudiant limité, bandeaux dédiés).
  static const roles = [
    'etudiant',
    'tuteur',
    'formateur',
    'enseignant',
    'enseignant_attente',
    'moderateur',
  ];

  /// Profil JSON du compte simulé courant — mutable pour que
  /// `PATCH /utilisateurs/moi/niveau` (onboarding) fonctionne aussi en démo.
  static Map<String, dynamic>? _profil;

  static bool get active => _profil != null;

  static Map<String, dynamic> get profilJson =>
      Map<String, dynamic>.from(_profil ?? const {});

  static UserProfile? get utilisateur =>
      _profil == null ? null : UserProfile.fromJson(profilJson);

  static String? get userId => _profil?['id'] as String?;

  /// Active la session pour [role] et la persiste.
  static Future<UserProfile> activer(String role) async {
    _profil = _profilPour(role);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clePrefs, role);
    } catch (_) {}
    return utilisateur!;
  }

  /// Restaure une session persistée, ou renvoie `null` s'il n'y en a pas.
  static Future<UserProfile?> restaurer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString(_clePrefs);
      if (role == null || !roles.contains(role)) return null;
      _profil = _profilPour(role);
      return utilisateur;
    } catch (_) {
      return null;
    }
  }

  static Future<void> desactiver() async {
    _profil = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_clePrefs);
    } catch (_) {}
  }

  static void definirNiveau(String niveauId) {
    _profil?['niveauId'] = niveauId;
  }

  static Map<String, dynamic> _profilPour(String role) => switch (role) {
        'tuteur' => {
            'id': 'usr-demo-tuteur',
            'email': 'demo.tuteur@universe.cm',
            'prenom': 'Brice',
            'nom': 'Momo',
            'rang': 'tuteur',
            'niveauId': 'niv-uy1-info-l3',
            'identifiant': 'brice.demo',
            'photoUrl': avatarDemo('brice-momo'),
            'bio': 'Tuteur du groupe Algorithmique L3 (compte de test).',
          },
        'formateur' => {
            'id': 'usr-demo-formateur',
            'email': 'demo.formateur@universe.cm',
            'prenom': 'Nadia',
            'nom': 'Essomba',
            'rang': 'formateur',
            'identifiant': 'nadia.demo',
            'photoUrl': avatarDemo('nadia-essomba'),
            'bio': 'Formatrice TDS — vidéos pédagogiques chaque semaine '
                '(compte de test).',
          },
        'enseignant' => {
            'id': 'usr-demo-enseignant',
            'email': 'demo.enseignant@universe.cm',
            'prenom': 'Dr. Paul',
            'nom': 'Atangana',
            'rang': 'enseignant',
            'badgeEnseignant': true,
            'dossierEnseignant': 'valide',
            'identifiant': 'paul.demo',
            'photoUrl': avatarDemo('paul-atangana'),
            'bio': 'Enseignant-chercheur, accréditation validée '
                '(compte de test).',
          },
        'enseignant_attente' => {
            'id': 'usr-demo-enseignant-attente',
            'email': 'demo.enseignant2@universe.cm',
            'prenom': 'Dr. Rose',
            'nom': 'Abena',
            'rang': 'enseignant',
            'badgeEnseignant': false,
            'dossierEnseignant': 'soumis',
            'identifiant': 'rose.demo',
            'photoUrl': avatarDemo('rose-abena'),
            'bio': 'Enseignante — dossier en cours d\'examen '
                '(compte de test).',
          },
        'moderateur' => {
            'id': 'usr-demo-moderateur',
            'email': 'demo.moderateur@universe.cm',
            'prenom': 'Cyrille',
            'nom': 'Nkoulou',
            'rang': 'moderateur',
            'identifiant': 'cyrille.demo',
            'photoUrl': avatarDemo('cyrille-nkoulou'),
            'bio': 'Modérateur UniVerse pour l\'UY1 (compte de test).',
          },
        // Étudiant par défaut — niveau déjà choisi pour ne pas repasser
        // par l'onboarding à chaque essai.
        _ => {
            'id': 'usr-demo-etudiant',
            'email': 'demo.etudiant@universe.cm',
            'prenom': 'Aline',
            'nom': 'Kouam',
            'rang': 'etudiant',
            'niveauId': 'niv-uy1-info-l3',
            'identifiant': 'aline.demo',
            'photoUrl': avatarDemo('aline-kouam'),
            'bio': 'Étudiante en L3 Informatique à l\'UY1 (compte de test).',
          },
      };
}
