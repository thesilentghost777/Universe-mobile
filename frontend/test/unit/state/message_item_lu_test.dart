import 'package:flutter_test/flutter_test.dart';
import 'package:universe_frontend/shared/models/models.dart';

void main() {
  group('MessageItem lu / luAt', () {
    test('fromJson defaults lu to false when absent', () {
      final m = MessageItem.fromJson({
        'id': 'm1',
        'contenu': 'Salut',
        'auteurId': 'u1',
      });
      expect(m.lu, isFalse);
    });

    test('fromJson parses lu when present', () {
      final m = MessageItem.fromJson({
        'id': 'm1',
        'contenu': 'Salut',
        'auteurId': 'u1',
        'lu': true,
      });
      expect(m.lu, isTrue);
    });

    test('fromJson dérive lu depuis luAt', () {
      final m = MessageItem.fromJson({
        'id': 'm1',
        'contenu': 'Salut',
        'auteurId': 'u1',
        'luAt': '2026-09-20T04:00:00.000Z',
      });
      expect(m.lu, isTrue);
    });
  });
}
