import 'package:flutter_test/flutter_test.dart';
import 'package:universe_frontend/shared/models/models.dart';

void main() {
  group('VideoItem jalon 2/3', () {
    test('fromJson lit aimeParMoi, detesteParMoi et abonneParMoi', () {
      final v = VideoItem.fromJson({
        'id': 'v1',
        'titre': 'Cours',
        'aimeParMoi': true,
        'detesteParMoi': false,
        'abonneParMoi': true,
      });
      expect(v.likedByMe, isTrue);
      expect(v.dislikedByMe, isFalse);
      expect(v.abonneParMoi, isTrue);
    });

    test('fromJson accepte les alias anglais', () {
      final v = VideoItem.fromJson({
        'id': 'v2',
        'titre': 'TD',
        'likedByMe': false,
        'dislikedByMe': true,
      });
      expect(v.likedByMe, isFalse);
      expect(v.dislikedByMe, isTrue);
      expect(v.abonneParMoi, isFalse);
    });
  });
}
