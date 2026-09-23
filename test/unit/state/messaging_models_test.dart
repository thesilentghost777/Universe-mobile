import 'package:flutter_test/flutter_test.dart';
import 'package:universe_frontend/features/home/widgets/canal_rail_item.dart';
import 'package:universe_frontend/shared/models/models.dart';

void main() {
  group('MessageItem read receipts', () {
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

    test('copyWith toggles lu without touching other fields', () {
      const m = MessageItem(id: 'm1', contenu: 'Salut', auteurId: 'u1');
      final relu = m.copyWith(lu: true);
      expect(relu.lu, isTrue);
      expect(relu.contenu, m.contenu);
      expect(relu.auteurId, m.auteurId);
    });
  });

  group('ConversationItem unread count', () {
    test('fromJson defaults nonLus to 0 when absent', () {
      final c = ConversationItem.fromJson({'id': 'c1'});
      expect(c.nonLus, 0);
    });

    test('fromJson parses an explicit nonLus count', () {
      final c = ConversationItem.fromJson({'id': 'c1', 'nonLus': 4});
      expect(c.nonLus, 4);
    });
  });

  group('CanalRailItem.depuisArbre', () {
    test('returns an empty list for a null or empty arbre', () {
      expect(CanalRailItem.depuisArbre(null), isEmpty);
      expect(CanalRailItem.depuisArbre({'facultes': []}), isEmpty);
    });

    test('flattens Faculte > Filiere > Niveau > Matiere > Canal', () {
      final arbre = {
        'facultes': [
          {
            'filieres': [
              {
                'niveaux': [
                  {
                    'matieres': [
                      {
                        'nom': 'Algorithmique',
                        'canaux': [
                          {'id': 'c1', 'nom': 'Annonces', 'nombreNonLus': 3},
                          {'id': 'c2', 'nom': 'TD'},
                        ],
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ],
      };

      final items = CanalRailItem.depuisArbre(arbre);

      expect(items, hasLength(2));
      expect(items[0].id, 'c1');
      expect(items[0].matiere, 'Algorithmique');
      expect(items[0].nombreNonLus, 3);
      expect(items[1].id, 'c2');
      expect(items[1].nombreNonLus, 0);
    });
  });
}
