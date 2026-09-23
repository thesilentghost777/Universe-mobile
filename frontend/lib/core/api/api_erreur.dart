import 'package:dio/dio.dart';

/// Erreur API présentée à l'utilisateur — un seul mapping pour tout le client.
class ApiErreur implements Exception {
  const ApiErreur(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => message;

  static bool estReseau(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  static ApiErreur depuis(Object error) {
    if (error is ApiErreur) return error;
    if (error is DioException) {
      if (estReseau(error)) {
        return const ApiErreur('Hors ligne. Vérifie ta connexion.');
      }
      final code = error.response?.statusCode;
      return ApiErreur(_messagePourStatut(code), status: code);
    }
    return const ApiErreur('Une erreur est survenue.');
  }

  static String _messagePourStatut(int? code) {
    return switch (code) {
      401 => 'Session expirée. Reconnecte-toi.',
      403 => 'Accès refusé.',
      409 => 'Conflit : cette action n\'est plus possible.',
      422 => 'Données invalides.',
      429 => 'Trop de requêtes. Réessaie dans un instant.',
      500 || 502 || 503 || 504 => 'Le serveur est indisponible.',
      _ => 'Une erreur est survenue.',
    };
  }
}
