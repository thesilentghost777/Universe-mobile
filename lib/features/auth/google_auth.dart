import 'package:google_sign_in/google_sign_in.dart';

/// Connexion Google, isolée dans un seul fichier.
///
/// ## Ce qu'il reste à faire hors du code Dart
///
/// Google exige une configuration native, sans quoi l'appel échoue à
/// l'exécution (le code compile quand même) :
///
/// 1. Créer un projet sur console.cloud.google.com et y activer
///    « Google Sign-In ».
/// 2. Créer **deux** identifiants OAuth :
///    - un client **Android**, avec le nom de paquet de l'app et
///      l'empreinte SHA-1 de la clé de signature
///      (`keytool -list -v -keystore ~/.android/debug.keystore`,
///      mot de passe `android`) ;
///    - un client **Web** : c'est son identifiant qui sert de
///      `serverClientId` ci-dessous, et c'est lui que le backend
///      utilisera pour valider le jeton.
/// 3. Passer l'identifiant web au lancement :
///    `flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com`
/// 4. Pour iOS, ajouter le `REVERSED_CLIENT_ID` dans les schémas d'URL
///    de `Info.plist`.
///
/// Tant que ce n'est pas fait, [connecter] lève une exception que
/// [estNonConfigure] reconnaît, pour afficher un message clair plutôt
/// qu'une erreur technique.
class GoogleAuth {
  GoogleAuth._();

  static const _serverClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  static GoogleSignIn get _google => GoogleSignIn.instance;

  /// Depuis la v7 du plugin, `initialize` doit être appelé une fois et une
  /// seule avant toute autre méthode. On mémorise le future plutôt qu'un
  /// booléen : deux appels rapprochés attendent alors la même init au lieu
  /// d'en lancer deux.
  static Future<void>? _initialisation;

  static Future<void> _initialiser() {
    return _initialisation ??= _google.initialize(
      // Indispensable sur Android pour obtenir un `idToken` exploitable
      // côté serveur ; sans lui, seul un `accessToken` est renvoyé.
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
  }

  /// Ouvre le sélecteur de compte Google.
  ///
  /// Renvoie le jeton d'identité à transmettre au backend, ou `null` si
  /// l'utilisateur a fermé la fenêtre.
  static Future<String?> connecter() async {
    await _initialiser();
    final GoogleSignInAccount compte;
    try {
      compte = await _google.authenticate(scopeHint: const ['email', 'profile']);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }

    final idToken = compte.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Aucun idToken renvoyé par Google : GOOGLE_SERVER_CLIENT_ID '
        'est probablement absent ou incorrect.',
      );
    }
    return idToken;
  }

  /// Déconnecte le compte Google local, sans toucher à la session UniVerse.
  static Future<void> deconnecter() async {
    try {
      await _initialiser();
      await _google.signOut();
    } catch (_) {
      // Sans importance : la session applicative reste gérée par nos jetons.
    }
  }

  /// Distingue « pas encore configuré » d'une vraie panne, pour afficher
  /// le bon message à l'utilisateur.
  static bool estNonConfigure(Object erreur) {
    if (erreur is GoogleSignInException) {
      if (erreur.code == GoogleSignInExceptionCode.clientConfigurationError ||
          erreur.code == GoogleSignInExceptionCode.providerConfigurationError) {
        return true;
      }
    }
    final texte = erreur.toString().toLowerCase();
    return _serverClientId.isEmpty ||
        texte.contains('idtoken') ||
        texte.contains('developer_error') ||
        texte.contains('sign_in_failed') ||
        texte.contains('10:');
  }
}
