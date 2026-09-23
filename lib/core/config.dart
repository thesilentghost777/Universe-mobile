/// Configuration runtime du client UniVerse.
class AppConfig {
  AppConfig._();

  /// Surcharge explicite fournie au build : `--dart-define=API_BASE_URL=...`.
  /// Prioritaire sur la détection automatique par plateforme ci-dessous.
  static const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Base URL de l'API NestJS (sans slash final).
  ///
  /// La surcharge `API_BASE_URL` reste disponible pour les environnements
  /// locaux et les tests.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    return 'https://api.universe-icorp.com';
  }

  static const String appName = 'UniVerse';
  static const String tagline = "L'UNIVERSITÉ EN LIGNE";
}
