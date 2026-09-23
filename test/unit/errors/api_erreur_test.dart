import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe_frontend/core/api/api_erreur.dart';

DioException _dio(int? status, {DioExceptionType type = DioExceptionType.badResponse}) {
  return DioException(
    requestOptions: RequestOptions(path: '/x'),
    type: type,
    response: status == null
        ? null
        : Response(requestOptions: RequestOptions(path: '/x'), statusCode: status),
  );
}

void main() {
  group('ApiErreur', () {
    test('préserve une ApiErreur déjà typée', () {
      const origine = ApiErreur('Déjà mappée', status: 409);
      expect(ApiErreur.depuis(origine), same(origine));
    });

    test('mappe les statuts HTTP métier', () {
      expect(ApiErreur.depuis(_dio(401)).message, contains('Session expirée'));
      expect(ApiErreur.depuis(_dio(403)).message, 'Accès refusé.');
      expect(ApiErreur.depuis(_dio(409)).message, contains('Conflit'));
      expect(ApiErreur.depuis(_dio(422)).message, 'Données invalides.');
      expect(ApiErreur.depuis(_dio(429)).message, contains('Trop de requêtes'));
      expect(ApiErreur.depuis(_dio(500)).message, 'Le serveur est indisponible.');
      expect(ApiErreur.depuis(_dio(503)).message, 'Le serveur est indisponible.');
    });

    test('mappe une coupure réseau', () {
      final e = ApiErreur.depuis(
        _dio(null, type: DioExceptionType.connectionError),
      );
      expect(e.message, contains('Hors ligne'));
      expect(ApiErreur.estReseau(_dio(null, type: DioExceptionType.connectionTimeout)), isTrue);
      expect(ApiErreur.estReseau(_dio(null, type: DioExceptionType.receiveTimeout)), isTrue);
      expect(ApiErreur.estReseau(_dio(null, type: DioExceptionType.sendTimeout)), isTrue);
    });

    test('reste générique hors Dio', () {
      expect(ApiErreur.depuis(StateError('boom')).message, 'Une erreur est survenue.');
    });
  });
}
