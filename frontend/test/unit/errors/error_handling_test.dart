import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe_frontend/features/ai/ai_store.dart';

void main() {
  group('Error Handling & Fallbacks Tests', () {
    String formatAuthError(Object error) {
      if (error is DioException) {
        final code = error.response?.statusCode;
        if (code == 401) return 'Identifiants incorrects';
        if (code == 429) return 'Trop de tentatives — réessayez plus tard';
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError) {
          return 'Connexion impossible';
        }
      }
      final s = error.toString();
      if (s.contains('401')) return 'Identifiants incorrects';
      if (s.contains('429')) return 'Trop de tentatives — réessayez plus tard';
      if (s.contains('Timeout') || s.contains('connection')) return 'Connexion impossible';
      return 'Une erreur est survenue';
    }

    test('Auth error status codes mapping to friendly messages', () {
      final dio401 = DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 401,
        ),
      );

      final dio429 = DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 429,
        ),
      );

      final timeout = DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        type: DioExceptionType.connectionTimeout,
      );

      expect(formatAuthError(dio401), 'Identifiants incorrects');
      expect(formatAuthError(dio429), 'Trop de tentatives — réessayez plus tard');
      expect(formatAuthError(timeout), 'Connexion impossible');
    });

    test('AI chat assistant handles rate limit (429) with exponential wait hint', () {
      final err429 = Exception('HTTP 429 Too Many Requests');
      final msg = AiChatController.messageErreur(err429);
      expect(msg, contains('Trop de questions'));
      expect(msg, contains('Attends quelques secondes'));
    });

    test('AI chat assistant handles expired session (401/403) with reconnect hint', () {
      final err401 = Exception('HTTP 401 Unauthorized');
      final msg = AiChatController.messageErreur(err401);
      expect(msg, contains('Session expirée'));
      expect(msg, contains('Reconnecte-toi'));
    });

    test('AI chat assistant handles network timeout with offline hint', () {
      final errNet = Exception('SocketException: OS Error: Connection timed out');
      final msg = AiChatController.messageErreur(errNet);
      expect(msg, contains('Connexion indisponible'));
      expect(msg, contains('Vérifie ton réseau'));
    });

    test('Generic unhandled error returns graceful fallback', () {
      final errGen = Exception('Unexpected 500 server error');
      final msg = AiChatController.messageErreur(errGen);
      expect(msg, contains('L\'assistant n\'a pas pu répondre'));
    });
  });
}
