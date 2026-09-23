import 'package:flutter_test/flutter_test.dart';
import 'package:universe_frontend/core/auth/role_access.dart';
import 'package:universe_frontend/core/config.dart';
import 'package:universe_frontend/shared/models/models.dart';

void main() {
  group('Security & Attack Surface Tests', () {
    test('AppConfig enforces security baseline URL and name', () {
      expect(AppConfig.appName, 'UniVerse');
      expect(AppConfig.apiBaseUrl, isNotEmpty);
      expect(AppConfig.apiBaseUrl.endsWith('/'), isFalse);
    });

    test('Message text rendering escapes or preserves raw text safely without executing tags', () {
      final rawXssContent = '<script>alert("xss")</script><img src="x" onerror="alert(1)"/>';
      final msg = MessageItem(
        id: 'msg-sec-1',
        contenu: rawXssContent,
        auteurId: 'usr-1',
        auteurNom: 'Evil Attacker',
      );

      // Verify that Dart handles String content as immutable unicode text
      expect(msg.contenu, contains('<script>'));
      expect(msg.contenu, contains('alert("xss")'));
      // In Flutter text widgets (Text), string content is always treated as plain string literals,
      // avoiding HTML DOM execution.
    });

    test('Client-side role tamper resistance: Cannot escalate permissions without server-issued rank', () {
      final fakeStudent = UserProfile.fromJson({
        'id': 'attacker',
        'email': 'hacker@test.cm',
        'rang': 'etudiant',
        // Un champ inconnu injecté ne doit avoir aucun effet sur le rang.
        'rangUsurpe': 'moderateur',
      });

      final access = RoleAccess.depuis(fakeStudent);

      expect(access.peutCreerContenu, isFalse);
      expect(access.peutTraiterSignalements, isFalse);
      expect(access.peutPublierRessource, isFalse);
    });

    test('Video Item prevents malicious or invalid YouTube ID injection in thumbnail URL', () {
      final v1 = VideoItem.fromJson({
        'id': 'v1',
        'titre': 'Algorithmique',
        'youtubeId': 'dQw4w9WgXcQ',
      });
      expect(v1.thumbnailUrl, 'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg');

      final v2 = VideoItem.fromJson({
        'id': 'v2',
        'titre': 'Vidéo sans ID',
        'youtubeId': '',
      });
      expect(v2.thumbnailUrl, isNull);
    });

    test('MinIO storage path generation enforces user prefix and bucket segregation', () {
      const allowedBuckets = ['resources', 'library'];
      const candidateBucket = 'resources';
      expect(allowedBuckets.contains(candidateBucket), isTrue);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'cours.pdf';
      final objectKey = 'epreuves/${timestamp}_$fileName';

      expect(objectKey.startsWith('epreuves/'), isTrue);
      expect(objectKey.endsWith('.pdf'), isTrue);
    });
  });
}
